// =============================================================================
// ffi_exports.cpp
// Mục đích  : Cổng FFI DUY NHẤT kết nối Dart ↔ C++ pipeline.
//             Quản lý vòng đời toàn bộ pipeline: init → process frames → release.
//             Không sử dụng JNI, không Java naming convention.
// Input     : Gọi từ Dart qua dart:ffi với raw pointers và primitive types.
// Output    : Structs tương thích C (packed, no vtable) được đọc từ Dart.
// Cách hoạt :
//   tmod_init_core()     → Tạo và kết nối tất cả module.
//   tmod_process_frame() → Chạy toàn bộ pipeline 1 frame:
//                          RGBA → YOLOv8n → ByteTrack → Depth → TTC → Risk
//   tmod_get_detections()→ Lấy danh sách detection chi tiết sau frame cuối.
//   tmod_release_core()  → Giải phóng tài nguyên.
// Lý do extern "C": Dart FFI yêu cầu C linkage (không name-mangling).
// =============================================================================

#include <cstdint>
#include <cstring>
#include <memory>
#include <vector>
#include <algorithm>
#include <android/log.h>

// Core modules
#include "core/nnapi_delegate.h"
#include "core/tflite_runner.h"

// Vision pipeline
#include "vision/yolov8n_engine.h"
#include "vision/byte_track.h"
#include "vision/depth_estimator.h"
#include "vision/ttc_calculator.h"

#define LOG_TAG "SaViCam_FFI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// =============================================================================
// Structs chia sẻ với Dart (phải khớp 1:1 với c_structs.dart).
// Sử dụng __attribute__((packed)) để đảm bảo layout không có padding ẩn.
// =============================================================================

/// Kết quả phát hiện đối tượng từ YOLOv8n + tracking + depth
struct __attribute__((packed)) DetectionResult {
    int32_t class_id;        // Index class COCO (0–79)
    float   confidence;      // Điểm tin cậy [0, 1]
    float   x_min;           // Toạ độ bounding box (pixels, ảnh gốc)
    float   y_min;
    float   x_max;
    float   y_max;
    int32_t track_id;        // ID tracking từ ByteTrack (-1 nếu chưa track)
    float   distance_m;      // Khoảng cách ước lượng (mét, -1 nếu thất bại)
    float   ttc_seconds;     // TTC ước lượng cho object này (giây)
    int32_t risk_level;      // Mức rủi ro riêng của object này (0–4)
};

/// Kết quả tổng hợp toàn khung hình (cho Dart đọc nhanh, không cần iterate detections)
struct __attribute__((packed)) FrameResult {
    int32_t risk_level;           // Mức rủi ro tổng frame (0=SAFE, 4=CRITICAL)
    float   ttc_seconds;          // TTC nhỏ nhất trong frame (giây)
    float   nearest_distance_m;   // Khoảng cách object gần nhất (mét)
    int32_t num_detections;       // Tổng số detection sau NMS
    int32_t nearest_class_id;     // Class ID vật cản gần nhất
    int32_t interrupt_active;     // 1 nếu interrupt flag đang bật (CRITICAL)
    int32_t nearest_track_id;     // Track ID vật cản nguy hiểm nhất
    float   frame_process_ms;     // Thời gian xử lý frame (ms)
};

// =============================================================================
// GLOBAL PIPELINE STATE
// Mục đích: Singleton instances của tất cả module pipeline.
//           Được tạo 1 lần bởi tmod_init_core() và xoá bởi tmod_release_core().
// Thread safety: Các hàm FFI phải được gọi từ 1 thread. Không thread-safe.
// =============================================================================
namespace {

// Trạng thái khởi tạo
static bool g_core_initialized = false;

// Module instances (unique_ptr để auto-cleanup)
static std::unique_ptr<tmod::vision::YoloV8nEngine>   g_yolo_engine;
static std::unique_ptr<tmod::vision::ByteTrack>        g_byte_tracker;
static std::unique_ptr<tmod::vision::DepthEstimator>   g_depth_estimator;
static std::unique_ptr<tmod::vision::TtcCalculator>    g_ttc_calculator;

// Buffer tái sử dụng cho detection results (tránh alloc mỗi frame)
static std::vector<DetectionResult>                    g_detection_buffer;

// Cache kết quả frame gần nhất (cho tmod_get_detections gọi sau)
static std::vector<tmod::vision::TrackedObject>        g_last_tracks;
static std::vector<float>                              g_last_distances;
static tmod::vision::FrameRiskResult                   g_last_risk_result{};

// Kích thước ảnh camera thực tế (cập nhật mỗi frame)
static int32_t g_last_frame_w = 0;
static int32_t g_last_frame_h = 0;

// Thời gian xử lý frame gần nhất (ms)
static float g_last_frame_ms = 0.0f;

} // anonymous namespace

// =============================================================================
// Utility: Lấy thời gian hiện tại (nanoseconds) dùng CLOCK_MONOTONIC
// =============================================================================
static int64_t NowNs() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return static_cast<int64_t>(ts.tv_sec) * 1000000000LL + ts.tv_nsec;
}

// =============================================================================
// EXPORTED FUNCTIONS — Dart FFI gọi trực tiếp qua đây
// =============================================================================

extern "C" {

// =============================================================================
// tmod_init_core()
// Mục đích  : Khởi tạo toàn bộ pipeline: YOLOv8n + ByteTrack + Depth + TTC.
// Input     : model_path — đường dẫn tuyệt đối tới file yolov8n_qat.tflite.
// Output    : 1 nếu thành công, 0 nếu thất bại.
// Cách hoạt :
//   1. Tạo YoloV8nEngine → gọi Init(model_path) để nạp TFLite model.
//   2. Tạo ByteTrack, DepthEstimator, TtcCalculator.
//   3. Pre-allocate detection buffer.
// =============================================================================
__attribute__((visibility("default")))
int32_t tmod_init_core(const char* model_path) {
    LOGI("tmod_init_core: Bắt đầu khởi tạo pipeline. model='%s'",
         model_path ? model_path : "(null)");

    if (g_core_initialized) {
        LOGW("tmod_init_core: Pipeline đã được khởi tạo, bỏ qua.");
        return 1;
    }

    if (!model_path) {
        LOGE("tmod_init_core: model_path là null!");
        return 0;
    }

    // -------------------------------------------------------------------------
    // Bước 1: Khởi tạo YOLOv8n engine (nạp TFLite model + NNAPI)
    // -------------------------------------------------------------------------
    g_yolo_engine = std::make_unique<tmod::vision::YoloV8nEngine>();
    if (!g_yolo_engine->Init(model_path)) {
        LOGE("tmod_init_core: YoloV8nEngine::Init() thất bại!");
        g_yolo_engine.reset();
        return 0;
    }
    LOGI("tmod_init_core: ✓ YoloV8nEngine khởi tạo OK.");

    // -------------------------------------------------------------------------
    // Bước 2: Khởi tạo ByteTrack tracker
    // -------------------------------------------------------------------------
    g_byte_tracker = std::make_unique<tmod::vision::ByteTrack>();
    LOGI("tmod_init_core: ✓ ByteTrack khởi tạo OK.");

    // -------------------------------------------------------------------------
    // Bước 3: Khởi tạo DepthEstimator với thông số camera mặc định
    // Thông số mặc định phù hợp camera góc rộng smartphone phổ thông.
    // Caller có thể override qua tmod_set_camera_params() sau.
    // -------------------------------------------------------------------------
    g_depth_estimator = std::make_unique<tmod::vision::DepthEstimator>();
    g_depth_estimator->SetCameraParams(/*focal_px=*/500.0f, /*ref_h=*/1.7f);
    LOGI("tmod_init_core: ✓ DepthEstimator khởi tạo OK (focal=500px).");

    // -------------------------------------------------------------------------
    // Bước 4: Khởi tạo TtcCalculator
    // -------------------------------------------------------------------------
    g_ttc_calculator = std::make_unique<tmod::vision::TtcCalculator>();
    g_ttc_calculator->SetCameraFps(30.0f);
    LOGI("tmod_init_core: ✓ TtcCalculator khởi tạo OK (FPS=30).");

    // -------------------------------------------------------------------------
    // Pre-allocate detection buffer (tránh alloc mỗi frame)
    // -------------------------------------------------------------------------
    g_detection_buffer.reserve(64);
    g_last_tracks.reserve(64);
    g_last_distances.reserve(64);

    g_core_initialized = true;
    LOGI("tmod_init_core: ✅ Pipeline CV khởi tạo hoàn tất.");
    return 1;
}

// =============================================================================
// tmod_set_camera_params()
// Mục đích  : Cấu hình thông số camera thực tế (gọi sau tmod_init_core).
// Input     : focal_px — tiêu cự pixels (từ Camera2 API getFocalLength()).
//             ref_height_m — chiều cao tham chiếu mặc định.
//             fps — FPS camera thực tế.
// Output    : 1 nếu thành công.
// =============================================================================
__attribute__((visibility("default")))
int32_t tmod_set_camera_params(float focal_px, float ref_height_m, float fps) {
    if (!g_core_initialized) return 0;

    g_depth_estimator->SetCameraParams(focal_px, ref_height_m);
    g_ttc_calculator->SetCameraFps(fps);

    LOGI("tmod_set_camera_params: focal=%.1fpx ref_h=%.2fm fps=%.0f",
         focal_px, ref_height_m, fps);
    return 1;
}

// =============================================================================
// tmod_process_frame()
// Mục đích  : Xử lý 1 khung hình camera qua toàn bộ pipeline.
// Input     : rgba_data — con trỏ buffer RGBA 8-bit (w × h × 4 bytes).
//             width, height — kích thước ảnh (pixels).
//             result — con trỏ FrameResult do Dart cấp phát.
// Output    : 1 nếu thành công, 0 nếu thất bại.
// Pipeline  :
//   1. YOLOv8n detect → BBox[]
//   2. ByteTrack update → TrackedObject[]
//   3. DepthEstimator batch → float[] distances
//   4. TtcCalculator processFrame → FrameRiskResult
//   5. Điền FrameResult cho Dart
//   6. Cache results cho tmod_get_detections()
// Tối ưu   : Không alloc heap trong vòng lặp chính, tái sử dụng buffers.
// =============================================================================
__attribute__((visibility("default")))
int32_t tmod_process_frame(const uint8_t* rgba_data, int32_t width, int32_t height,
                            FrameResult* result) {
    // Kiểm tra tiền điều kiện
    if (!g_core_initialized || !rgba_data || !result || width <= 0 || height <= 0) {
        LOGE("tmod_process_frame: Tham số không hợp lệ hoặc core chưa init.");
        if (result) {
            result->risk_level         = 0;
            result->ttc_seconds        = 999.0f;
            result->nearest_distance_m = 99.0f;
            result->num_detections     = 0;
            result->nearest_class_id   = -1;
            result->interrupt_active   = 0;
            result->nearest_track_id   = -1;
            result->frame_process_ms   = 0.0f;
        }
        return 0;
    }

    int64_t t_start = NowNs();

    // Lưu kích thước frame
    g_last_frame_w = width;
    g_last_frame_h = height;

    // -------------------------------------------------------------------------
    // Bước 1: YOLOv8n Detection
    // Input : RGBA buffer
    // Output: danh sách BBox với class_id, confidence, bbox coords
    // -------------------------------------------------------------------------
    std::vector<tmod::vision::BBox> detections =
        g_yolo_engine->Detect(rgba_data, width, height);

    // -------------------------------------------------------------------------
    // Bước 2: ByteTrack Tracking
    // Input : BBox[] từ detection
    // Output: TrackedObject[] với track_id ổn định và velocity
    // -------------------------------------------------------------------------
    g_last_tracks = g_byte_tracker->Update(detections);

    // -------------------------------------------------------------------------
    // Bước 3: Depth Estimation (batch)
    // Input : TrackedObject[] với bbox
    // Output: float[] khoảng cách tương ứng (mét)
    // -------------------------------------------------------------------------
    g_last_distances = g_depth_estimator->EstimateBatch(g_last_tracks);

    // Dọn lịch sử EMA của track đã biến mất
    {
        std::vector<int32_t> active_ids;
        active_ids.reserve(g_last_tracks.size());
        for (const auto& t : g_last_tracks) {
            active_ids.push_back(t.track_id);
        }
        g_depth_estimator->PurgeStaleHistory(active_ids);
    }

    // -------------------------------------------------------------------------
    // Bước 4: TTC Calculation + Risk Classification + Emergency System
    // Input : TrackedObject[] + float[] distances
    // Output: FrameRiskResult (max_risk, min_ttc, interrupt_flag...)
    // -------------------------------------------------------------------------
    g_last_risk_result = g_ttc_calculator->ProcessFrame(g_last_tracks, g_last_distances);

    // -------------------------------------------------------------------------
    // Bước 5: Điền FrameResult cho Dart
    // -------------------------------------------------------------------------
    int64_t t_end = NowNs();
    g_last_frame_ms = static_cast<float>(t_end - t_start) / 1e6f;

    result->risk_level         = g_last_risk_result.max_risk_level;
    result->ttc_seconds        = g_last_risk_result.min_ttc_seconds;
    result->nearest_distance_m = g_last_risk_result.nearest_distance_m;
    result->num_detections     = static_cast<int32_t>(g_last_tracks.size());
    result->nearest_class_id   = g_last_risk_result.nearest_class_id;
    result->interrupt_active   = g_last_risk_result.interrupt_active ? 1 : 0;
    result->nearest_track_id   = g_last_risk_result.nearest_track_id;
    result->frame_process_ms   = g_last_frame_ms;

    // -------------------------------------------------------------------------
    // Bước 6: Build detection buffer cache (cho tmod_get_detections)
    // -------------------------------------------------------------------------
    size_t n = std::min(g_last_tracks.size(), g_last_distances.size());
    g_detection_buffer.resize(n);

    for (size_t i = 0; i < n; ++i) {
        const auto& obj = g_last_tracks[i];
        float dist = g_last_distances[i];

        // Tính TTC riêng cho object này
        float vel_mps = g_ttc_calculator->PixelVelocityToMps(obj.velocity_y, dist);
        float ttc     = g_ttc_calculator->CalculateTtc(dist, vel_mps);
        int32_t risk  = g_ttc_calculator->ClassifyRisk(ttc, dist);

        auto& d        = g_detection_buffer[i];
        d.class_id     = obj.bbox.class_id;
        d.confidence   = obj.bbox.confidence;
        d.x_min        = obj.bbox.x_min;
        d.y_min        = obj.bbox.y_min;
        d.x_max        = obj.bbox.x_max;
        d.y_max        = obj.bbox.y_max;
        d.track_id     = obj.track_id;
        d.distance_m   = dist;
        d.ttc_seconds  = ttc;
        d.risk_level   = risk;
    }

    LOGI("tmod_process_frame: %dx%d → %zu det → %zu tracks | risk=%d ttc=%.2fs dist=%.2fm | %.1fms",
         width, height,
         detections.size(), g_last_tracks.size(),
         result->risk_level, result->ttc_seconds, result->nearest_distance_m,
         g_last_frame_ms);

    return 1;
}

// =============================================================================
// tmod_get_detections()
// Mục đích  : Lấy danh sách detection chi tiết của frame cuối cùng.
// Input     : out_buffer — Dart cấp phát mảng DetectionResult[max_count].
//             max_count — kích thước mảng tối đa.
// Output    : Số lượng detection thực tế ghi vào buffer.
// Cách hoạt : Copy từ g_detection_buffer (đã build trong tmod_process_frame)
//             vào Dart-allocated buffer, không tính lại.
// =============================================================================
__attribute__((visibility("default")))
int32_t tmod_get_detections(DetectionResult* out_buffer, int32_t max_count) {
    if (!g_core_initialized || !out_buffer || max_count <= 0) {
        return 0;
    }

    int32_t count = static_cast<int32_t>(
        std::min(g_detection_buffer.size(), static_cast<size_t>(max_count))
    );

    if (count > 0) {
        std::memcpy(out_buffer, g_detection_buffer.data(),
                    count * sizeof(DetectionResult));
    }

    return count;
}

// =============================================================================
// tmod_release_core()
// Mục đích  : Giải phóng toàn bộ tài nguyên pipeline C++.
//             Gọi trước khi app đóng hoặc khi restart pipeline.
// =============================================================================
__attribute__((visibility("default")))
void tmod_release_core() {
    LOGI("tmod_release_core: Bắt đầu giải phóng pipeline.");

    // Reset interrupt flag khẩn cấp
    tmod::vision::TtcCalculator::ForceReleaseInterrupt();

    // Giải phóng các modules theo thứ tự ngược với init
    g_ttc_calculator.reset();
    g_depth_estimator.reset();
    g_byte_tracker.reset();
    g_yolo_engine.reset();

    // Xoá buffers
    g_detection_buffer.clear();
    g_detection_buffer.shrink_to_fit();
    g_last_tracks.clear();
    g_last_distances.clear();

    g_core_initialized = false;
    LOGI("tmod_release_core: ✅ Tất cả tài nguyên đã được giải phóng.");
}

// =============================================================================
// tmod_is_initialized()
// Mục đích: Kiểm tra pipeline đã sẵn sàng chưa (Dart gọi trước process_frame).
// Output  : 1 nếu đã init, 0 nếu chưa.
// =============================================================================
__attribute__((visibility("default")))
int32_t tmod_is_initialized() {
    return g_core_initialized ? 1 : 0;
}

// =============================================================================
// tmod_get_interrupt_flag()
// Mục đích: Đọc emergency interrupt flag (thread-safe, atomic read).
// Output  : 1 nếu đang CRITICAL interrupt, 0 nếu bình thường.
// Cách dùng: Dart audio module poll hàm này để biết có dừng TTS không.
// =============================================================================
__attribute__((visibility("default")))
int32_t tmod_get_interrupt_flag() {
    return tmod::vision::TtcCalculator::IsInterruptActive() ? 1 : 0;
}

// =============================================================================
// tmod_reset_interrupt()
// Mục đích: Tắt interrupt flag từ Dart (ví dụ user đã xác nhận nguy hiểm).
// =============================================================================
__attribute__((visibility("default")))
void tmod_reset_interrupt() {
    tmod::vision::TtcCalculator::ForceReleaseInterrupt();
    LOGI("tmod_reset_interrupt: Interrupt flag được reset từ Dart.");
}

// =============================================================================
// tmod_get_current_risk()
// Mục đích: Đọc mức rủi ro hiện tại thread-safe (cho UI poll không cần FrameResult).
// Output  : 0=SAFE, 1=CAUTION, 2=WARNING, 3=DANGER, 4=CRITICAL
// =============================================================================
__attribute__((visibility("default")))
int32_t tmod_get_current_risk() {
    return tmod::vision::TtcCalculator::GetCurrentMaxRisk();
}

// =============================================================================
// tmod_reset_tracker()
// Mục đích: Reset ByteTrack tracker (gọi khi scene thay đổi đột ngột).
//           Giữ nguyên model TFLite, không cần reinit toàn bộ.
// =============================================================================
__attribute__((visibility("default")))
void tmod_reset_tracker() {
    if (!g_core_initialized) return;
    g_byte_tracker->Reset();
    g_depth_estimator->ClearHistory();
    g_detection_buffer.clear();
    g_last_tracks.clear();
    g_last_distances.clear();
    LOGI("tmod_reset_tracker: Tracker và depth history đã được reset.");
}

// =============================================================================
// tmod_get_version()
// Mục đích: Trả về version string của native library (debug / display).
// Output  : Con trỏ tới string constant (không cần giải phóng từ Dart).
// =============================================================================
__attribute__((visibility("default")))
const char* tmod_get_version() {
    return "SaViCam T-Mod Native v1.0.0 — YOLOv8n+ByteTrack+TTC (c) 2024";
}

} // extern "C"

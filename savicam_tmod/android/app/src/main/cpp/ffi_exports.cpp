/// ffi_exports.cpp
/// Cánh cửa DUY NHẤT mở ra cho Dart FFI gọi vào.
/// Tất cả các hàm export đều là extern "C" để Dart dart:ffi có thể lookup.
/// KHÔNG sử dụng JNI, KHÔNG sử dụng Java_com_* naming convention.

#include <cstdint>
#include <cstring>
#include <android/log.h>

#define LOG_TAG "SaViCam_FFI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ============================================================================
// Structs chia sẻ với Dart (phải khớp 1:1 với c_structs.dart)
// ============================================================================

/// Kết quả phát hiện đối tượng từ YOLOv8n
struct DetectionResult {
    int32_t class_id;
    float   confidence;
    float   x_min;
    float   y_min;
    float   x_max;
    float   y_max;
    int32_t track_id;       // ID tracking từ ByteTrack
    float   distance_m;     // Khoảng cách ước lượng (mét)
};

/// Kết quả xử lý toàn khung hình
struct FrameResult {
    int32_t risk_level;         // 0-4 (0 = an toàn, 4 = sinh tử)
    float   ttc_seconds;        // Time-to-Collision (giây)
    float   nearest_distance_m; // Khoảng cách vật cản gần nhất
    int32_t num_detections;     // Số đối tượng phát hiện
    int32_t nearest_class_id;   // Class ID của vật cản gần nhất
};

// ============================================================================
// Biến nội bộ module
// ============================================================================
static bool g_core_initialized = false;

// ============================================================================
// EXPORTED FUNCTIONS - Dart FFI gọi trực tiếp qua đây
// ============================================================================

extern "C" {

/// Khởi tạo toàn bộ pipeline: TFLite + NNAPI + YOLOv8n + ByteTrack
/// @param model_path: Đường dẫn tuyệt đối tới file yolov8n_qat.tflite trên thiết bị
/// @return 1 nếu thành công, 0 nếu thất bại
__attribute__((visibility("default")))
int32_t tmod_init_core(const char* model_path) {
    LOGI("tmod_init_core: Khởi tạo pipeline CV với model: %s", model_path);

    // TODO: Nạp TFLite model, tạo NNAPI delegate, khởi tạo ByteTrack
    // g_tflite_runner = new TFLiteRunner(model_path, true);
    // g_yolo_engine = new YoloV8nEngine(g_tflite_runner);
    // g_byte_tracker = new ByteTrack();
    // g_depth_estimator = new DepthEstimator();
    // g_ttc_calculator = new TtcCalculator();

    g_core_initialized = true;
    LOGI("tmod_init_core: Pipeline CV khởi tạo hoàn tất.");
    return 1;
}

/// Xử lý 1 khung hình camera.
/// Dart gửi pointer tới buffer RGBA và kích thước, nhận lại FrameResult.
/// @param rgba_data: Con trỏ tới dữ liệu pixel RGBA
/// @param width: Chiều rộng ảnh
/// @param height: Chiều cao ảnh
/// @param result: Con trỏ output FrameResult (Dart cấp phát bộ nhớ)
/// @return 1 nếu xử lý thành công, 0 nếu thất bại
__attribute__((visibility("default")))
int32_t tmod_process_frame(const uint8_t* rgba_data, int32_t width, int32_t height, FrameResult* result) {
    if (!g_core_initialized || !rgba_data || !result) {
        LOGE("tmod_process_frame: Core chưa init hoặc tham số null.");
        return 0;
    }

    // TODO: Pipeline thực tế:
    // 1. Tiền xử lý ảnh -> tensor input
    // 2. YOLOv8n inference qua TFLite + NNAPI
    // 3. ByteTrack cập nhật tracking
    // 4. DepthEstimator tính khoảng cách
    // 5. TtcCalculator tính TTC & mức rủi ro

    // --- Giả lập kết quả xử lý ---
    result->risk_level = 0;
    result->ttc_seconds = 999.0f;
    result->nearest_distance_m = 99.0f;
    result->num_detections = 0;
    result->nearest_class_id = -1;

    return 1;
}

/// Lấy danh sách detection chi tiết của frame cuối cùng.
/// @param out_buffer: Dart cấp phát mảng DetectionResult[max_count]
/// @param max_count: Kích thước mảng tối đa
/// @return Số lượng detection thực tế ghi vào buffer
__attribute__((visibility("default")))
int32_t tmod_get_detections(DetectionResult* out_buffer, int32_t max_count) {
    if (!g_core_initialized || !out_buffer || max_count <= 0) {
        return 0;
    }

    // TODO: Copy danh sách detection từ frame cuối cùng vào out_buffer
    return 0; // Hiện chưa có detection nào
}

/// Giải phóng toàn bộ tài nguyên C++
__attribute__((visibility("default")))
void tmod_release_core() {
    LOGI("tmod_release_core: Giải phóng tài nguyên pipeline CV.");

    // TODO: delete g_tflite_runner, g_yolo_engine, g_byte_tracker, ...
    g_core_initialized = false;
}

/// Kiểm tra trạng thái khởi tạo
__attribute__((visibility("default")))
int32_t tmod_is_initialized() {
    return g_core_initialized ? 1 : 0;
}

} // extern "C"

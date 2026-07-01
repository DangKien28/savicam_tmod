// =============================================================================
// ttc_calculator.cpp
// Mục đích  : Tính Time-to-Collision (TTC) và phân loại mức độ rủi ro va chạm.
//             Quản lý hệ thống khẩn cấp: interrupt flag, ưu tiên cảnh báo.
// Input     : Khoảng cách (mét) + vận tốc tiếp cận (m/s) từ DepthEstimator + ByteTrack.
// Output    : TTC (giây) + RiskLevel (0–4) + interrupt_flag khi CRITICAL.
// Cách hoạt :
//   TTC = distance / approach_velocity
//   approach_velocity tính từ velocity_y của ByteTrack track (pixel/frame → m/s).
//   RiskLevel xác định theo bảng ngưỡng TTC + khoảng cách.
//   Khi CRITICAL: set g_interrupt_flag toàn cục, override tất cả cảnh báo.
// Lý do TTC: Chỉ số quan trọng nhất trong ADAS (Advanced Driver Assistance),
//   phản ánh nguy cơ va chạm thực tế tốt hơn chỉ dùng khoảng cách thuần tuý.
//   Ví dụ: vật thể 5m nhưng đứng yên vs 5m nhưng đang lao tới ở 10m/s.
// =============================================================================

#include "ttc_calculator.h"

#include <android/log.h>
#include <cmath>
#include <algorithm>
#include <atomic>
#include <chrono>

#define LOG_TAG_TTC "TModVision_TTC"
#define TTC_LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG_TTC, __VA_ARGS__)
#define TTC_LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG_TTC, __VA_ARGS__)
#define TTC_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG_TTC, __VA_ARGS__)

namespace tmod {
namespace vision {

// =============================================================================
// EMERGENCY SYSTEM — Biến toàn cục cho hệ thống khẩn cấp
// Mục đích: interrupt_flag được check bởi audio/haptic module để dừng ngay
//           tất cả output đang chạy và kích hoạt cảnh báo CRITICAL.
// Thread safety: std::atomic đảm bảo read/write an toàn từ nhiều thread.
// =============================================================================

// Flag khẩn cấp — TRUE khi có ít nhất 1 object ở mức CRITICAL
std::atomic<bool> g_interrupt_flag{false};

// Timestamp lần CRITICAL gần nhất (milliseconds since epoch)
std::atomic<int64_t> g_last_critical_time_ms{0};

// Mức rủi ro cao nhất hiện tại (cho các module khác poll)
std::atomic<int32_t> g_current_max_risk{0};

// =============================================================================
// Hằng số phân loại rủi ro
// =============================================================================

// TTC thresholds (giây) — được tinh chỉnh cho môi trường giao thông Việt Nam
// Lý do ngưỡng thấp hơn standard ADAS Tây: tốc độ trung bình xe máy VN <40km/h
static constexpr float TTC_CRITICAL  = 1.2f;  // <1.2s → CRITICAL (sinh tử)
static constexpr float TTC_DANGER    = 2.5f;  // <2.5s → DANGER (nguy hiểm)
static constexpr float TTC_WARNING   = 4.5f;  // <4.5s → WARNING (cảnh báo)
static constexpr float TTC_CAUTION   = 7.0f;  // <7.0s → CAUTION (chú ý)
// >7.0s → SAFE

// Khoảng cách thresholds (mét) — phòng ngừa vật thể đứng yên gần
static constexpr float DIST_CRITICAL = 0.8f;   // <0.8m → luôn CRITICAL
static constexpr float DIST_DANGER   = 1.5f;   // <1.5m → ít nhất DANGER
static constexpr float DIST_WARNING  = 3.0f;   // <3.0m → ít nhất WARNING
static constexpr float DIST_CAUTION  = 5.0f;   // <5.0m → ít nhất CAUTION

// TTC vô cực (vật thể không di chuyển hoặc di chuyển ra xa)
static constexpr float TTC_INFINITY  = 999.0f;

// Thời gian giữ interrupt flag sau khi hết CRITICAL (ms)
static constexpr int64_t INTERRUPT_HOLD_MS = 2000;  // 2 giây

// Pixel/frame → m/s conversion (giả sử camera 30FPS, 1 pixel ≈ focal/distance)
// Thực tế cần calibrate theo camera params, đây là giá trị heuristic.
static constexpr float PIXEL_TO_MS_FACTOR = 0.02f;  // 1 pixel/frame ≈ 0.02 m/s (ước lượng)

// =============================================================================
// Constructor
// =============================================================================
TtcCalculator::TtcCalculator()
    : camera_fps_(30.0f)
    , pixels_per_meter_(100.0f)   // ~100px = 1m ở khoảng cách 5m với camera 500px focal
{
    TTC_LOGI("TtcCalculator: Khởi tạo. FPS=%.0f, px/m=%.0f",
             camera_fps_, pixels_per_meter_);
}

// =============================================================================
// Destructor
// =============================================================================
TtcCalculator::~TtcCalculator() {
    // Reset interrupt flag khi dừng pipeline
    g_interrupt_flag.store(false);
    g_current_max_risk.store(0);
}

// =============================================================================
// SetCameraFps()
// Mục đích: Cấu hình FPS camera để quy đổi velocity pixel/frame → m/s chính xác.
// =============================================================================
void TtcCalculator::SetCameraFps(float fps) {
    if (fps > 0.0f) {
        camera_fps_ = fps;
        TTC_LOGI("TtcCalculator: Camera FPS = %.0f", camera_fps_);
    }
}

// =============================================================================
// SetPixelsPerMeter()
// Mục đích: Calibrate tỷ lệ pixel/m tại khoảng cách tham chiếu.
// Công thức: pixels_per_meter = focal_length_px / ref_distance_m
// =============================================================================
void TtcCalculator::SetPixelsPerMeter(float ppm) {
    if (ppm > 0.0f) pixels_per_meter_ = ppm;
}

// =============================================================================
// CalculateTtc()
// Mục đích  : Tính TTC từ khoảng cách và vận tốc tiếp cận.
// Input     : distance_m — khoảng cách hiện tại (mét, >0).
//             approach_velocity_mps — vận tốc tiếp cận (m/s, >0 = đang lại gần).
// Output    : TTC (giây). TTC_INFINITY nếu không tiếp cận hoặc quá xa.
// Chú ý    : approach_velocity_mps > 0 → vật đang lại gần (nguy hiểm).
//             approach_velocity_mps < 0 → vật đang ra xa (an toàn).
// =============================================================================
float TtcCalculator::CalculateTtc(float distance_m, float approach_velocity_mps) {
    // Vật không tiếp cận hoặc tiếp cận quá chậm → TTC vô cực
    if (approach_velocity_mps < 0.05f) {
        return TTC_INFINITY;
    }
    if (distance_m <= 0.0f) {
        return 0.0f;  // Đã va chạm
    }

    float ttc = distance_m / approach_velocity_mps;

    // Cap TTC tối đa để tránh giá trị vô nghĩa
    return std::min(ttc, TTC_INFINITY);
}

// =============================================================================
// PixelVelocityToMps()
// Mục đích  : Quy đổi velocity pixel/frame từ ByteTrack sang m/s thực.
// Input     : pixel_vel — velocity dọc trục Y (pixel/frame từ ByteTrack).
//             distance_m — khoảng cách hiện tại để scale px → m.
// Output    : approach_velocity (m/s). Dương = đang tiếp cận.
// Cách hoạt : velocity_mps = pixel_vel_y × (1/pixels_per_meter_at_distance) × fps
//   pixels_per_meter_at_dist = focal_px / distance_m (pinhole model)
//   → velocity_mps = pixel_vel_y × distance_m / (focal_px × fps) × fps
//                  = pixel_vel_y × distance_m / focal_px
// Lý do tách hàm: Để unit test độc lập và dễ calibrate.
// =============================================================================
float TtcCalculator::PixelVelocityToMps(float pixel_vel_y, float distance_m) const {
    if (distance_m <= 0.0f || pixels_per_meter_ <= 0.0f) return 0.0f;

    // pixels_per_meter thực tế thay đổi theo khoảng cách (pinhole)
    // focal_px ≈ pixels_per_meter_ × ref_distance (mặc định calibrate ở 5m)
    float focal_px = pixels_per_meter_ * 5.0f;  // approximate
    float vel_mps  = pixel_vel_y * distance_m / focal_px;

    // Velocity dương (bbox đi xuống = lại gần camera) → approach velocity dương
    return std::max(0.0f, vel_mps);
}

// =============================================================================
// ClassifyRisk()
// Mục đích  : Phân loại mức độ rủi ro từ TTC và khoảng cách.
// Input     : ttc — Time-to-Collision (giây).
//             distance_m — khoảng cách thực (mét).
// Output    : RiskLevel:
//   0 = SAFE     — An toàn, không cần cảnh báo
//   1 = CAUTION  — Chú ý, cảnh báo nhẹ (TTS thông thường)
//   2 = WARNING  — Cảnh báo, giảm tốc (TTS ưu tiên)
//   3 = DANGER   — Nguy hiểm, phanh gấp (TTS khẩn cấp + rung)
//   4 = CRITICAL — Sinh tử, va chạm sắp xảy ra (interrupt ALL + rung mạnh)
// Logic: Lấy mức rủi ro CAO HƠN giữa TTC-based và distance-based.
//   Đảm bảo vật thể tĩnh gần (distance-based) cũng được cảnh báo đúng.
// =============================================================================
int32_t TtcCalculator::ClassifyRisk(float ttc, float distance_m) {
    // Xác định risk theo TTC
    int32_t risk_ttc = 0;
    if      (ttc < TTC_CRITICAL) risk_ttc = 4;
    else if (ttc < TTC_DANGER)   risk_ttc = 3;
    else if (ttc < TTC_WARNING)  risk_ttc = 2;
    else if (ttc < TTC_CAUTION)  risk_ttc = 1;

    // Xác định risk theo khoảng cách (vật thể tĩnh/chậm gần)
    int32_t risk_dist = 0;
    if      (distance_m < DIST_CRITICAL) risk_dist = 4;
    else if (distance_m < DIST_DANGER)   risk_dist = 3;
    else if (distance_m < DIST_WARNING)  risk_dist = 2;
    else if (distance_m < DIST_CAUTION)  risk_dist = 1;

    // Lấy mức cao nhất
    return std::max(risk_ttc, risk_dist);
}

// =============================================================================
// ProcessFrame()
// Mục đích  : Xử lý toàn bộ danh sách objects trong 1 frame,
//             tính TTC cho từng object, cập nhật emergency system.
// Input     : objects — danh sách TrackedObject từ ByteTrack.
//             distances — khoảng cách tương ứng từ DepthEstimator.
// Output    : FrameRiskResult chứa mức rủi ro cao nhất, TTC nhỏ nhất,
//             object nguy hiểm nhất, và interrupt_flag.
// =============================================================================
FrameRiskResult TtcCalculator::ProcessFrame(
    const std::vector<TrackedObject>& objects,
    const std::vector<float>& distances)
{
    FrameRiskResult result{};
    result.max_risk_level     = 0;
    result.min_ttc_seconds    = TTC_INFINITY;
    result.nearest_distance_m = TTC_INFINITY;
    result.nearest_class_id   = -1;
    result.interrupt_active   = false;

    if (objects.empty()) {
        // Không có vật thể → an toàn, tắt interrupt nếu đã quá thời gian giữ
        TryReleaseInterrupt();
        g_current_max_risk.store(0);
        return result;
    }

    size_t count = std::min(objects.size(), distances.size());

    for (size_t i = 0; i < count; ++i) {
        const auto& obj = objects[i];
        float dist = distances[i];

        if (dist < 0.0f) continue;  // Depth estimate thất bại

        // Quy đổi velocity pixel/frame → m/s (velocity_y dương = lại gần)
        float approach_vel = PixelVelocityToMps(obj.velocity_y, dist);

        // Tính TTC
        float ttc = CalculateTtc(dist, approach_vel);

        // Phân loại rủi ro
        int32_t risk = ClassifyRisk(ttc, dist);

        // Cập nhật kết quả frame
        if (risk > result.max_risk_level) {
            result.max_risk_level = risk;
        }
        if (ttc < result.min_ttc_seconds) {
            result.min_ttc_seconds = ttc;
        }
        if (dist < result.nearest_distance_m) {
            result.nearest_distance_m = dist;
            result.nearest_class_id   = obj.bbox.class_id;
            result.nearest_track_id   = obj.track_id;
        }
    }

    // -------------------------------------------------------------------------
    // EMERGENCY SYSTEM UPDATE
    // Mục đích: Kích hoạt interrupt flag khi có CRITICAL risk.
    //           Giữ flag trong INTERRUPT_HOLD_MS sau khi hết CRITICAL.
    // -------------------------------------------------------------------------
    if (result.max_risk_level >= 4) {
        // Kích hoạt khẩn cấp
        g_interrupt_flag.store(true);
        g_last_critical_time_ms.store(CurrentTimeMs());
        g_current_max_risk.store(result.max_risk_level);

        TTC_LOGE("🚨 CRITICAL: TTC=%.2fs dist=%.2fm class=%d track=%d — INTERRUPT TRIGGERED!",
                 result.min_ttc_seconds, result.nearest_distance_m,
                 result.nearest_class_id, result.nearest_track_id);
    } else {
        // Cập nhật max risk
        g_current_max_risk.store(result.max_risk_level);
        // Thử tắt interrupt nếu đã qua thời gian giữ
        TryReleaseInterrupt();
    }

    result.interrupt_active = g_interrupt_flag.load();

    // Log cảnh báo theo mức độ
    if (result.max_risk_level >= 3) {
        TTC_LOGW("⚠️ DANGER: TTC=%.2fs dist=%.2fm risk=%d",
                 result.min_ttc_seconds, result.nearest_distance_m,
                 result.max_risk_level);
    } else if (result.max_risk_level >= 2) {
        TTC_LOGI("WARNING: TTC=%.2fs dist=%.2fm risk=%d",
                 result.min_ttc_seconds, result.nearest_distance_m,
                 result.max_risk_level);
    }

    return result;
}

// =============================================================================
// IsInterruptActive()
// Mục đích: Kiểm tra interrupt flag từ luồng khác (audio / haptic module).
// Thread safety: std::atomic đảm bảo an toàn.
// =============================================================================
bool TtcCalculator::IsInterruptActive() {
    return g_interrupt_flag.load(std::memory_order_relaxed);
}

// =============================================================================
// GetCurrentMaxRisk()
// Mục đích: Đọc mức rủi ro hiện tại thread-safe (cho UI / TTS module poll).
// =============================================================================
int32_t TtcCalculator::GetCurrentMaxRisk() {
    return g_current_max_risk.load(std::memory_order_relaxed);
}

// =============================================================================
// ForceReleaseInterrupt()
// Mục đích: Buộc tắt interrupt flag (gọi từ UI khi user xác nhận).
// =============================================================================
void TtcCalculator::ForceReleaseInterrupt() {
    g_interrupt_flag.store(false);
    TTC_LOGI("TtcCalculator: Interrupt flag được tắt bởi user.");
}

// =============================================================================
// [PRIVATE] TryReleaseInterrupt()
// Mục đích: Tắt interrupt flag nếu đã quá thời gian giữ INTERRUPT_HOLD_MS.
// Cách hoạt: So sánh thời gian hiện tại với lần CRITICAL cuối cùng.
// =============================================================================
void TtcCalculator::TryReleaseInterrupt() {
    if (!g_interrupt_flag.load(std::memory_order_relaxed)) return;

    int64_t elapsed = CurrentTimeMs() - g_last_critical_time_ms.load();
    if (elapsed >= INTERRUPT_HOLD_MS) {
        g_interrupt_flag.store(false);
        TTC_LOGI("TtcCalculator: Interrupt flag tự động tắt sau %lldms.", (long long)elapsed);
    }
}

// =============================================================================
// [PRIVATE] CurrentTimeMs()
// Mục đích: Lấy thời gian hiện tại tính bằng milliseconds (monotonic clock).
// =============================================================================
int64_t TtcCalculator::CurrentTimeMs() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(
        steady_clock::now().time_since_epoch()
    ).count();
}

} // namespace vision
} // namespace tmod

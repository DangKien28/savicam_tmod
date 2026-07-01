// =============================================================================
// ttc_calculator.h
// Mục đích: Interface cho TtcCalculator và hệ thống khẩn cấp (interrupt flag).
// =============================================================================

#ifndef TMOD_TTC_CALCULATOR_H
#define TMOD_TTC_CALCULATOR_H

#include <cstdint>
#include <vector>
#include <atomic>
#include "byte_track.h"

namespace tmod {
namespace vision {

// =============================================================================
// FrameRiskResult — Kết quả phân tích rủi ro toàn frame
// Mục đích: Gom kết quả TTC + risk của tất cả objects trong 1 frame.
// =============================================================================
struct FrameRiskResult {
    int32_t max_risk_level;      // Mức rủi ro cao nhất (0–4)
    float   min_ttc_seconds;     // TTC nhỏ nhất (giây)
    float   nearest_distance_m;  // Khoảng cách object gần nhất (m)
    int32_t nearest_class_id;    // Class COCO của object gần nhất
    int32_t nearest_track_id;    // Track ID của object nguy hiểm nhất
    bool    interrupt_active;    // TRUE nếu interrupt flag đang bật
};

// =============================================================================
// Global emergency state — truy cập từ bất kỳ module nào
// =============================================================================
extern std::atomic<bool>    g_interrupt_flag;       // TRUE = CRITICAL đang xảy ra
extern std::atomic<int64_t> g_last_critical_time_ms; // Timestamp CRITICAL gần nhất
extern std::atomic<int32_t> g_current_max_risk;     // Risk level hiện tại (0–4)

// =============================================================================
// TtcCalculator
// Mục đích: Tính TTC, phân loại rủi ro, quản lý emergency interrupt system.
// =============================================================================
class TtcCalculator {
public:
    TtcCalculator();
    ~TtcCalculator();

    // Cấu hình
    void SetCameraFps(float fps);
    void SetPixelsPerMeter(float ppm);

    // Tính TTC từ khoảng cách và vận tốc tiếp cận
    float CalculateTtc(float distance_m, float approach_velocity_mps);

    // Phân loại rủi ro (0=SAFE, 1=CAUTION, 2=WARNING, 3=DANGER, 4=CRITICAL)
    int32_t ClassifyRisk(float ttc, float distance_m);

    // Quy đổi velocity pixel/frame → m/s
    float PixelVelocityToMps(float pixel_vel_y, float distance_m) const;

    // Xử lý toàn bộ frame (main pipeline call)
    FrameRiskResult ProcessFrame(
        const std::vector<TrackedObject>& objects,
        const std::vector<float>& distances
    );

    // Truy vấn trạng thái emergency (thread-safe)
    static bool    IsInterruptActive();
    static int32_t GetCurrentMaxRisk();
    static void    ForceReleaseInterrupt();

private:
    void    TryReleaseInterrupt();
    static int64_t CurrentTimeMs();

    float camera_fps_;          // FPS camera thực tế
    float pixels_per_meter_;    // Tỷ lệ px/m tại khoảng cách tham chiếu
};

} // namespace vision
} // namespace tmod

#endif // TMOD_TTC_CALCULATOR_H

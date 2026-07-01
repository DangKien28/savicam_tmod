// =============================================================================
// depth_estimator.h
// Mục đích: Interface cho DepthEstimator — ước lượng khoảng cách từ bbox.
// =============================================================================

#ifndef TMOD_DEPTH_ESTIMATOR_H
#define TMOD_DEPTH_ESTIMATOR_H

#include "byte_track.h"
#include <unordered_map>
#include <vector>
#include <cstdint>

namespace tmod {
namespace vision {

// =============================================================================
// DepthEstimator
// Mục đích: Ước lượng khoảng cách đến vật thể bằng pinhole camera model.
//           Dùng chiều cao bbox và kích thước thực tế tham chiếu per-class.
//           Áp dụng EMA smoothing để giảm nhiễu frame-to-frame.
// =============================================================================
class DepthEstimator {
public:
    DepthEstimator();
    ~DepthEstimator();

    // Cấu hình thông số camera
    void SetCameraParams(float focal_px, float ref_height_m);

    // Điều chỉnh tốc độ EMA smoothing (0.05–1.0)
    void SetEmaAlpha(float alpha);

    // Ước lượng khoảng cách 1 object (mét, -1.0f nếu thất bại)
    float Estimate(const TrackedObject& obj);

    // Ước lượng khoảng cách hàng loạt
    std::vector<float> EstimateBatch(const std::vector<TrackedObject>& objects);

    // Xoá lịch sử EMA (gọi khi reset tracker)
    void ClearHistory();

    // Xoá EMA history của track không còn active
    void PurgeStaleHistory(const std::vector<int32_t>& active_ids);

    // Load chiều cao vật thể từ file JSON tùy chỉnh ở runtime
    void LoadCustomHeights(const std::string& json_path);

    // Lấy giá trị tham số hiện tại (debug)
    float GetFocalLength() const { return focal_length_px_; }
    float GetDefaultRefHeight() const { return ref_object_height_m_; }

private:
    // Lấy chiều cao thực tham chiếu theo class COCO hoặc custom
    float GetRefHeight(int class_id) const;

    // Áp dụng EMA smoothing theo track_id
    float ApplyEmaSmoothing(int32_t track_id, float raw_distance);

    float focal_length_px_;         // Tiêu cự camera (pixels)
    float ref_object_height_m_;     // Chiều cao mặc định (m) nếu class không rõ
    float ema_alpha_;               // EMA weight [0.05, 1.0]

    // Bản đồ chiều cao custom tải từ JSON
    std::unordered_map<int, float> custom_height_map_;

    // Bộ nhớ EMA per track_id: {track_id → smoothed_depth}
    std::unordered_map<int32_t, float> depth_history_;
};

} // namespace vision
} // namespace tmod

#endif // TMOD_DEPTH_ESTIMATOR_H

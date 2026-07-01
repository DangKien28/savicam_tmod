// =============================================================================
// byte_track.h
// Mục đích: Interface cho ByteTrack — bộ theo dõi đa vật thể (MOT).
// =============================================================================

#ifndef TMOD_BYTE_TRACK_H
#define TMOD_BYTE_TRACK_H

#include <vector>
#include <cstdint>
#include "yolov8n_engine.h"

namespace tmod {
namespace vision {

// Forward declaration cấu trúc nội bộ (không expose chi tiết ra ngoài)
struct InternalTrack;

// =============================================================================
// TrackedObject — Kết quả tracking của 1 vật thể qua nhiều frame.
// Mục đích: Cung cấp thông tin vị trí + velocity cho DepthEstimator và TTC.
// =============================================================================
struct TrackedObject {
    int32_t track_id;      // ID duy nhất, ổn định qua các frame
    BBox    bbox;          // Bounding box vị trí hiện tại (ảnh gốc pixels)
    float   velocity_x;   // Velocity theo trục X (pixels/frame, + = sang phải)
    float   velocity_y;   // Velocity theo trục Y (pixels/frame, + = xuống dưới)
};

// =============================================================================
// ByteTrack
// Mục đích: Multi-object tracker dùng thuật toán ByteTrack với Kalman Filter.
//           Cung cấp track_id ổn định và velocity estimate cho pipeline TTC.
// =============================================================================
class ByteTrack {
public:
    ByteTrack();
    ~ByteTrack();

    // Cập nhật tracker với detections từ frame mới
    // Trả về danh sách tracks đang active (confirmed)
    std::vector<TrackedObject> Update(const std::vector<BBox>& detections);

    // Lấy danh sách tracks active từ frame gần nhất
    const std::vector<TrackedObject>& GetActiveTracks() const;

    // Reset toàn bộ trạng thái tracker
    void Reset();

    // Số track đang active
    int GetActiveTrackCount() const { return static_cast<int>(tracks_.size()); }

    // Frame count hiện tại (debug)
    int GetFrameCount() const { return frame_count_; }

private:
    // Tính IoU giữa 2 BBox
    static float ComputeIoU(const BBox& a, const BBox& b);

    // Greedy matching giữa track predictions và detections
    void GreedyMatch(
        const std::vector<int>& track_indices,
        const std::vector<int>& det_indices,
        const std::vector<BBox>& detections,
        float iou_thresh,
        std::vector<bool>& matched_track,
        std::vector<bool>& matched_det
    );

    // Danh sách track nội bộ (trạng thái đầy đủ, kể cả Lost)
    std::vector<InternalTrack> internal_tracks_;

    // Cache tracks cho output (chỉ Tracked state)
    std::vector<TrackedObject> tracks_;

    int32_t next_id_;       // ID counter tăng dần
    int     frame_count_;   // Đếm số frame đã xử lý
};

} // namespace vision
} // namespace tmod

#endif // TMOD_BYTE_TRACK_H

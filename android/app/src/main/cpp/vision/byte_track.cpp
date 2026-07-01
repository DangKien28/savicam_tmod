// =============================================================================
// byte_track.cpp
// Mục đích  : Thuật toán tracking đa vật thể (Multi-Object Tracking - MOT)
//             theo phương pháp ByteTrack, tối ưu cho pipeline camera real-time.
// Input     : Danh sách BBox từ YOLOv8n mỗi frame.
// Output    : Danh sách TrackedObject với ID ổn định qua các frame và velocity.
// Cách hoạt :
//   1. Dùng Kalman Filter đơn giản để dự đoán vị trí track frame tiếp theo.
//   2. Tính IoU giữa predicted tracks và detections mới.
//   3. Greedy matching: gán detection có IoU cao nhất cho từng track.
//   4. Track không được match (high confidence) → giữ nhưng đánh dấu Lost.
//   5. Detection không được match → tạo track mới.
//   6. Track Lost quá lâu (>MAX_AGE frame) → xoá (Removed).
// Lý do ByteTrack: Đơn giản, không cần re-ID network, phù hợp edge device.
//   ByteTrack dùng cả high-score và low-score detections để match,
//   giảm ID switch so với SORT thuần tuý.
// =============================================================================

#include "byte_track.h"

#include <android/log.h>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <limits>

#define LOG_TAG_TRACK "TModVision_Track"
#define TRACK_LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG_TRACK, __VA_ARGS__)
#define TRACK_LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG_TRACK, __VA_ARGS__)

namespace tmod {
namespace vision {

// =============================================================================
// Hằng số ByteTrack
// =============================================================================

// Ngưỡng confidence để phân biệt high/low confidence detections
static constexpr float HIGH_CONF_THRESHOLD  = 0.50f;
static constexpr float LOW_CONF_THRESHOLD   = 0.10f;

// IoU threshold để match tracks với detections
static constexpr float HIGH_IOU_THRESHOLD   = 0.30f; // Match track-highconf
static constexpr float LOW_IOU_THRESHOLD    = 0.20f; // Match track-lowconf

// Số frame track bị Lost tối đa trước khi xoá
static constexpr int   MAX_AGE_FRAMES       = 30;   // ~1 giây ở 30FPS

// Số frame tối thiểu để track được coi là "ổn định" (Confirmed)
static constexpr int   MIN_HITS_TO_CONFIRM  = 2;

// =============================================================================
// TrackState — Trạng thái của mỗi track
// =============================================================================
enum class TrackState { New, Tracked, Lost, Removed };

// =============================================================================
// KalmanState — Trạng thái Kalman Filter đơn giản cho 1 track
// Dùng constant velocity model: [cx, cy, w, h, vx, vy, vw, vh]
// =============================================================================
struct KalmanState {
    float cx, cy, w, h;         // Trạng thái vị trí (centre x/y, width, height)
    float vx, vy, vw, vh;       // Velocity (pixel/frame)

    KalmanState() : cx(0), cy(0), w(0), h(0), vx(0), vy(0), vw(0), vh(0) {}

    // Khởi tạo từ BBox
    void InitFromBBox(const BBox& box) {
        cx = (box.x_min + box.x_max) * 0.5f;
        cy = (box.y_min + box.y_max) * 0.5f;
        w  = box.x_max - box.x_min;
        h  = box.y_max - box.y_min;
        vx = vy = vw = vh = 0.0f;
    }

    // Dự đoán trạng thái frame tiếp theo (constant velocity)
    void Predict() {
        cx += vx;
        cy += vy;
        w  += vw;
        h  += vh;
        // Đảm bảo w, h không âm
        w  = std::max(1.0f, w);
        h  = std::max(1.0f, h);
    }

    // Cập nhật từ measurement (detected BBox) với Kalman gain đơn giản
    void Update(const BBox& measured, float gain = 0.7f) {
        float mx = (measured.x_min + measured.x_max) * 0.5f;
        float my = (measured.y_min + measured.y_max) * 0.5f;
        float mw = measured.x_max - measured.x_min;
        float mh = measured.y_max - measured.y_min;

        // Velocity estimation từ innovation
        float innov_x = mx - cx;
        float innov_y = my - cy;
        float innov_w = mw - w;
        float innov_h = mh - h;

        vx = gain * innov_x + (1.0f - gain) * vx;
        vy = gain * innov_y + (1.0f - gain) * vy;
        vw = gain * innov_w + (1.0f - gain) * vw;
        vh = gain * innov_h + (1.0f - gain) * vh;

        // Cập nhật state
        cx += gain * innov_x;
        cy += gain * innov_y;
        w  += gain * innov_w;
        h  += gain * innov_h;
    }

    // Chuyển về BBox (dùng để tính IoU với detections)
    BBox ToBBox(int class_id = -1, float conf = 1.0f) const {
        BBox b;
        b.class_id   = class_id;
        b.confidence = conf;
        b.x_min      = cx - w * 0.5f;
        b.y_min      = cy - h * 0.5f;
        b.x_max      = cx + w * 0.5f;
        b.y_max      = cy + h * 0.5f;
        return b;
    }
};

// =============================================================================
// InternalTrack — Thông tin nội bộ 1 track (không expose ra ngoài)
// =============================================================================
struct InternalTrack {
    int32_t      track_id;      // ID track duy nhất, tăng dần
    TrackState   state;         // Trạng thái track
    KalmanState  kalman;        // Kalman filter state
    BBox         last_bbox;     // BBox cuối cùng được match
    int          age;           // Số frame kể từ khi tạo
    int          hits;          // Số lần được match (detect thành công)
    int          time_since_update; // Số frame kể từ lần match cuối

    // Velocity cuối cùng (lưu để trả cho TrackedObject)
    float vel_x, vel_y;

    // Constructor
    InternalTrack(int32_t id, const BBox& det)
        : track_id(id), state(TrackState::New)
        , age(1), hits(1), time_since_update(0)
        , vel_x(0.0f), vel_y(0.0f)
    {
        kalman.InitFromBBox(det);
        last_bbox = det;
    }
};

// =============================================================================
// Constructor
// =============================================================================
ByteTrack::ByteTrack()
    : next_id_(1)
    , frame_count_(0)
{
    TRACK_LOGI("ByteTrack: Khởi tạo tracker. MAX_AGE=%d, MIN_HITS=%d",
               MAX_AGE_FRAMES, MIN_HITS_TO_CONFIRM);
}

// =============================================================================
// Destructor
// =============================================================================
ByteTrack::~ByteTrack() = default;

// =============================================================================
// Update()
// Mục đích  : Cập nhật tracker với danh sách detections từ frame mới.
// Input     : detections — danh sách BBox từ YOLOv8n.
// Output    : Danh sách TrackedObject với track_id ổn định và velocity.
// Cách hoạt (ByteTrack 2-stage matching):
//   Stage 1: Match tracks đang active với HIGH confidence detections bằng IoU.
//   Stage 2: Match tracks còn lại (Lost) với LOW confidence detections.
//   Tạo track mới cho detections không được match.
//   Xoá track quá cũ.
// =============================================================================
std::vector<TrackedObject> ByteTrack::Update(const std::vector<BBox>& detections) {
    ++frame_count_;

    // -------------------------------------------------------------------------
    // Phân loại detections thành high-confidence và low-confidence
    // -------------------------------------------------------------------------
    std::vector<int> high_det_idx, low_det_idx;
    for (int i = 0; i < static_cast<int>(detections.size()); ++i) {
        if (detections[i].confidence >= HIGH_CONF_THRESHOLD) {
            high_det_idx.push_back(i);
        } else if (detections[i].confidence >= LOW_CONF_THRESHOLD) {
            low_det_idx.push_back(i);
        }
        // Bỏ qua detection quá thấp (<LOW_CONF_THRESHOLD)
    }

    // -------------------------------------------------------------------------
    // Bước 1: Dự đoán trạng thái tất cả internal tracks (Kalman predict step)
    // -------------------------------------------------------------------------
    for (auto& t : internal_tracks_) {
        t.kalman.Predict();
        t.age++;
        t.time_since_update++;
    }

    // -------------------------------------------------------------------------
    // Stage 1: Match active tracks với HIGH confidence detections
    // -------------------------------------------------------------------------
    std::vector<int> active_track_idx;  // Tracks ở trạng thái Tracked hoặc New
    std::vector<int> lost_track_idx;    // Tracks đã Lost

    for (int i = 0; i < static_cast<int>(internal_tracks_.size()); ++i) {
        if (internal_tracks_[i].state == TrackState::Tracked ||
            internal_tracks_[i].state == TrackState::New) {
            active_track_idx.push_back(i);
        } else if (internal_tracks_[i].state == TrackState::Lost) {
            lost_track_idx.push_back(i);
        }
    }

    // Tính ma trận IoU giữa active tracks và high detections
    std::vector<bool> matched_high_det(detections.size(), false);
    std::vector<bool> matched_track(internal_tracks_.size(), false);

    GreedyMatch(active_track_idx, high_det_idx, detections,
                HIGH_IOU_THRESHOLD, matched_track, matched_high_det);

    // -------------------------------------------------------------------------
    // Stage 2: Match lost tracks với LOW confidence detections
    // -------------------------------------------------------------------------
    GreedyMatch(lost_track_idx, low_det_idx, detections,
                LOW_IOU_THRESHOLD, matched_track, matched_high_det);

    // -------------------------------------------------------------------------
    // Cập nhật tracks đã được match
    // -------------------------------------------------------------------------
    for (int ti = 0; ti < static_cast<int>(internal_tracks_.size()); ++ti) {
        auto& t = internal_tracks_[ti];
        if (matched_track[ti]) {
            // Đã được match trong Stage 1 hoặc 2: cập nhật Kalman, reset age
            t.hits++;
            t.time_since_update = 0;
            t.vel_x = t.kalman.vx;
            t.vel_y = t.kalman.vy;
            if (t.hits >= MIN_HITS_TO_CONFIRM || t.state == TrackState::Tracked) {
                t.state = TrackState::Tracked;
            }
        } else {
            // Không được match: chuyển sang Lost
            if (t.state == TrackState::Tracked || t.state == TrackState::New) {
                t.state = TrackState::Lost;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Tạo track mới cho high detections chưa được match
    // -------------------------------------------------------------------------
    for (int di : high_det_idx) {
        if (!matched_high_det[di]) {
            internal_tracks_.emplace_back(next_id_++, detections[di]);
            TRACK_LOGD("ByteTrack: Track mới ID=%d, class=%d, conf=%.2f",
                       internal_tracks_.back().track_id,
                       detections[di].class_id,
                       detections[di].confidence);
        }
    }

    // -------------------------------------------------------------------------
    // Xoá tracks quá cũ (Lost > MAX_AGE frames)
    // -------------------------------------------------------------------------
    internal_tracks_.erase(
        std::remove_if(internal_tracks_.begin(), internal_tracks_.end(),
            [](const InternalTrack& t) {
                return t.state == TrackState::Lost &&
                       t.time_since_update > MAX_AGE_FRAMES;
            }),
        internal_tracks_.end()
    );

    // -------------------------------------------------------------------------
    // Tổng hợp output: chỉ trả các tracks ở trạng thái Tracked (đã confirmed)
    // -------------------------------------------------------------------------
    tracks_.clear();
    for (const auto& t : internal_tracks_) {
        if (t.state == TrackState::Tracked) {
            TrackedObject obj;
            obj.track_id   = t.track_id;
            obj.bbox       = t.kalman.ToBBox(t.last_bbox.class_id, t.last_bbox.confidence);
            obj.velocity_x = t.vel_x;
            obj.velocity_y = t.vel_y;
            tracks_.push_back(obj);
        }
    }

    TRACK_LOGI("ByteTrack: Frame %d — %zu detections → %zu active tracks.",
               frame_count_, detections.size(), tracks_.size());
    return tracks_;
}

// =============================================================================
// GetActiveTracks()
// Mục đích: Trả về cache danh sách tracks cuối cùng (không tính lại).
// =============================================================================
const std::vector<TrackedObject>& ByteTrack::GetActiveTracks() const {
    return tracks_;
}

// =============================================================================
// Reset()
// Mục đích: Xoá toàn bộ trạng thái tracker (dùng khi restart pipeline).
// =============================================================================
void ByteTrack::Reset() {
    internal_tracks_.clear();
    tracks_.clear();
    next_id_      = 1;
    frame_count_  = 0;
    TRACK_LOGI("ByteTrack: Đã reset toàn bộ trạng thái tracker.");
}

// =============================================================================
// [PRIVATE] ComputeIoU()
// Mục đích: Tính IoU giữa BBox predicted từ Kalman và BBox detection.
// =============================================================================
float ByteTrack::ComputeIoU(const BBox& a, const BBox& b) {
    float ix1 = std::max(a.x_min, b.x_min);
    float iy1 = std::max(a.y_min, b.y_min);
    float ix2 = std::min(a.x_max, b.x_max);
    float iy2 = std::min(a.y_max, b.y_max);

    float iw = std::max(0.0f, ix2 - ix1);
    float ih = std::max(0.0f, iy2 - iy1);
    float inter = iw * ih;
    if (inter <= 0.0f) return 0.0f;

    float area_a = (a.x_max - a.x_min) * (a.y_max - a.y_min);
    float area_b = (b.x_max - b.x_min) * (b.y_max - b.y_min);
    float uni    = area_a + area_b - inter;
    return (uni <= 0.0f) ? 0.0f : (inter / uni);
}

// =============================================================================
// [PRIVATE] GreedyMatch()
// Mục đích  : Greedy matching giữa tracks và detections theo IoU.
// Input     : track_indices — index tracks cần match.
//             det_indices   — index detections cần match.
//             detections    — danh sách BBox detections.
//             iou_thresh    — ngưỡng IoU tối thiểu để match.
// Output    : matched_track, matched_det — đánh dấu những index đã được match.
// Cách hoạt : Tính IoU tất cả pairs, sắp xếp theo IoU giảm dần,
//             gán greedy (track chưa match ← det chưa match có IoU cao nhất).
// Lý do Greedy thay vì Hungarian: Nhanh hơn O(n³) vs O(n log n),
//   đủ chính xác cho số track thường <50 trên edge device.
// =============================================================================
void ByteTrack::GreedyMatch(
    const std::vector<int>& track_indices,
    const std::vector<int>& det_indices,
    const std::vector<BBox>& detections,
    float iou_thresh,
    std::vector<bool>& matched_track,
    std::vector<bool>& matched_det)
{
    if (track_indices.empty() || det_indices.empty()) return;

    // Xây dựng danh sách (iou, track_idx, det_idx) cho tất cả pairs
    struct MatchPair {
        float iou;
        int   ti;   // index trong internal_tracks_
        int   di;   // index trong detections
    };
    std::vector<MatchPair> pairs;
    pairs.reserve(track_indices.size() * det_indices.size());

    for (int ti : track_indices) {
        if (matched_track[ti]) continue;
        BBox pred_box = internal_tracks_[ti].kalman.ToBBox(
            internal_tracks_[ti].last_bbox.class_id,
            internal_tracks_[ti].last_bbox.confidence
        );
        for (int di : det_indices) {
            if (matched_det[di]) continue;
            float iou = ComputeIoU(pred_box, detections[di]);
            if (iou >= iou_thresh) {
                pairs.push_back({iou, ti, di});
            }
        }
    }

    // Sắp xếp theo IoU giảm dần
    std::sort(pairs.begin(), pairs.end(),
        [](const MatchPair& a, const MatchPair& b) { return a.iou > b.iou; });

    // Greedy assignment
    for (const auto& p : pairs) {
        if (matched_track[p.ti] || matched_det[p.di]) continue;

        // Match: cập nhật Kalman state của track với measurement
        internal_tracks_[p.ti].kalman.Update(detections[p.di]);
        internal_tracks_[p.ti].last_bbox = detections[p.di];

        matched_track[p.ti] = true;
        matched_det[p.di]   = true;
    }
}

} // namespace vision
} // namespace tmod

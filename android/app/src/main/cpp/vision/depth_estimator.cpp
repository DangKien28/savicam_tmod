// =============================================================================
// depth_estimator.cpp
// Mục đích  : Ước lượng khoảng cách vật thể từ camera mà không cần LiDAR/stereo.
//             Sử dụng mô hình pinhole camera heuristic dựa trên chiều cao bbox.
// Input     : TrackedObject (bbox + class_id) + thông số camera.
// Output    : Khoảng cách ước lượng tính bằng mét.
// Cách hoạt :
//   Công thức pinhole: distance = (ref_height_real × focal_length) / bbox_height_pixels
//   Trong đó:
//     - ref_height_real: chiều cao thực của vật thể theo class (m)
//     - focal_length: tiêu cự camera tính bằng pixels
//     - bbox_height_pixels: chiều cao bounding box trong ảnh (pixels)
// Cải tiến:
//   - Per-class reference heights (người, xe máy, ô tô, xe tải...)
//   - Temporal smoothing bằng EMA để giảm nhiễu frame-to-frame
//   - Clamp khoảng cách về [0.1m, 100m] để tránh giá trị vô lý
// Lý do chọn: Không cần sensor bổ sung, chạy O(1) mỗi object,
//   phù hợp edge device. Độ chính xác ~15-20% ở khoảng cách 1-10m.
// =============================================================================

#include "depth_estimator.h"

#include <android/log.h>
#include <cmath>
#include <algorithm>
#include <unordered_map>
#include <fstream>
#include <nlohmann/json.hpp>

#define LOG_TAG_DEPTH "TModVision_Depth"
#define DEPTH_LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG_DEPTH, __VA_ARGS__)
#define DEPTH_LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG_DEPTH, __VA_ARGS__)
#define DEPTH_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG_DEPTH, __VA_ARGS__)

namespace tmod {
namespace vision {

// =============================================================================
// Kích thước thực tế tham chiếu của các class COCO (mét)
// Mục đích: Cải thiện độ chính xác ước lượng khoảng cách per-class.
// Nguồn: Số liệu trung bình thực tế của phương tiện giao thông Việt Nam.
// =============================================================================
static const float CLASS_REF_HEIGHT[80] = {
    1.70f,  // 0: person (người trưởng thành VN ~1.65-1.70m)
    1.00f,  // 1: bicycle (xe đạp ~1.0m chiều cao tổng)
    1.50f,  // 2: car (ô tô sedan ~1.45-1.55m)
    1.10f,  // 3: motorcycle (xe máy ~1.0-1.2m)
    5.00f,  // 4: airplane
    3.20f,  // 5: bus (xe buýt ~3.0-3.4m)
    4.00f,  // 6: train
    3.50f,  // 7: truck (xe tải ~3.0-4.0m)
    2.00f,  // 8: boat
    0.80f,  // 9: traffic light
    0.60f,  // 10: fire hydrant
    1.00f,  // 11: stop sign
    1.20f,  // 12: parking meter
    0.90f,  // 13: bench
    0.30f,  // 14: bird
    0.35f,  // 15: cat
    0.50f,  // 16: dog
    1.50f,  // 17: horse
    0.80f,  // 18: sheep
    1.40f,  // 19: cow
    3.00f,  // 20: elephant
    1.00f,  // 21: bear
    1.50f,  // 22: zebra
    5.50f,  // 23: giraffe
    0.40f,  // 24: backpack
    1.00f,  // 25: umbrella
    0.30f,  // 26: handbag
    0.10f,  // 27: tie
    0.60f,  // 28: suitcase
    0.25f,  // 29: frisbee
    1.60f,  // 30: skis
    1.50f,  // 31: snowboard
    0.22f,  // 32: sports ball
    1.00f,  // 33: kite
    0.90f,  // 34: baseball bat
    0.20f,  // 35: baseball glove
    1.00f,  // 36: skateboard
    2.00f,  // 37: surfboard
    0.70f,  // 38: tennis racket
    0.30f,  // 39: bottle
    0.22f,  // 40: wine glass
    0.12f,  // 41: cup
    0.20f,  // 42: fork
    0.22f,  // 43: knife
    0.18f,  // 44: spoon
    0.15f,  // 45: bowl
    0.20f,  // 46: banana
    0.10f,  // 47: apple
    0.15f,  // 48: sandwich
    0.10f,  // 49: orange
    0.25f,  // 50: broccoli
    0.20f,  // 51: carrot
    0.15f,  // 52: hot dog
    0.30f,  // 53: pizza
    0.10f,  // 54: donut
    0.15f,  // 55: cake
    0.90f,  // 56: chair
    0.80f,  // 57: couch
    0.50f,  // 58: potted plant
    0.60f,  // 59: bed
    0.80f,  // 60: dining table
    0.80f,  // 61: toilet
    0.60f,  // 62: tv
    0.03f,  // 63: laptop
    0.03f,  // 64: mouse
    0.02f,  // 65: remote
    0.03f,  // 66: keyboard
    0.14f,  // 67: cell phone
    0.45f,  // 68: microwave
    0.50f,  // 69: oven
    0.30f,  // 70: toaster
    0.40f,  // 71: sink
    1.70f,  // 72: refrigerator
    0.25f,  // 73: book
    0.25f,  // 74: clock
    0.30f,  // 75: vase
    0.20f,  // 76: scissors
    0.40f,  // 77: teddy bear
    0.22f,  // 78: hair drier
    0.20f,  // 79: toothbrush
};

// =============================================================================
// Constructor
// Mục đích: Khởi tạo với thông số camera mặc định phù hợp camera smartphone.
// focal_length_px_ = 500px: Phù hợp FOV ~70° trên màn hình 640px width.
// =============================================================================
DepthEstimator::DepthEstimator()
    : focal_length_px_(500.0f)
    , ref_object_height_m_(1.7f)
    , ema_alpha_(0.4f)      // EMA weight: 0.4 = balance giữa responsiveness và smoothness
{
    DEPTH_LOGI("DepthEstimator: Khởi tạo. focal=%.1fpx, ref_h=%.2fm, EMA_alpha=%.2f",
               focal_length_px_, ref_object_height_m_, ema_alpha_);
}

// =============================================================================
// Destructor
// =============================================================================
DepthEstimator::~DepthEstimator() {
    depth_history_.clear();
}

// =============================================================================
// SetCameraParams()
// Mục đích  : Cấu hình thông số camera thực tế của thiết bị.
// Input     : focal_px — tiêu cự tính bằng pixels (lấy từ Camera2 API).
//             ref_height_m — chiều cao tham chiếu mặc định (bị override per-class).
// Cách tính focal_px từ FOV: focal_px = (width/2) / tan(hFOV/2)
//   Ví dụ: FOV=75°, width=1280 → focal_px = 640 / tan(37.5°) ≈ 833px
// =============================================================================
void DepthEstimator::SetCameraParams(float focal_px, float ref_height_m) {
    if (focal_px > 0.0f) focal_length_px_   = focal_px;
    if (ref_height_m > 0.0f) ref_object_height_m_ = ref_height_m;
    DEPTH_LOGI("DepthEstimator: Cấu hình camera — focal=%.1fpx, default_ref_h=%.2fm",
               focal_length_px_, ref_object_height_m_);
}

// =============================================================================
// SetEmaAlpha()
// Mục đích: Điều chỉnh tốc độ làm mịn EMA.
// alpha=1.0 → không làm mịn, alpha=0.1 → rất mịn nhưng chậm phản ứng.
// =============================================================================
void DepthEstimator::SetEmaAlpha(float alpha) {
    ema_alpha_ = std::max(0.05f, std::min(1.0f, alpha));
}

// =============================================================================
// Estimate()
// Mục đích  : Ước lượng khoảng cách 1 TrackedObject từ bbox height.
// Input     : obj — TrackedObject với bbox và class_id.
// Output    : Khoảng cách (mét), -1.0f nếu không ước lượng được.
// Cách hoạt :
//   1. Lấy chiều cao bbox tính bằng pixels (bbox_h).
//   2. Lấy chiều cao thực tham chiếu theo class_id.
//   3. Công thức pinhole: d = (real_h × focal) / bbox_h.
//   4. Áp dụng EMA smoothing theo track_id.
//   5. Clamp về [0.1m, 100m].
// =============================================================================
float DepthEstimator::Estimate(const TrackedObject& obj) {
    // Tính chiều cao bbox tính bằng pixels
    float bbox_h = std::abs(obj.bbox.y_max - obj.bbox.y_min);
    if (bbox_h < 2.0f) {
        // Bbox quá nhỏ → không đáng tin cậy
        return -1.0f;
    }

    // Lấy chiều cao thực tế tham chiếu theo class
    float real_h = GetRefHeight(obj.bbox.class_id);

    // Công thức pinhole camera: distance = (real_height × focal) / bbox_height_px
    float raw_distance = (real_h * focal_length_px_) / bbox_h;

    // Clamp vào khoảng vật lý hợp lý
    raw_distance = std::max(0.1f, std::min(raw_distance, 100.0f));

    // Áp dụng EMA smoothing theo track_id để giảm jitter
    float smoothed = ApplyEmaSmoothing(obj.track_id, raw_distance);

    DEPTH_LOGD("DepthEstimator: Track#%d class=%d bbox_h=%.1fpx real_h=%.2fm "
               "raw=%.2fm smooth=%.2fm",
               obj.track_id, obj.bbox.class_id, bbox_h, real_h,
               raw_distance, smoothed);

    return smoothed;
}

// =============================================================================
// EstimateBatch()
// Mục đích  : Ước lượng khoảng cách cho danh sách TrackedObject.
// Input     : objects — danh sách từ ByteTrack.
// Output    : distances — vector khoảng cách tương ứng (cùng thứ tự).
// =============================================================================
std::vector<float> DepthEstimator::EstimateBatch(
    const std::vector<TrackedObject>& objects)
{
    std::vector<float> distances;
    distances.reserve(objects.size());
    for (const auto& obj : objects) {
        distances.push_back(Estimate(obj));
    }
    return distances;
}

// =============================================================================
// ClearHistory()
// Mục đích: Xoá bộ nhớ EMA (gọi khi reset tracker).
// =============================================================================
void DepthEstimator::ClearHistory() {
    depth_history_.clear();
    DEPTH_LOGI("DepthEstimator: Đã xoá lịch sử EMA.");
}

// =============================================================================
// LoadCustomHeights()
// Mục đích: Tải bản đồ chiều cao tùy chỉnh từ tệp JSON ở runtime.
// - Tránh việc hard-code các giá trị chiều cao, cho phép thay đổi cấu hình
//   linh hoạt theo từng loại camera hoặc môi trường lắp đặt mà không cần build lại.
// - Không throw exception và không gây crash nếu tệp JSON bị lỗi hoặc thiếu dữ liệu.
// - Chạy mượt mà trên môi trường Android NDK.
// =============================================================================
void DepthEstimator::LoadCustomHeights(const std::string& json_path) {
    custom_height_map_.clear();
    std::ifstream f(json_path);
    if (!f.is_open()) {
        DEPTH_LOGE("DepthEstimator: Khong the mo file JSON tai: %s (fail)", json_path.c_str());
        return;
    }

    try {
        // Dùng parse của nlohmann/json với allow_exceptions = false để tránh crash do exception
        nlohmann::json j = nlohmann::json::parse(f, nullptr, false);
        if (j.is_discarded()) {
            DEPTH_LOGE("DepthEstimator: JSON loi cu phap hoac bi discarded tai: %s (fail)", json_path.c_str());
            return;
        }

        if (!j.is_object()) {
            DEPTH_LOGE("DepthEstimator: JSON root phai la mot JSON object tai: %s (fail)", json_path.c_str());
            return;
        }

        for (auto& el : j.items()) {
            try {
                // Key của JSON là chuỗi số đại diện cho class_id (vd: "0", "2", "3")
                int class_id = std::stoi(el.key());
                if (el.value().is_number()) {
                    float height = el.value().get<float>();
                    if (height > 0.0f) {
                        custom_height_map_[class_id] = height;
                    }
                }
            } catch (...) {
                // Bỏ qua các phần tử đơn lẻ bị lỗi phân tích cú pháp
            }
        }
        DEPTH_LOGI("DepthEstimator: Load thanh cong %zu custom heights tu %s (success)",
                   custom_height_map_.size(), json_path.c_str());
    } catch (const std::exception& e) {
        DEPTH_LOGE("DepthEstimator: Gap ngoai le khi load custom heights: %s (fail)", e.what());
    } catch (...) {
        DEPTH_LOGE("DepthEstimator: Loi khong xac dinh khi load custom heights (fail)");
    }
}

// =============================================================================
// [PRIVATE] GetRefHeight()
// Mục đích: Lấy chiều cao thực tế tham chiếu của vật thể theo class_id.
// - Tại sao không hard-code nữa: Việc hard-code hạn chế khả năng tùy biến khi cấu hình
//   camera thay đổi hoặc khi chạy thử nghiệm trên các bộ dataset thực tế khác nhau.
// - Vì sao cần custom height: Cho phép ưu tiên sử dụng chiều cao từ dataset riêng (custom_height_map_)
//   được tải động ở runtime, giúp tăng tính linh hoạt và chính xác cho hệ thống.
// - Vì sao dùng fallback: Nếu không có cấu hình tùy chỉnh cho class cụ thể, ta cần
//   fallback về bộ CLASS_REF_HEIGHT (COCO chuẩn) để đảm bảo luôn ước lượng được.
//   Nếu class_id nằm ngoài khoảng COCO [0, 79], fallback cuối cùng về ref_object_height_m_
//   nhằm tránh trả về giá trị lỗi hoặc gây lỗi bộ nhớ.
// =============================================================================
float DepthEstimator::GetRefHeight(int class_id) const {
    // Ưu tiên dataset riêng
    if (custom_height_map_.count(class_id)) {
        DEPTH_LOGD("DepthEstimator: GetRefHeight class=%d [custom] -> %.2fm", class_id, custom_height_map_.at(class_id));
        return custom_height_map_.at(class_id);
    }

    // fallback COCO
    if (class_id >= 0 && class_id < 80) {
        DEPTH_LOGD("DepthEstimator: GetRefHeight class=%d [coco] -> %.2fm", class_id, CLASS_REF_HEIGHT[class_id]);
        return CLASS_REF_HEIGHT[class_id];
    }

    // fallback cuối
    DEPTH_LOGD("DepthEstimator: GetRefHeight class=%d [default] -> %.2fm", class_id, ref_object_height_m_);
    return ref_object_height_m_;
}

// =============================================================================
// [PRIVATE] ApplyEmaSmoothing()
// Mục đích  : Exponential Moving Average để làm mịn depth theo track_id.
// Công thức : ema_new = alpha × raw + (1-alpha) × ema_old
// Lý do EMA : EMA thích hợp hơn SMA vì ưu tiên giá trị gần đây,
//             phản ứng nhanh với sự thay đổi thực nhưng lọc được nhiễu nhỏ.
// =============================================================================
float DepthEstimator::ApplyEmaSmoothing(int32_t track_id, float raw_distance) {
    auto it = depth_history_.find(track_id);
    if (it == depth_history_.end()) {
        // Track mới: khởi tạo EMA bằng raw value
        depth_history_[track_id] = raw_distance;
        return raw_distance;
    }

    // Cập nhật EMA
    float& ema = it->second;
    ema = ema_alpha_ * raw_distance + (1.0f - ema_alpha_) * ema;
    return ema;
}

// =============================================================================
// PurgeStaleHistory()
// Mục đích  : Xoá EMA history của các track không còn active.
// Input     : active_ids — danh sách track_id đang active.
// Lý do    : Tránh memory leak khi có nhiều track tạo rồi xoá theo thời gian.
// =============================================================================
void DepthEstimator::PurgeStaleHistory(const std::vector<int32_t>& active_ids) {
    // Tạo set active ids để lookup O(log n)
    std::vector<int32_t> sorted_ids = active_ids;
    std::sort(sorted_ids.begin(), sorted_ids.end());

    for (auto it = depth_history_.begin(); it != depth_history_.end(); ) {
        bool is_active = std::binary_search(sorted_ids.begin(), sorted_ids.end(), it->first);
        if (!is_active) {
            it = depth_history_.erase(it);
        } else {
            ++it;
        }
    }
}

} // namespace vision
} // namespace tmod

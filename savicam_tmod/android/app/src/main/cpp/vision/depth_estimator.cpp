#include "depth_estimator.h"
#include <cmath>

namespace tmod {
namespace vision {

DepthEstimator::DepthEstimator() : focal_length_px_(500.0f), ref_object_height_m_(1.7f) {}

void DepthEstimator::SetCameraParams(float focal_px, float ref_height_m) {
    focal_length_px_ = focal_px;
    ref_object_height_m_ = ref_height_m;
}

float DepthEstimator::Estimate(const TrackedObject& obj) {
    float bbox_h = std::abs(obj.bbox.y_max - obj.bbox.y_min);
    if (bbox_h <= 0.0f) return -1.0f;
    return (ref_object_height_m_ * focal_length_px_) / bbox_h;
}

} // namespace vision
} // namespace tmod

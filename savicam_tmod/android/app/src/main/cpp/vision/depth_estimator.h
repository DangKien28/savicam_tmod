#ifndef TMOD_DEPTH_ESTIMATOR_H
#define TMOD_DEPTH_ESTIMATOR_H

#include "byte_track.h"

namespace tmod {
namespace vision {

class DepthEstimator {
private:
    float focal_length_px_;
    float ref_object_height_m_;

public:
    DepthEstimator();
    void SetCameraParams(float focal_px, float ref_height_m);
    float Estimate(const TrackedObject& obj);
};

} // namespace vision
} // namespace tmod

#endif // TMOD_DEPTH_ESTIMATOR_H

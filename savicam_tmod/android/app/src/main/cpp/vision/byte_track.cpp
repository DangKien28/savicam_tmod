#include "byte_track.h"

namespace tmod {
namespace vision {

ByteTrack::ByteTrack() : next_id_(1) {}

std::vector<TrackedObject> ByteTrack::Update(const std::vector<BBox>& detections) {
    tracks_.clear();
    for (const auto& det : detections) {
        TrackedObject obj;
        obj.track_id = next_id_++;
        obj.bbox = det;
        obj.velocity_x = 0.0f;
        obj.velocity_y = 0.0f;
        tracks_.push_back(obj);
    }
    return tracks_;
}

const std::vector<TrackedObject>& ByteTrack::GetActiveTracks() const {
    return tracks_;
}

} // namespace vision
} // namespace tmod

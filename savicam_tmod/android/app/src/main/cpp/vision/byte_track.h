#ifndef TMOD_BYTE_TRACK_H
#define TMOD_BYTE_TRACK_H

#include <vector>
#include <cstdint>
#include "yolov8n_engine.h"

namespace tmod {
namespace vision {

struct TrackedObject {
    int32_t track_id;
    BBox    bbox;
    float   velocity_x;
    float   velocity_y;
};

class ByteTrack {
private:
    int32_t next_id_;
    std::vector<TrackedObject> tracks_;

public:
    ByteTrack();
    std::vector<TrackedObject> Update(const std::vector<BBox>& detections);
    const std::vector<TrackedObject>& GetActiveTracks() const;
};

} // namespace vision
} // namespace tmod

#endif // TMOD_BYTE_TRACK_H

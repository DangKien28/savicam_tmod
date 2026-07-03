// android/app/src/main/cpp/vision/yolov8n_engine.h
#ifndef TMOD_YOLOV8N_ENGINE_H
#define TMOD_YOLOV8N_ENGINE_H

#include <vector>
#include <cstdint>
#include <stdint.h>

namespace tmod {
namespace vision {

struct BBox {
    int32_t class_id;
    float   confidence;
    float   x_min, y_min, x_max, y_max;
};

class YoloV8nEngine {
public:
    YoloV8nEngine();
    bool Init(const char* model_path);
    std::vector<BBox> Detect(const uint8_t* frame_data, int32_t w, int32_t h);
};

} // namespace vision
} // namespace tmod

#endif // TMOD_YOLOV8N_ENGINE_H
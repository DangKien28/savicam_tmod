#include "yolov8n_engine.h"
#include <android/log.h>

#define LOG_TAG_YOLO "TModVision_YOLO"
#define YOLO_LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG_YOLO, __VA_ARGS__)

namespace tmod {
namespace vision {

YoloV8nEngine::YoloV8nEngine() {}

bool YoloV8nEngine::Init(const char* model_path) {
    YOLO_LOGI("Khởi tạo YOLOv8n engine từ: %s", model_path);
    return true;
}

std::vector<BBox> YoloV8nEngine::Detect(const uint8_t* rgba, int32_t w, int32_t h) {
    YOLO_LOGI("Detect trên ảnh %dx%d", w, h);
    return {};
}

} // namespace vision
} // namespace tmod

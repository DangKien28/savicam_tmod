// android/app/src/main/cpp/vision/yolov8n_engine.cpp
#include "yolov8n_engine.h"
#include <android/log.h>
#include <vector>
#include <cstdint>

#define LOG_TAG_YOLO "TModVision_YOLO"
#define YOLO_LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG_YOLO, __VA_ARGS__)

namespace tmod {
namespace vision {

YoloV8nEngine::YoloV8nEngine() {}

bool YoloV8nEngine::Init(const char* model_path) {
    YOLO_LOGI("Khởi tạo YOLOv8n engine từ: %s", model_path);
    return true;
}

std::vector<BBox> YoloV8nEngine::Detect(const uint8_t* frame_data, int32_t w, int32_t h) {
    YOLO_LOGI("Detect trên ảnh Grayscale %dx%d, con trỏ vùng nhớ: %p", w, h, (void*)frame_data);

    std::vector<BBox> mock_results;
    BBox mock_box = { 1, 0.95f, 0.1f, 0.1f, 0.5f, 0.5f }; 
    mock_results.push_back(mock_box);

    return mock_results;
}

} // namespace vision
} // namespace tmod
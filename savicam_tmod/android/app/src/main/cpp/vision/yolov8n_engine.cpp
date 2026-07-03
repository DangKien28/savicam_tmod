#include "yolov8n_engine.h"
#include <android/log.h>

#define LOG_TAG_YOLO "TModVision_YOLO"
#define YOLO_LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG_YOLO, __VA_ARGS__)

namespace tmod {
namespace vision {

YoloV8nEngine::YoloV8nEngine() {}

bool YoloV8nEngine::Init(const char* model_path) {
    YOLO_LOGI("Khởi tạo YOLOv8n engine từ: %s", model_path);
    // Logic khởi tạo model TFLite và gán NNAPI Delegate sẽ được đưa vào đây
    return true;
}

std::vector<BBox> YoloV8nEngine::Detect(const uint8_t* frame_data, int32_t w, int32_t h) {
    // Xác nhận đã nhận được con trỏ chứa bytes ảnh xám từ Dart
    YOLO_LOGI("Detect trên ảnh Grayscale %dx%d, con trỏ vùng nhớ: %p", w, h, frame_data);

    // TODO: Chèn logic OpenCV tại đây khi đã chuẩn bị xong mô hình thực tế
    // cv::Mat img(h, w, CV_8UC1, (void*)frame_data);
    // cv::Mat resized_img;
    // cv::resize(img, resized_img, cv::Size(640, 640));
    // tensor_input = resized_img.data;
    // tflite_interpreter->Invoke();

    // Trả về mock 1 object phát hiện được để test luồng tín hiệu truyền ngược lên VisionAlertController
    std::vector<BBox> mock_results;
    BBox mock_box = { 1, 0.95f, 0.1f, 0.1f, 0.5f, 0.5f }; // Class 1
    mock_results.push_back(mock_box);

    return mock_results;
}

} // namespace vision
} // namespace tmod
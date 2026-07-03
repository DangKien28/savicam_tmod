// android/app/src/main/cpp/ffi_exports.cpp
#include <cstdint>
#include <stdint.h>
#include <cstring>
#include <vector>
#include <android/log.h>
#include "vision/yolov8n_engine.h"

#define LOG_TAG "SaViCam_FFI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

struct DetectionResult {
    int32_t class_id;    
    float   confidence;
    float   x_min;
    float   y_min;
    float   x_max;
    float   y_max;
    int32_t track_id;       
    float   distance_m;     
};

struct FrameResult {
    int32_t risk_level;         
    float   ttc_seconds;        
    float   nearest_distance_m; 
    int32_t num_detections;     
    int32_t nearest_class_id;   
};

static bool g_core_initialized = false;
static tmod::vision::YoloV8nEngine* g_yolo_engine = nullptr;

extern "C" {

__attribute__((visibility("default")))
int32_t tmod_init_core(const char* model_path) {
    LOGI("tmod_init_core: Khởi tạo pipeline CV với model: %s", model_path);

    if (g_yolo_engine == nullptr) {
        g_yolo_engine = new tmod::vision::YoloV8nEngine();
    }
    
    bool init_success = g_yolo_engine->Init(model_path);
    if (!init_success) {
        LOGE("tmod_init_core: Lỗi khởi tạo YOLOv8n engine.");
        return 0;
    }

    g_core_initialized = true;
    LOGI("tmod_init_core: Pipeline CV khởi tạo hoàn tất.");
    return 1;
}

__attribute__((visibility("default")))
int32_t tmod_process_frame(const uint8_t* frame_data, int32_t width, int32_t height, FrameResult* result) {
    if (!g_core_initialized || !frame_data || !result) {
        LOGE("tmod_process_frame: Core chưa init hoặc tham số null.");
        return 0;
    }

    std::vector<tmod::vision::BBox> bboxes = g_yolo_engine->Detect(frame_data, width, height);

    result->num_detections = bboxes.size();
    
    if (bboxes.empty()) {
        result->risk_level = 0;
        result->ttc_seconds = 999.0f;
        result->nearest_distance_m = 99.0f;
        result->nearest_class_id = -1;
    } else {
        result->risk_level = 2; 
        result->ttc_seconds = 2.5f;
        result->nearest_distance_m = 2.0f;
        result->nearest_class_id = bboxes[0].class_id;
    }

    return 1;
}

__attribute__((visibility("default")))
int32_t tmod_get_detections(DetectionResult* out_buffer, int32_t max_count) {
    if (!g_core_initialized || !out_buffer || max_count <= 0) {
        return 0;
    }
    return 0; 
}

__attribute__((visibility("default")))
void tmod_release_core() {
    LOGI("tmod_release_core: Giải phóng tài nguyên pipeline CV.");
    if (g_yolo_engine != nullptr) {
        delete g_yolo_engine;
        g_yolo_engine = nullptr;
    }
    g_core_initialized = false;
}

__attribute__((visibility("default")))
int32_t tmod_is_initialized() {
    return g_core_initialized ? 1 : 0;
}

__attribute__((visibility("default")))
int32_t tmod_get_last_risk_level() {
    if (!g_core_initialized) return 0;
    return 0; 
}

} // extern "C"
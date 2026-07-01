// =============================================================================
// yolov8n_engine.h
// Mục đích: Interface cho YOLOv8nEngine — object detection TFLite pipeline.
// =============================================================================

#ifndef TMOD_YOLOV8N_ENGINE_H
#define TMOD_YOLOV8N_ENGINE_H

#include <vector>
#include <cstdint>
#include <memory>
#include "../core/tflite_runner.h"

namespace tmod {
namespace vision {

// =============================================================================
// BBox — Bounding box kết quả phát hiện
// Mục đích: Lưu thông tin 1 đối tượng được nhận diện.
//           Toạ độ theo không gian ảnh gốc (pixels).
// =============================================================================
struct BBox {
    int32_t class_id;              // Index class COCO (0–79)
    float   confidence;            // Điểm tin cậy [0, 1]
    float   x_min, y_min;          // Góc trên-trái bounding box (pixels)
    float   x_max, y_max;          // Góc dưới-phải bounding box (pixels)
};

// =============================================================================
// YoloV8nEngine
// Mục đích: Nhận diện vật thể real-time từ ảnh camera bằng YOLOv8n TFLite.
// Thread safety: KHÔNG thread-safe. Sử dụng trong 1 thread inference duy nhất.
// =============================================================================
class YoloV8nEngine {
public:
    YoloV8nEngine();
    ~YoloV8nEngine();

    // Khởi tạo engine với model file
    bool Init(const char* model_path);

    // Nhận diện vật thể trong 1 frame RGBA
    std::vector<BBox> Detect(const uint8_t* rgba, int32_t w, int32_t h);

    // Trả về tên class COCO từ class_id
    static const char* GetClassName(int class_id);

    // Kiểm tra trạng thái
    bool IsInitialized() const { return is_initialized_; }

private:
    // Tiền xử lý: RGBA → letterbox float32 tensor 640×640×3
    void Preprocess(const uint8_t* rgba, int32_t w, int32_t h);

    // Giải mã output tensor + NMS
    std::vector<BBox> DecodeAndNms(const std::vector<float>& raw_output);

    // Tính Intersection-over-Union
    static float ComputeIoU(const BBox& a, const BBox& b);

    // TFLite runner (owned)
    std::unique_ptr<tmod::core::TFLiteRunner> tflite_runner_;

    // Buffers tái sử dụng (tránh allocation mỗi frame)
    std::vector<float> input_tensor_;   // 640×640×3 floats
    std::vector<float> output_tensor_;  // 84×8400 floats

    bool    is_initialized_;

    // Thông số letterbox (lưu để undo sau inference)
    int32_t img_w_, img_h_;  // Kích thước ảnh gốc
    float   scale_;          // Tỷ lệ scale letterbox
    int     pad_x_, pad_y_;  // Padding để căn giữa
};

} // namespace vision
} // namespace tmod

#endif // TMOD_YOLOV8N_ENGINE_H

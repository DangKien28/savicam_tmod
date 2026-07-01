// =============================================================================
// yolov8n_engine.cpp
// Mục đích  : Engine nhận diện vật thể YOLOv8n thời gian thực qua TFLite.
//             Bao gồm toàn bộ pipeline: tiền xử lý ảnh → inference → hậu xử lý.
// Input     : Buffer ảnh RGBA thô từ camera Android.
// Output    : Danh sách BBox chứa class_id, confidence, toạ độ bounding box.
// Cách hoạt :
//   1. Letterbox resize ảnh RGBA về 640×640 (giữ tỷ lệ khung hình)
//   2. Chuyển RGBA→RGB, normalize về [0,1] float32
//   3. Gọi TFLiteRunner.RunInference()
//   4. Decode output tensor YOLOv8n: [1×84×8400] → [cx,cy,w,h, cls_scores×80]
//   5. NMS (Non-Maximum Suppression) lọc box trùng lặp
// Lý do chọn YOLOv8n: Model nhỏ nhất (~3.2MB), phù hợp thiết bị edge,
//   đạt ~50FPS trên Snapdragon 8 Gen1 với NNAPI INT8 quantization.
// =============================================================================

#include "yolov8n_engine.h"

#include <android/log.h>
#include <cmath>
#include <cstring>
#include <algorithm>
#include <numeric>

#define LOG_TAG_YOLO "TModVision_YOLO"
#define YOLO_LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG_YOLO, __VA_ARGS__)
#define YOLO_LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG_YOLO, __VA_ARGS__)
#define YOLO_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG_YOLO, __VA_ARGS__)

namespace tmod {
namespace vision {

// =============================================================================
// Hằng số YOLOv8n
// =============================================================================

// Kích thước input chuẩn của YOLOv8n
static constexpr int   YOLO_INPUT_W  = 640;
static constexpr int   YOLO_INPUT_H  = 640;
static constexpr int   YOLO_CHANNELS = 3;

// Output tensor shape: [1 × 84 × 8400]
// 84 = 4 (cx,cy,w,h) + 80 (COCO class scores)
static constexpr int   YOLO_NUM_ANCHORS    = 8400;
static constexpr int   YOLO_NUM_FEATURES   = 84;  // 4 bbox + 80 classes
static constexpr int   YOLO_NUM_CLASSES    = 80;
static constexpr int   YOLO_BBOX_DIMS      = 4;

// Ngưỡng confidence và NMS
static constexpr float CONF_THRESHOLD      = 0.30f; // Lọc boxes yếu
static constexpr float NMS_IOU_THRESHOLD   = 0.45f; // Ngưỡng IoU cho NMS

// =============================================================================
// COCO class names (80 classes) — dùng cho logging
// =============================================================================
static const char* COCO_CLASSES[80] = {
    "person","bicycle","car","motorcycle","airplane","bus","train","truck",
    "boat","traffic light","fire hydrant","stop sign","parking meter","bench",
    "bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe",
    "backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard",
    "sports ball","kite","baseball bat","baseball glove","skateboard","surfboard",
    "tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl",
    "banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza",
    "donut","cake","chair","couch","potted plant","bed","dining table","toilet",
    "tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven",
    "toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear",
    "hair drier","toothbrush"
};

// =============================================================================
// Constructor
// =============================================================================
YoloV8nEngine::YoloV8nEngine()
    : is_initialized_(false)
    , img_w_(0)
    , img_h_(0)
    , scale_(1.0f)
    , pad_x_(0)
    , pad_y_(0)
{
    // Pre-allocate input tensor buffer (640×640×3 floats = 1,228,800)
    input_tensor_.resize(YOLO_INPUT_W * YOLO_INPUT_H * YOLO_CHANNELS, 0.0f);
    output_tensor_.resize(YOLO_NUM_FEATURES * YOLO_NUM_ANCHORS, 0.0f);
    YOLO_LOGI("YoloV8nEngine: Constructor hoàn tất, buffer pre-allocated.");
}

// =============================================================================
// Destructor
// =============================================================================
YoloV8nEngine::~YoloV8nEngine() {
    tflite_runner_.reset();
    YOLO_LOGI("YoloV8nEngine: Đã giải phóng tài nguyên.");
}

// =============================================================================
// Init()
// Mục đích  : Nạp model YOLOv8n .tflite và cấu hình TFLiteRunner.
// Input     : model_path — đường dẫn tuyệt đối tới file .tflite trên thiết bị.
// Output    : true nếu thành công.
// Cách hoạt : Tạo TFLiteRunner với NNAPI=true (tự fallback CPU nếu cần).
// =============================================================================
bool YoloV8nEngine::Init(const char* model_path) {
    if (!model_path) {
        YOLO_LOGE("YoloV8nEngine: model_path là null!");
        return false;
    }
    YOLO_LOGI("YoloV8nEngine: Khởi tạo từ model: %s", model_path);

    // Tạo TFLiteRunner với NNAPI ưu tiên
    tflite_runner_ = std::make_unique<tmod::core::TFLiteRunner>(
        std::string(model_path), /*use_nnapi=*/true
    );
    tflite_runner_->SetNumThreads(4);  // 4 threads cho inference CPU

    if (!tflite_runner_->LoadModel()) {
        YOLO_LOGE("YoloV8nEngine: LoadModel() thất bại!");
        tflite_runner_.reset();
        return false;
    }

    is_initialized_ = true;
    YOLO_LOGI("YoloV8nEngine: Khởi tạo thành công. "
              "Input=%zu floats. NNAPI=%s.",
              tflite_runner_->GetInputSize(),
              tflite_runner_->IsUsingNnapi() ? "BẬT" : "TẮT (CPU)");
    return true;
}

// =============================================================================
// Detect()
// Mục đích  : Nhận diện vật thể trong 1 khung hình camera.
// Input     : rgba — buffer pixel RGBA 8-bit từ camera Android.
//             w, h — chiều rộng và cao của ảnh gốc.
// Output    : Danh sách BBox với toạ độ theo không gian ảnh GỐC (không phải 640×640).
// Cách hoạt :
//   1. Letterbox RGBA → float32 tensor [1×640×640×3]
//   2. RunInference
//   3. Decode + NMS
//   4. Scale box về kích thước ảnh gốc
// =============================================================================
std::vector<BBox> YoloV8nEngine::Detect(const uint8_t* rgba, int32_t w, int32_t h) {
    if (!is_initialized_ || !rgba || w <= 0 || h <= 0) {
        YOLO_LOGE("YoloV8nEngine: Detect — tham số không hợp lệ hoặc chưa init.");
        return {};
    }

    // Lưu kích thước ảnh gốc cho bước scale box sau
    img_w_ = w;
    img_h_ = h;

    // -------------------------------------------------------------------------
    // Bước 1: Tiền xử lý — Letterbox + RGBA→RGB + Normalize
    // -------------------------------------------------------------------------
    Preprocess(rgba, w, h);

    // -------------------------------------------------------------------------
    // Bước 2: TFLite Inference
    // -------------------------------------------------------------------------
    if (!tflite_runner_->RunInference(input_tensor_, output_tensor_)) {
        YOLO_LOGE("YoloV8nEngine: RunInference() thất bại!");
        return {};
    }

    // -------------------------------------------------------------------------
    // Bước 3: Decode output tensor + NMS
    // -------------------------------------------------------------------------
    std::vector<BBox> results = DecodeAndNms(output_tensor_);

    YOLO_LOGI("YoloV8nEngine: Detect %dx%d → %zu objects sau NMS.",
              w, h, results.size());
    return results;
}

// =============================================================================
// [PRIVATE] Preprocess()
// Mục đích  : Chuyển đổi ảnh RGBA → float32 tensor 640×640×3 theo letterbox.
// Input     : rgba — buffer RGBA, w/h kích thước gốc.
// Output    : input_tensor_ được điền dữ liệu chuẩn hoá [0,1].
// Cách hoạt :
//   - Tính scale = min(640/w, 640/h) để giữ aspect ratio
//   - Tính padding offset (pad_x_, pad_y_) để căn giữa
//   - Dùng bilinear sampling đơn giản để resize
//   - Loại kênh Alpha, normalize /255.0f
// Lý do letterbox: Tránh méo ảnh khi resize thẳng về 640×640,
//   giúp model nhận dạng chính xác hơn.
// =============================================================================
void YoloV8nEngine::Preprocess(const uint8_t* rgba, int32_t w, int32_t h) {
    // Tính tỷ lệ scale để vừa với 640×640 (giữ aspect ratio)
    scale_ = std::min(static_cast<float>(YOLO_INPUT_W) / w,
                      static_cast<float>(YOLO_INPUT_H) / h);

    int new_w = static_cast<int>(std::round(w * scale_));
    int new_h = static_cast<int>(std::round(h * scale_));

    // Tính padding để căn giữa ảnh đã resize trong 640×640
    pad_x_ = (YOLO_INPUT_W - new_w) / 2;
    pad_y_ = (YOLO_INPUT_H - new_h) / 2;

    // Lấp đầy input tensor bằng màu xám trung tính (114/255 theo YOLO convention)
    constexpr float FILL_VALUE = 114.0f / 255.0f;
    std::fill(input_tensor_.begin(), input_tensor_.end(), FILL_VALUE);

    // Resize + chuyển đổi kênh màu (nearest-neighbor cho tốc độ)
    // Format output tensor: NCHW hay NHWC → YOLOv8 dùng NHWC (1,640,640,3)
    for (int row = 0; row < new_h; ++row) {
        for (int col = 0; col < new_w; ++col) {
            // Toạ độ pixel nguồn (bilinear nearest)
            int src_x = static_cast<int>(col / scale_);
            int src_y = static_cast<int>(row / scale_);

            // Clamp để tránh out-of-bounds
            src_x = std::min(src_x, w - 1);
            src_y = std::min(src_y, h - 1);

            // Đọc pixel RGBA từ ảnh gốc
            int src_idx = (src_y * w + src_x) * 4;  // 4 bytes per pixel (RGBA)
            float r = rgba[src_idx + 0] / 255.0f;
            float g = rgba[src_idx + 1] / 255.0f;
            float b = rgba[src_idx + 2] / 255.0f;
            // Alpha (rgba[src_idx+3]) bỏ qua

            // Toạ độ đích trong tensor 640×640
            int dst_x = col + pad_x_;
            int dst_y = row + pad_y_;

            // Ghi vào tensor theo format NHWC: [batch=0, y, x, channel]
            int base = (dst_y * YOLO_INPUT_W + dst_x) * YOLO_CHANNELS;
            input_tensor_[base + 0] = r;
            input_tensor_[base + 1] = g;
            input_tensor_[base + 2] = b;
        }
    }
}

// =============================================================================
// [PRIVATE] DecodeAndNms()
// Mục đích  : Giải mã output tensor YOLOv8n và áp dụng NMS.
// Input     : raw_output — output tensor [84 × 8400] (flattened, row-major).
// Output    : Danh sách BBox cuối cùng sau NMS, toạ độ theo ảnh GỐC.
// Cách hoạt :
//   - YOLOv8 output: mỗi cột là 1 anchor, các hàng là [cx,cy,w,h, cls0..cls79]
//   - Tìm class score cao nhất → confidence = max(cls_scores)
//   - Lọc theo CONF_THRESHOLD
//   - Convert cx,cy,w,h → x_min,y_min,x_max,y_max
//   - Scale về ảnh gốc (undo letterbox)
//   - NMS per-class
// Lý do Greedy NMS: O(n log n) đơn giản, đủ nhanh cho n < 8400 anchors.
// =============================================================================
std::vector<BBox> YoloV8nEngine::DecodeAndNms(const std::vector<float>& raw_output) {
    // Danh sách box trước NMS
    std::vector<BBox> candidates;
    candidates.reserve(256);  // Reserve để tránh reallocation

    // Output tensor layout: [84 × 8400], hàng-trước-cột
    // Truy cập: raw_output[feature_idx * YOLO_NUM_ANCHORS + anchor_idx]
    const float* out = raw_output.data();

    for (int a = 0; a < YOLO_NUM_ANCHORS; ++a) {
        // Đọc 4 giá trị bbox (cx,cy,w,h) từ output tensor
        float cx = out[0 * YOLO_NUM_ANCHORS + a];
        float cy = out[1 * YOLO_NUM_ANCHORS + a];
        float bw = out[2 * YOLO_NUM_ANCHORS + a];
        float bh = out[3 * YOLO_NUM_ANCHORS + a];

        // Tìm class score cao nhất trong 80 classes
        float max_score = -1.0f;
        int   best_cls  = -1;
        for (int c = 0; c < YOLO_NUM_CLASSES; ++c) {
            float score = out[(YOLO_BBOX_DIMS + c) * YOLO_NUM_ANCHORS + a];
            if (score > max_score) {
                max_score = score;
                best_cls  = c;
            }
        }

        // Lọc box dưới ngưỡng confidence
        if (max_score < CONF_THRESHOLD) continue;
        if (bw <= 0.0f || bh <= 0.0f)  continue;

        // Chuyển cx,cy,w,h → corners (trong không gian 640×640)
        float x1_640 = cx - bw * 0.5f;
        float y1_640 = cy - bh * 0.5f;
        float x2_640 = cx + bw * 0.5f;
        float y2_640 = cy + bh * 0.5f;

        // Undo letterbox: scale về không gian ảnh gốc
        float x1 = (x1_640 - pad_x_) / scale_;
        float y1 = (y1_640 - pad_y_) / scale_;
        float x2 = (x2_640 - pad_x_) / scale_;
        float y2 = (y2_640 - pad_y_) / scale_;

        // Clamp về [0, img_size]
        x1 = std::max(0.0f, std::min(x1, static_cast<float>(img_w_ - 1)));
        y1 = std::max(0.0f, std::min(y1, static_cast<float>(img_h_ - 1)));
        x2 = std::max(0.0f, std::min(x2, static_cast<float>(img_w_ - 1)));
        y2 = std::max(0.0f, std::min(y2, static_cast<float>(img_h_ - 1)));

        BBox box;
        box.class_id   = best_cls;
        box.confidence = max_score;
        box.x_min      = x1;
        box.y_min      = y1;
        box.x_max      = x2;
        box.y_max      = y2;
        candidates.push_back(box);
    }

    // Nếu không có ứng viên nào, trả về rỗng
    if (candidates.empty()) return {};

    // -------------------------------------------------------------------------
    // Non-Maximum Suppression (Greedy, per-class)
    // Mục đích: Loại bỏ các box trùng lặp, chỉ giữ box confidence cao nhất.
    // Cách hoạt:
    //   1. Sắp xếp theo confidence giảm dần
    //   2. Với mỗi box chưa bị loại, xoá tất cả box cùng class có IoU > threshold
    // -------------------------------------------------------------------------
    std::vector<BBox> results;
    results.reserve(64);

    // Sắp xếp theo confidence giảm dần
    std::sort(candidates.begin(), candidates.end(),
        [](const BBox& a, const BBox& b) { return a.confidence > b.confidence; });

    std::vector<bool> suppressed(candidates.size(), false);

    for (size_t i = 0; i < candidates.size(); ++i) {
        if (suppressed[i]) continue;

        results.push_back(candidates[i]);

        for (size_t j = i + 1; j < candidates.size(); ++j) {
            if (suppressed[j]) continue;
            // Chỉ so sánh box cùng class
            if (candidates[j].class_id != candidates[i].class_id) continue;

            // Tính IoU
            float iou = ComputeIoU(candidates[i], candidates[j]);
            if (iou > NMS_IOU_THRESHOLD) {
                suppressed[j] = true;  // Loại box trùng lặp
            }
        }
    }

    return results;
}

// =============================================================================
// [PRIVATE] ComputeIoU()
// Mục đích  : Tính Intersection-over-Union giữa 2 bounding box.
// Input     : a, b — hai BBox cần so sánh.
// Output    : IoU trong [0, 1].
// Cách hoạt : IoU = diện tích giao / diện tích hợp.
// =============================================================================
float YoloV8nEngine::ComputeIoU(const BBox& a, const BBox& b) {
    // Toạ độ vùng giao nhau
    float inter_x1 = std::max(a.x_min, b.x_min);
    float inter_y1 = std::max(a.y_min, b.y_min);
    float inter_x2 = std::min(a.x_max, b.x_max);
    float inter_y2 = std::min(a.y_max, b.y_max);

    float inter_w = std::max(0.0f, inter_x2 - inter_x1);
    float inter_h = std::max(0.0f, inter_y2 - inter_y1);
    float inter_area = inter_w * inter_h;

    if (inter_area <= 0.0f) return 0.0f;

    // Diện tích từng box
    float area_a = (a.x_max - a.x_min) * (a.y_max - a.y_min);
    float area_b = (b.x_max - b.x_min) * (b.y_max - b.y_min);

    float union_area = area_a + area_b - inter_area;
    if (union_area <= 0.0f) return 0.0f;

    return inter_area / union_area;
}

// =============================================================================
// GetClassName()
// Mục đích: Trả về tên class COCO từ class_id (dùng cho UI / TTS).
// =============================================================================
const char* YoloV8nEngine::GetClassName(int class_id) {
    if (class_id < 0 || class_id >= YOLO_NUM_CLASSES) return "unknown";
    return COCO_CLASSES[class_id];
}

} // namespace vision
} // namespace tmod

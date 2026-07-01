// =============================================================================
// tflite_runner.h
// Mục đích: Interface cho TFLiteRunner — engine TFLite với hỗ trợ NNAPI.
// =============================================================================

#ifndef TMOD_TFLITE_RUNNER_H
#define TMOD_TFLITE_RUNNER_H

#include <string>
#include <vector>
#include <memory>
#include <cstdint>
#include <cstddef>

namespace tmod {
namespace core {

// Forward declaration để tránh circular include
class NnApiDelegate;

// =============================================================================
// TFLiteRunner
// Mục đích: Quản lý toàn bộ vòng đời TFLite model — load, configure, infer.
// Thread safety: KHÔNG thread-safe. Caller phải đảm bảo single-thread access.
// =============================================================================
class TFLiteRunner {
public:
    // Khởi tạo với đường dẫn model và tuỳ chọn NNAPI
    TFLiteRunner(const std::string& model_path, bool use_nnapi);
    ~TFLiteRunner();

    // Cấu hình số CPU thread (gọi trước LoadModel)
    void SetNumThreads(int num_threads);

    // Nạp model từ file .tflite
    bool LoadModel();

    // Giải phóng tài nguyên model
    void UnloadModel();

    // Kiểm tra trạng thái
    bool IsLoaded() const;
    bool IsUsingNnapi() const;

    // Kích thước tensors
    size_t GetInputSize() const;
    size_t GetOutputSize() const;

    // Sao chép dữ liệu vào input tensor
    bool CopyToInputTensor(const float* data, size_t size);

    // Thực thi inference
    bool RunInference(const std::vector<float>& input, std::vector<float>& output);

    // Thời gian inference lần cuối (ms)
    float GetInferenceTimeMs() const;

private:
    // Đọc file model binary vào buffer
    bool ReadModelFile(const std::string& path, std::vector<uint8_t>& buffer);

    std::string             model_path_;
    bool                    use_nnapi_;
    bool                    is_loaded_;

    int                     input_tensor_idx_;
    int                     output_tensor_idx_;
    size_t                  input_size_;
    size_t                  output_size_;
    int                     num_threads_;

    float                   last_inference_ms_ = 0.0f;

    // Buffers tái sử dụng — tránh heap allocation mỗi frame
    std::vector<uint8_t>    model_buffer_;
    std::vector<float>      input_buffer_;
    std::vector<float>      output_buffer_;

    // NNAPI delegate (nullptr nếu dùng CPU)
    std::unique_ptr<NnApiDelegate> nnapi_delegate_;
};

} // namespace core
} // namespace tmod

#endif // TMOD_TFLITE_RUNNER_H

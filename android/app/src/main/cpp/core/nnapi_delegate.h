// =============================================================================
// nnapi_delegate.h
// Mục đích: Interface cho NnApiDelegate quản lý NNAPI hardware acceleration.
// =============================================================================

#ifndef TMOD_NNAPI_DELEGATE_H
#define TMOD_NNAPI_DELEGATE_H

namespace tmod {
namespace core {

// Cấu trúc options NNAPI — ánh xạ với TfLiteNnApiDelegateOptions
struct NnApiOptions {
    // Chế độ thực thi: 0=SUSTAIN, 1=FAST_SINGLE_ANSWER, 2=LOW_POWER
    int execution_preference    = 1;  // FAST_SINGLE_ANSWER mặc định
    bool allow_fp16             = true;
    bool allow_dynamic_dimensions = false;
    int max_number_delegated_partitions = 3;
};

// Hằng số execution preference (khớp với TFLite NNAPI API)
static constexpr int NNAPI_FAST_SINGLE_ANSWER = 1;

// =============================================================================
// NnApiDelegate
// Mục đích: Wrapper quản lý TFLite NNAPI Delegate lifecycle.
//           Hỗ trợ fallback tự động sang CPU nếu NNAPI không khả dụng.
// =============================================================================
class NnApiDelegate {
public:
    // Chế độ acceleration
    enum class AccelerationMode {
        TRY_NNAPI,      // Thử NNAPI, fallback CPU nếu thất bại
        FORCE_NNAPI,    // Bắt buộc NNAPI, trả lỗi nếu không có
        CPU_FALLBACK    // Chỉ dùng CPU
    };

    NnApiDelegate();
    ~NnApiDelegate();

    // Khởi tạo NNAPI delegate với chế độ được chỉ định
    bool Initialize(AccelerationMode mode = AccelerationMode::TRY_NNAPI);

    // Giải phóng tài nguyên delegate
    void Release();

    // Kiểm tra NNAPI có khả dụng không
    bool IsAvailable() const;

    // Lấy raw delegate pointer (ép kiểu sang TfLiteDelegate* bên ngoài)
    void* GetDelegate();

    // Lấy chế độ acceleration hiện tại
    AccelerationMode GetAccelerationMode() const;

    // Chuỗi mô tả trạng thái (dùng cho logging)
    const char* GetStatusString() const;

private:
    void*             delegate_;           // Raw TfLiteDelegate*
    bool              is_available_;       // NNAPI có khả dụng không
    AccelerationMode  acceleration_mode_;  // Chế độ hiện tại
    NnApiOptions      nnapi_options_;      // Cấu hình options
};

} // namespace core
} // namespace tmod

#endif // TMOD_NNAPI_DELEGATE_H

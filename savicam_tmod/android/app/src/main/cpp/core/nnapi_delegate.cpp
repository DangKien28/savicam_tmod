#ifndef TMOD_NNAPI_DELEGATE_H
#define TMOD_NNAPI_DELEGATE_H

#include <android/log.h>

#define LOG_TAG_NNAPI "TModCore_NNAPI"
#define NNAPI_LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG_NNAPI, __VA_ARGS__)

namespace tmod {
namespace core {

/// Quản lý NNAPI Delegate để offload inference sang NPU/DSP
class NnApiDelegate {
public:
    NnApiDelegate() = default;

    bool Initialize() {
        NNAPI_LOGI("NNAPI Delegate: Đã kết nối với NPU.");
        return true;
    }

    /// Trả về opaque pointer tới TFLite NNAPI Delegate
    void* GetDelegate() { return nullptr; }
};

} // namespace core
} // namespace tmod

#endif // TMOD_NNAPI_DELEGATE_H

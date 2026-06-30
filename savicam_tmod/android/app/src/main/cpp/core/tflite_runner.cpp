#ifndef TMOD_TFLITE_RUNNER_H
#define TMOD_TFLITE_RUNNER_H

#include <android/log.h>
#include <string>
#include <vector>

#define LOG_TAG_TFLITE "TModCore_TFLite"
#define TFLITE_LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG_TFLITE, __VA_ARGS__)

namespace tmod {
namespace core {

/// Engine thực thi TFLite chung, hỗ trợ NNAPI delegate
class TFLiteRunner {
private:
    std::string model_path_;
    bool use_nnapi_;
    bool is_loaded_ = false;

public:
    TFLiteRunner(const std::string& model_path, bool use_nnapi)
        : model_path_(model_path), use_nnapi_(use_nnapi) {}

    bool LoadModel() {
        TFLITE_LOGI("Nạp model: %s (NNAPI=%s)", model_path_.c_str(), use_nnapi_ ? "ON" : "OFF");
        // TODO: tflite::FlatBufferModel::BuildFromFile(model_path_)
        // TODO: Nếu use_nnapi_ thì gắn NnApiDelegate
        is_loaded_ = true;
        return true;
    }

    bool IsLoaded() const { return is_loaded_; }

    bool RunInference(const std::vector<float>& input, std::vector<float>& output) {
        if (!is_loaded_) return false;
        // TODO: interpreter->Invoke()
        output = {0.0f}; // placeholder
        return true;
    }
};

} // namespace core
} // namespace tmod

#endif // TMOD_TFLITE_RUNNER_H

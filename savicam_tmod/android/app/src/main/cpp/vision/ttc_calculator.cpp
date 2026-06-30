#include "ttc_calculator.h"

namespace tmod {
namespace vision {

TtcCalculator::TtcCalculator() {}

float TtcCalculator::CalculateTtc(float distance_m, float approach_velocity_mps) {
    if (approach_velocity_mps <= 0.01f) return 999.0f;
    return distance_m / approach_velocity_mps;
}

int32_t TtcCalculator::ClassifyRisk(float ttc, float distance_m) {
    if (ttc < 1.0f  || distance_m < 0.8f) return 4; // SINH TỬ
    if (ttc < 2.0f  || distance_m < 1.5f) return 3; // Nguy hiểm
    if (ttc < 4.0f  || distance_m < 3.0f) return 2; // Cảnh báo
    if (ttc < 7.0f  || distance_m < 5.0f) return 1; // Chú ý
    return 0; // An toàn
}

} // namespace vision
} // namespace tmod

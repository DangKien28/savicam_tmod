#ifndef TMOD_TTC_CALCULATOR_H
#define TMOD_TTC_CALCULATOR_H

#include <cstdint>

namespace tmod {
namespace vision {

class TtcCalculator {
public:
    TtcCalculator();
    float CalculateTtc(float distance_m, float approach_velocity_mps);
    int32_t ClassifyRisk(float ttc, float distance_m);
};

} // namespace vision
} // namespace tmod

#endif // TMOD_TTC_CALCULATOR_H

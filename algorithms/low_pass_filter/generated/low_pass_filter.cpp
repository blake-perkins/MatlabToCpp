#include "low_pass_filter.h"

namespace low_pass_filter {

void low_pass_filter(
    const double input_signal[],
    double alpha,
    int n,
    double output_signal[])
{
    if (n <= 0) return;

    output_signal[0] = input_signal[0];

    for (int k = 1; k < n; k++) {
        output_signal[k] = alpha * input_signal[k] + (1.0 - alpha) * output_signal[k - 1];
    }
}

} // namespace low_pass_filter

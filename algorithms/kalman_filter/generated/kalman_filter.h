#ifndef KALMAN_FILTER_H
#define KALMAN_FILTER_H

// Hand-written C++ equivalent of MATLAB Coder output.
// Matches the interface of kalman_filter.m exactly.
//
// When MATLAB Coder is available, this file will be auto-generated
// and this hand-written version will be replaced.

namespace kalman_filter {

// Kalman filter predict-update step.
//
// Inputs:
//   state[2]            - state vector [position, velocity]
//   measurement         - scalar position observation
//   state_covariance[4] - flattened 2x2 covariance [P11, P12, P21, P22]
//   measurement_noise   - measurement noise variance (R)
//   process_noise       - process noise variance (Q, added to diagonal)
//
// Outputs:
//   updated_state[2]      - updated state vector
//   updated_covariance[4] - flattened 2x2 updated covariance
void kalman_filter(
    const double state[2],
    double measurement,
    const double state_covariance[4],
    double measurement_noise,
    double process_noise,
    double updated_state[2],
    double updated_covariance[4]);

} // namespace kalman_filter

#endif // KALMAN_FILTER_H

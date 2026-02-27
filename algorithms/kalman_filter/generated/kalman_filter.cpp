#include "kalman_filter.h"

namespace kalman_filter {

void kalman_filter(
    const double state[2],
    double measurement,
    const double state_covariance[4],
    double measurement_noise,
    double process_noise,
    double updated_state[2],
    double updated_covariance[4])
{
    // Reshape covariance from flat vector to 2x2
    // P = [P11, P12; P21, P22]
    double P11 = state_covariance[0];
    double P12 = state_covariance[1];
    double P21 = state_covariance[2];
    double P22 = state_covariance[3];

    // State transition matrix (constant velocity model, dt=1)
    // F = [1, 1; 0, 1]

    // --- Predict ---
    // x_pred = F * state
    double x_pred0 = state[0] + state[1];
    double x_pred1 = state[1];

    // P_pred = F * P * F' + Q
    // F * P = [P11+P21, P12+P22; P21, P22]
    // (F * P) * F' = [(P11+P21) + (P12+P22), (P12+P22); P21+P22, P22]
    double Pp11 = (P11 + P21) + (P12 + P22) + process_noise;
    double Pp12 = (P12 + P22);
    double Pp21 = (P21 + P22);
    double Pp22 = P22 + process_noise;

    // --- Update ---
    // H = [1, 0]

    // Innovation: y = measurement - H * x_pred
    double y = measurement - x_pred0;

    // Innovation covariance: S = H * P_pred * H' + R = Pp11 + R
    double S = Pp11 + measurement_noise;

    // Kalman gain: K = P_pred * H' / S = [Pp11; Pp21] / S
    double K0 = Pp11 / S;
    double K1 = Pp21 / S;

    // Updated state: x = x_pred + K * y
    updated_state[0] = x_pred0 + K0 * y;
    updated_state[1] = x_pred1 + K1 * y;

    // Updated covariance (Joseph form): P = (I - K*H) * P_pred * (I - K*H)' + K*R*K'
    // I_KH = [1-K0, 0; -K1, 1]
    double ikh00 = 1.0 - K0;
    double ikh10 = -K1;
    // ikh01 = 0, ikh11 = 1

    // (I_KH) * P_pred
    double A00 = ikh00 * Pp11;               // + 0 * Pp21
    double A01 = ikh00 * Pp12;               // + 0 * Pp22
    double A10 = ikh10 * Pp11 + Pp21;        // ikh11=1
    double A11 = ikh10 * Pp12 + Pp22;        // ikh11=1

    // A * (I_KH)^T where (I_KH)^T = [ikh00, ikh10; 0, 1]
    double P_up11 = A00 * ikh00;
    double P_up12 = A00 * ikh10 + A01;
    double P_up21 = A10 * ikh00;
    double P_up22 = A10 * ikh10 + A11;

    // Add K * R * K'
    P_up11 += K0 * measurement_noise * K0;
    P_up12 += K0 * measurement_noise * K1;
    P_up21 += K1 * measurement_noise * K0;
    P_up22 += K1 * measurement_noise * K1;

    // Flatten back to vector
    updated_covariance[0] = P_up11;
    updated_covariance[1] = P_up12;
    updated_covariance[2] = P_up21;
    updated_covariance[3] = P_up22;
}

} // namespace kalman_filter

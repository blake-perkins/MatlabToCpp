#include "pid_controller.h"

namespace pid_controller {

void pid_controller(
    double error,
    double integral,
    double prev_error,
    double kp,
    double ki,
    double kd,
    double dt,
    double* output,
    double* new_integral,
    double* new_prev_error)
{
    // Update integral
    *new_integral = integral + error * dt;

    // Derivative term
    double derivative = (error - prev_error) / dt;

    // PID output
    *output = kp * error + ki * (*new_integral) + kd * derivative;

    // Store current error for next step
    *new_prev_error = error;
}

} // namespace pid_controller

/**
 * Sensor Processing Pipeline — Example Consumer Application
 *
 * Demonstrates using all three MatlabToCpp algorithms via Conan packages:
 *   1. Generate noisy sensor data (sine wave + noise)
 *   2. low_pass_filter — smooth the raw measurements
 *   3. kalman_filter — estimate state (position + velocity)
 *   4. pid_controller — generate control signal to track reference
 *
 * Build:
 *   conan install . --build=missing --remote=nexus
 *   cmake --preset conan-release
 *   cmake --build --preset conan-release
 */

#include <cmath>
#include <cstdio>
#include <vector>

#include "kalman_filter.h"
#include "low_pass_filter.h"
#include "pid_controller.h"

static constexpr int    NUM_STEPS = 20;
static constexpr double DT        = 0.1;
static constexpr double AMPLITUDE = 5.0;
static constexpr double FREQUENCY = 0.5;  // Hz
static constexpr double NOISE_AMP = 1.5;

// Simple deterministic "noise" for reproducibility (no <random> needed)
static double fake_noise(int step) {
    // Low-discrepancy-ish sequence
    double x = std::sin(step * 12.9898 + 78.233) * 43758.5453;
    return (x - std::floor(x)) * 2.0 - 1.0;  // range [-1, 1]
}

int main() {
    printf("=============================================================\n");
    printf("  Sensor Processing Pipeline — Example Consumer Application\n");
    printf("=============================================================\n\n");

    // Generate raw sensor data: sine wave + noise
    std::vector<double> raw_signal(NUM_STEPS);
    std::vector<double> reference(NUM_STEPS);
    for (int i = 0; i < NUM_STEPS; i++) {
        double t = i * DT;
        reference[i] = AMPLITUDE * std::sin(2.0 * M_PI * FREQUENCY * t);
        raw_signal[i] = reference[i] + NOISE_AMP * fake_noise(i);
    }

    // Step 1: Low-pass filter — smooth the raw signal
    std::vector<double> filtered(NUM_STEPS);
    double alpha = 0.3;
    low_pass_filter::low_pass_filter(raw_signal.data(), alpha, NUM_STEPS, filtered.data());

    // Step 2 & 3: Kalman filter + PID controller at each timestep
    double kf_state[2] = {0.0, 0.0};           // [position, velocity]
    double kf_cov[4]   = {10.0, 0.0, 0.0, 10.0}; // initial uncertainty
    double measurement_noise = 2.0;
    double process_noise     = 0.1;

    double pid_integral   = 0.0;
    double pid_prev_error = 0.0;
    double kp = 1.0, ki = 0.1, kd = 0.05;

    printf("%-5s  %8s  %8s  %8s  %8s  %8s\n",
           "Step", "Raw", "Filtered", "KF Est", "Ref", "Control");
    printf("-----  --------  --------  --------  --------  --------\n");

    for (int i = 0; i < NUM_STEPS; i++) {
        // Kalman filter update
        double updated_state[2];
        double updated_cov[4];
        kalman_filter::kalman_filter(
            kf_state, filtered[i], kf_cov,
            measurement_noise, process_noise,
            updated_state, updated_cov);

        // PID controller: track the reference trajectory
        double error = reference[i] - updated_state[0];
        double control_output;
        double new_integral;
        double new_prev_error;
        pid_controller::pid_controller(
            error, pid_integral, pid_prev_error,
            kp, ki, kd, DT,
            &control_output, &new_integral, &new_prev_error);

        printf("%-5d  %8.3f  %8.3f  %8.3f  %8.3f  %8.3f\n",
               i, raw_signal[i], filtered[i],
               updated_state[0], reference[i], control_output);

        // Carry state forward
        kf_state[0] = updated_state[0];
        kf_state[1] = updated_state[1];
        kf_cov[0] = updated_cov[0];
        kf_cov[1] = updated_cov[1];
        kf_cov[2] = updated_cov[2];
        kf_cov[3] = updated_cov[3];
        pid_integral   = new_integral;
        pid_prev_error = new_prev_error;
    }

    printf("\n-------------------------------------------------------------\n");
    printf("Pipeline complete. All three algorithms consumed via Conan.\n");

    return 0;
}

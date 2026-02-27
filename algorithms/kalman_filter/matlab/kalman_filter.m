function [updated_state, updated_covariance] = kalman_filter(state, measurement, state_covariance, measurement_noise, process_noise)
%KALMAN_FILTER 1D Kalman filter predict-update step.
%
%   [updated_state, updated_covariance] = kalman_filter(state, measurement, ...
%       state_covariance, measurement_noise, process_noise)
%
%   Inputs:
%       state              - 2x1 state vector [position; velocity]
%       measurement        - scalar measurement (position observation)
%       state_covariance   - 4x1 flattened 2x2 covariance [P11, P12, P21, P22]
%       measurement_noise  - scalar measurement noise variance (R)
%       process_noise      - scalar process noise variance (Q, added to diagonal)
%
%   Outputs:
%       updated_state      - 2x1 updated state vector
%       updated_covariance - 4x1 flattened 2x2 updated covariance
%
%   This function is compatible with MATLAB Coder for C++ generation.

%#codegen

    % Reshape covariance from flat vector to 2x2 matrix
    P = [state_covariance(1), state_covariance(2); ...
         state_covariance(3), state_covariance(4)];

    % State transition matrix (constant velocity model, dt=1)
    F = [1, 1; 0, 1];

    % Measurement matrix (observe position only)
    H = [1, 0];

    % Process noise matrix
    Q = [process_noise, 0; 0, process_noise];

    % --- Predict ---
    x_pred = F * state(:);
    P_pred = F * P * F' + Q;

    % --- Update ---
    % Innovation
    y = measurement - H * x_pred;

    % Innovation covariance
    S = H * P_pred * H' + measurement_noise;

    % Kalman gain
    K = P_pred * H' / S;

    % Updated state estimate
    updated_state = x_pred + K * y;

    % Updated covariance (Joseph form for numerical stability)
    I_KH = eye(2) - K * H;
    P_updated = I_KH * P_pred * I_KH' + K * measurement_noise * K';

    % Flatten covariance back to 4x1 vector
    updated_covariance = [P_updated(1,1); P_updated(1,2); P_updated(2,1); P_updated(2,2)];
end

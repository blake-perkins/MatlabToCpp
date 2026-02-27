function [output, new_integral, new_prev_error] = pid_controller(error, integral, prev_error, kp, ki, kd, dt)
%PID_CONTROLLER Discrete PID controller step.
%
%   [output, new_integral, new_prev_error] = pid_controller(error, integral, prev_error, kp, ki, kd, dt)
%
%   Inputs:
%       error       - current error (setpoint - measurement)
%       integral    - accumulated integral term from previous step
%       prev_error  - error from previous step
%       kp          - proportional gain
%       ki          - integral gain
%       kd          - derivative gain
%       dt          - timestep
%
%   Outputs:
%       output          - control signal: u = kp*e + ki*integral + kd*de/dt
%       new_integral    - updated integral (integral + error * dt)
%       new_prev_error  - current error (for next step's derivative)
%
%   This function is compatible with MATLAB Coder for C++ generation.

%#codegen

    % Update integral
    new_integral = integral + error * dt;

    % Derivative term
    derivative = (error - prev_error) / dt;

    % PID output
    output = kp * error + ki * new_integral + kd * derivative;

    % Store current error for next derivative calculation
    new_prev_error = error;
end

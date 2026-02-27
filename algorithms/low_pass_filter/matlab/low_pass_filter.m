function output_signal = low_pass_filter(input_signal, alpha, n)
%LOW_PASS_FILTER First-order IIR low-pass filter.
%
%   output_signal = low_pass_filter(input_signal, alpha, n)
%
%   Inputs:
%       input_signal  - Nx1 array of raw signal samples
%       alpha         - smoothing factor (0 < alpha <= 1, higher = less smoothing)
%       n             - number of samples to process
%
%   Outputs:
%       output_signal - Nx1 array of filtered signal samples
%
%   Formula: y[0] = x[0]; y[k] = alpha * x[k] + (1 - alpha) * y[k-1]
%
%   This function is compatible with MATLAB Coder for C++ generation.

%#codegen

    output_signal = zeros(n, 1);
    output_signal(1) = input_signal(1);

    for k = 2:n
        output_signal(k) = alpha * input_signal(k) + (1 - alpha) * output_signal(k - 1);
    end
end

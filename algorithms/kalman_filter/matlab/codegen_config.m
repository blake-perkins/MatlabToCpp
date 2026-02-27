function codegen_config(output_dir)
%CODEGEN_CONFIG Configure and run MATLAB Coder for kalman_filter.
%
%   codegen_config(output_dir) generates C++ static library source
%   into the specified output directory.
%
%   This function is called by the CI pipeline:
%       matlab -batch "codegen_config('/path/to/generated')"

    % Code generation configuration
    cfg = coder.config('lib');
    cfg.TargetLang = 'C++';
    cfg.GenerateReport = true;
    cfg.ReportPotentialDifferences = true;
    cfg.CppNamespace = 'kalman_filter';
    cfg.SaturateOnIntegerOverflow = true;
    cfg.EnableAutoParallelization = false;

    % Define input types matching the function signature:
    %   kalman_filter(state, measurement, state_covariance, measurement_noise, process_noise)
    state_type      = coder.typeof(double(0), [2, 1], [false, false]);   % 2x1 fixed
    meas_type       = coder.typeof(double(0));                           % scalar
    cov_type        = coder.typeof(double(0), [4, 1], [false, false]);   % 4x1 fixed (flattened 2x2)
    meas_noise_type = coder.typeof(double(0));                           % scalar
    proc_noise_type = coder.typeof(double(0));                           % scalar

    % Run code generation
    codegen kalman_filter ...
        -config cfg ...
        -args {state_type, meas_type, cov_type, meas_noise_type, proc_noise_type} ...
        -d output_dir ...
        -lang:c++

    fprintf('Code generation complete. Output: %s\n', output_dir);
end

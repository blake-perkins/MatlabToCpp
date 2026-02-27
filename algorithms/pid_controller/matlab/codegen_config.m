function codegen_config(output_dir)
%CODEGEN_CONFIG Configure and run MATLAB Coder for pid_controller.
%
%   codegen_config(output_dir) generates C++ static library source
%   into the specified output directory.

    cfg = coder.config('lib');
    cfg.TargetLang = 'C++';
    cfg.GenerateReport = true;
    cfg.ReportPotentialDifferences = true;
    cfg.CppNamespace = 'pid_controller';
    cfg.SaturateOnIntegerOverflow = true;
    cfg.EnableAutoParallelization = false;

    % Define input types — all scalars:
    %   pid_controller(error, integral, prev_error, kp, ki, kd, dt)
    error_type      = coder.typeof(double(0));
    integral_type   = coder.typeof(double(0));
    prev_error_type = coder.typeof(double(0));
    kp_type         = coder.typeof(double(0));
    ki_type         = coder.typeof(double(0));
    kd_type         = coder.typeof(double(0));
    dt_type         = coder.typeof(double(0));

    codegen pid_controller ...
        -config cfg ...
        -args {error_type, integral_type, prev_error_type, kp_type, ki_type, kd_type, dt_type} ...
        -d output_dir ...
        -lang:c++

    fprintf('Code generation complete. Output: %s\n', output_dir);
end

function codegen_config(output_dir)
%CODEGEN_CONFIG Configure and run MATLAB Coder for low_pass_filter.
%
%   codegen_config(output_dir) generates C++ static library source
%   into the specified output directory.

    cfg = coder.config('lib');
    cfg.TargetLang = 'C++';
    cfg.GenerateReport = true;
    cfg.ReportPotentialDifferences = true;
    cfg.CppNamespace = 'low_pass_filter';
    cfg.SaturateOnIntegerOverflow = true;
    cfg.EnableAutoParallelization = false;

    % Define input types:
    %   low_pass_filter(input_signal, alpha, n)
    input_type = coder.typeof(double(0), [1024, 1], [true, false]);  % variable-length up to 1024
    alpha_type = coder.typeof(double(0));                             % scalar
    n_type     = coder.typeof(int32(0));                              % scalar integer

    codegen low_pass_filter ...
        -config cfg ...
        -args {input_type, alpha_type, n_type} ...
        -d output_dir ...
        -lang:c++

    fprintf('Code generation complete. Output: %s\n', output_dir);
end

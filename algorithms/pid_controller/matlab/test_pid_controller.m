function results = test_pid_controller(vectors_dir, output_dir)
%TEST_PID_CONTROLLER Validate pid_controller against JSON test vectors.
%
%   results = test_pid_controller(vectors_dir, output_dir)

    results.Passed = 0;
    results.Failed = 0;
    results.Total = 0;
    results.Details = {};

    vector_files = dir(fullfile(vectors_dir, '*.json'));

    for i = 1:length(vector_files)
        if contains(vector_files(i).name, 'schema')
            continue;
        end

        filepath = fullfile(vectors_dir, vector_files(i).name);
        fid = fopen(filepath, 'r');
        raw = fread(fid, inf, 'char');
        fclose(fid);
        test_data = jsondecode(char(raw'));

        global_abs_tol = 1e-10;
        if isfield(test_data, 'global_tolerance')
            if isfield(test_data.global_tolerance, 'absolute')
                global_abs_tol = test_data.global_tolerance.absolute;
            end
        end

        for t = 1:length(test_data.test_cases)
            tc = test_data.test_cases(t);
            results.Total = results.Total + 1;

            err = tc.inputs.error;
            integral = tc.inputs.integral;
            prev_error = tc.inputs.prev_error;
            kp = tc.inputs.kp;
            ki = tc.inputs.ki;
            kd = tc.inputs.kd;
            dt = tc.inputs.dt;

            [actual_output, actual_new_integral, actual_new_prev_error] = ...
                pid_controller(err, integral, prev_error, kp, ki, kd, dt);

            expected_output = tc.expected_output.output;
            expected_new_integral = tc.expected_output.new_integral;
            expected_new_prev_error = tc.expected_output.new_prev_error;

            if isfield(tc, 'tolerance') && isfield(tc.tolerance, 'absolute')
                abs_tol = tc.tolerance.absolute;
            else
                abs_tol = global_abs_tol;
            end

            ok = abs(actual_output - expected_output) <= abs_tol && ...
                 abs(actual_new_integral - expected_new_integral) <= abs_tol && ...
                 abs(actual_new_prev_error - expected_new_prev_error) <= abs_tol;

            if ok
                results.Passed = results.Passed + 1;
                fprintf('  PASS: %s\n', tc.name);
            else
                results.Failed = results.Failed + 1;
                fprintf('  FAIL: %s\n', tc.name);
            end

            detail.test_name = tc.name;
            detail.actual_output = actual_output;
            detail.actual_new_integral = actual_new_integral;
            detail.actual_new_prev_error = actual_new_prev_error;
            detail.tolerance = abs_tol;
            detail.passed = ok;
            results.Details{end+1} = detail;
        end
    end

    fprintf('\nResults: %d passed, %d failed, %d total\n', ...
        results.Passed, results.Failed, results.Total);

    if nargin >= 2 && ~isempty(output_dir)
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        output_path = fullfile(output_dir, 'matlab_outputs.json');
        fid = fopen(output_path, 'w');
        fprintf(fid, '%s', jsonencode(results.Details));
        fclose(fid);
        fprintf('MATLAB outputs written to: %s\n', output_path);
    end
end

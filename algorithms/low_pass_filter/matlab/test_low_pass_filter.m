function results = test_low_pass_filter(vectors_dir, output_dir)
%TEST_LOW_PASS_FILTER Validate low_pass_filter against JSON test vectors.
%
%   results = test_low_pass_filter(vectors_dir, output_dir)
%
%   Reads all .json files in vectors_dir, runs low_pass_filter on each
%   test case's inputs, and compares outputs against expected values
%   within specified tolerances.
%
%   Writes actual outputs to output_dir/matlab_outputs.json for
%   equivalence comparison with C++ results.

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

            input_signal = tc.inputs.input_signal(:);
            alpha = tc.inputs.alpha;
            n = length(input_signal);

            actual_output = low_pass_filter(input_signal, alpha, n);
            actual_output = actual_output(:)';

            expected_output = tc.expected_output.output_signal(:)';

            if isfield(tc, 'tolerance') && isfield(tc.tolerance, 'absolute')
                abs_tol = tc.tolerance.absolute;
            else
                abs_tol = global_abs_tol;
            end

            ok = all(abs(actual_output - expected_output) <= abs_tol);

            if ok
                results.Passed = results.Passed + 1;
                fprintf('  PASS: %s\n', tc.name);
            else
                results.Failed = results.Failed + 1;
                fprintf('  FAIL: %s\n', tc.name);
                fprintf('    Expected: %s\n', mat2str(expected_output, 15));
                fprintf('    Actual:   %s\n', mat2str(actual_output, 15));
            end

            detail.test_name = tc.name;
            detail.actual_output_signal = actual_output;
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

function results = test_kalman_filter(vectors_dir, output_dir)
%TEST_KALMAN_FILTER Validate kalman_filter against JSON test vectors.
%
%   results = test_kalman_filter(vectors_dir, output_dir)
%
%   Reads all .json files in vectors_dir, runs kalman_filter on each
%   test case's inputs, and compares outputs against expected values
%   within specified tolerances.
%
%   Writes actual outputs to output_dir/matlab_outputs.json for
%   equivalence comparison with C++ results.
%
%   Returns a struct with fields: Passed, Failed, Total, Details

    results.Passed = 0;
    results.Failed = 0;
    results.Total = 0;
    results.Details = {};

    % Find all JSON test vector files
    vector_files = dir(fullfile(vectors_dir, '*.json'));

    for i = 1:length(vector_files)
        % Skip schema file
        if contains(vector_files(i).name, 'schema')
            continue;
        end

        % Load test vector file
        filepath = fullfile(vectors_dir, vector_files(i).name);
        fid = fopen(filepath, 'r');
        raw = fread(fid, inf, 'char');
        fclose(fid);
        test_data = jsondecode(char(raw'));

        % Get global tolerance defaults
        global_abs_tol = 1e-10;
        global_rel_tol = 1e-8;
        if isfield(test_data, 'global_tolerance')
            if isfield(test_data.global_tolerance, 'absolute')
                global_abs_tol = test_data.global_tolerance.absolute;
            end
            if isfield(test_data.global_tolerance, 'relative')
                global_rel_tol = test_data.global_tolerance.relative;
            end
        end

        % Run each test case
        for t = 1:length(test_data.test_cases)
            tc = test_data.test_cases(t);
            results.Total = results.Total + 1;

            % Extract inputs
            state = tc.inputs.state(:);
            measurement = tc.inputs.measurement;
            state_covariance = tc.inputs.state_covariance(:);
            measurement_noise = tc.inputs.measurement_noise;
            process_noise = tc.inputs.process_noise;

            % Run algorithm
            [updated_state, updated_covariance] = kalman_filter( ...
                state, measurement, state_covariance, ...
                measurement_noise, process_noise);

            % Flatten actual outputs for comparison
            actual_updated_state = updated_state(:)';
            actual_updated_cov = updated_covariance(:)';

            % Get expected outputs
            expected_state = tc.expected_output.updated_state(:)';
            expected_cov = tc.expected_output.updated_covariance(:)';

            % Get tolerance for this test case
            if isfield(tc, 'tolerance') && isfield(tc.tolerance, 'absolute')
                abs_tol = tc.tolerance.absolute;
            else
                abs_tol = global_abs_tol;
            end

            % Compare
            state_ok = all(abs(actual_updated_state - expected_state) <= abs_tol);
            cov_ok = all(abs(actual_updated_cov - expected_cov) <= abs_tol);

            if state_ok && cov_ok
                results.Passed = results.Passed + 1;
                fprintf('  PASS: %s\n', tc.name);
            else
                results.Failed = results.Failed + 1;
                fprintf('  FAIL: %s\n', tc.name);
                if ~state_ok
                    fprintf('    State mismatch: expected %s, got %s\n', ...
                        mat2str(expected_state, 15), mat2str(actual_updated_state, 15));
                end
                if ~cov_ok
                    fprintf('    Covariance mismatch: expected %s, got %s\n', ...
                        mat2str(expected_cov, 15), mat2str(actual_updated_cov, 15));
                end
            end

            % Record actual outputs for equivalence check
            detail.test_name = tc.name;
            detail.actual_state = actual_updated_state;
            detail.actual_covariance = actual_updated_cov;
            detail.expected_state = expected_state;
            detail.expected_covariance = expected_cov;
            detail.tolerance = abs_tol;
            detail.passed = state_ok && cov_ok;
            results.Details{end+1} = detail;
        end
    end

    fprintf('\nResults: %d passed, %d failed, %d total\n', ...
        results.Passed, results.Failed, results.Total);

    % Write actual outputs for equivalence comparison with C++
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

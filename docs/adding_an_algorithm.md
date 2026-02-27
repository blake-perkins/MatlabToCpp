# Adding a New Algorithm

This guide walks you through adding a new MATLAB algorithm to the pipeline. Once set up, the Jenkins pipeline will automatically test your MATLAB code, generate C++, verify equivalence, and publish a Conan package.

## Prerequisites

- Your algorithm works in MATLAB
- You know the function signature (input types, sizes, output types)
- You have test cases with known inputs and expected outputs

**Additional examples:** Besides `kalman_filter` (fixed-size array inputs), you can reference `low_pass_filter` (variable-length array input) and `pid_controller` (all-scalar inputs with multiple pointer outputs) for different patterns.

## Step-by-Step

### 1. Create the algorithm directory

Copy the example algorithm as a starting point:

```bash
cp -r algorithms/kalman_filter algorithms/my_algorithm
```

### 2. Update `algorithm.yaml`

Edit `algorithms/my_algorithm/algorithm.yaml`:

```yaml
name: my_algorithm
display_name: "My Algorithm"
description: "Brief description of what it does"
matlab_entry_point: my_algorithm

owner: your.email@example.com
team: your-team-name

consumers:
  - cpp-team@example.com

dependencies: []
```

- **name**: Must match the directory name (lowercase, underscores)
- **owner**: Email notified on pipeline failures
- **consumers**: Emails notified when a new version is published
- **matlab_entry_point**: The main MATLAB function name

### 3. Set the initial version

Edit `algorithms/my_algorithm/VERSION`:

```
0.1.0
```

### 4. Add your MATLAB algorithm

Replace the contents of `algorithms/my_algorithm/matlab/my_algorithm.m` with your function.

Requirements:
- The function must be MATLAB Coder compatible (add `%#codegen` directive)
- All input/output sizes must be deterministic (or use `coder.typeof` for variable sizes)
- No unsupported MATLAB functions (check [MATLAB Coder support](https://www.mathworks.com/help/coder/ug/functions-and-objects-supported-for-cc-code-generation.html))

Example:

```matlab
function output = my_algorithm(input_a, input_b)
%MY_ALGORITHM Brief description.
%#codegen
    output = input_a + input_b;  % Your actual algorithm here
end
```

### 5. Configure code generation

Edit `algorithms/my_algorithm/matlab/codegen_config.m`:

```matlab
function codegen_config(output_dir)
    cfg = coder.config('lib');
    cfg.TargetLang = 'C++';
    cfg.GenerateReport = true;
    cfg.CppNamespace = 'my_algorithm';

    % Define your input types
    input_a_type = coder.typeof(double(0), [3, 1], [false, false]);  % 3x1 double
    input_b_type = coder.typeof(double(0));                          % scalar double

    codegen my_algorithm ...
        -config cfg ...
        -args {input_a_type, input_b_type} ...
        -d output_dir ...
        -lang:c++
end
```

### 6. Define test vectors

Edit `algorithms/my_algorithm/test_vectors/nominal.json`:

```json
{
  "algorithm": "my_algorithm",
  "version": "1.0",
  "description": "Standard test cases",
  "global_tolerance": {
    "absolute": 1e-10,
    "relative": 1e-8
  },
  "test_cases": [
    {
      "name": "basic_case",
      "description": "Simple addition",
      "inputs": {
        "input_a": [1.0, 2.0, 3.0],
        "input_b": 10.0
      },
      "expected_output": [11.0, 12.0, 13.0],
      "tolerance": { "absolute": 1e-10 }
    },
    {
      "name": "zero_input",
      "description": "Zero inputs should produce zero output",
      "inputs": {
        "input_a": [0.0, 0.0, 0.0],
        "input_b": 0.0
      },
      "expected_output": [0.0, 0.0, 0.0]
    }
  ]
}
```

See [test_vector_format.md](test_vector_format.md) for the full specification.

### 7. Write the MATLAB test harness

Edit `algorithms/my_algorithm/matlab/test_my_algorithm.m`:

```matlab
function results = test_my_algorithm(vectors_dir, output_dir)
    results.Passed = 0;
    results.Failed = 0;
    results.Total = 0;
    results.Details = {};

    vector_files = dir(fullfile(vectors_dir, '*.json'));

    for i = 1:length(vector_files)
        if contains(vector_files(i).name, 'schema'), continue; end

        fid = fopen(fullfile(vectors_dir, vector_files(i).name), 'r');
        raw = fread(fid, inf, 'char');
        fclose(fid);
        test_data = jsondecode(char(raw'));

        global_tol = 1e-10;
        if isfield(test_data, 'global_tolerance')
            global_tol = test_data.global_tolerance.absolute;
        end

        for t = 1:length(test_data.test_cases)
            tc = test_data.test_cases(t);
            results.Total = results.Total + 1;

            % === CUSTOMIZE THIS: extract inputs and call your function ===
            actual = my_algorithm(tc.inputs.input_a(:), tc.inputs.input_b);

            % Get tolerance
            if isfield(tc, 'tolerance') && isfield(tc.tolerance, 'absolute')
                tol = tc.tolerance.absolute;
            else
                tol = global_tol;
            end

            % Compare
            if all(abs(actual(:)' - tc.expected_output(:)') <= tol)
                results.Passed = results.Passed + 1;
                fprintf('  PASS: %s\n', tc.name);
            else
                results.Failed = results.Failed + 1;
                fprintf('  FAIL: %s\n', tc.name);
            end

            % Record for equivalence check
            detail.test_name = tc.name;
            detail.actual_output = actual(:)';
            detail.expected_output = tc.expected_output(:)';
            detail.tolerance = tol;
            results.Details{end+1} = detail;
        end
    end

    fprintf('\nResults: %d passed, %d failed, %d total\n', ...
        results.Passed, results.Failed, results.Total);

    if nargin >= 2 && ~isempty(output_dir)
        if ~exist(output_dir, 'dir'), mkdir(output_dir); end
        fid = fopen(fullfile(output_dir, 'matlab_outputs.json'), 'w');
        fprintf(fid, '%s', jsonencode(results.Details));
        fclose(fid);
    end
end
```

### 8. Update the C++ test harness

Edit `algorithms/my_algorithm/cpp/test_my_algorithm.cpp` to match your function's inputs and outputs. The key section to customize is the function call:

```cpp
// Call your generated C++ function
my_algorithm(input_a_data, input_b, output_data);
```

### 9. Update the Conan recipe

Edit `algorithms/my_algorithm/cpp/conanfile.py`:
- Change the `name` field to your algorithm name
- Update the `description`

### 10. Update CMakeLists.txt

Edit `algorithms/my_algorithm/cpp/CMakeLists.txt`:
- Change `ALGO_NAME` to your algorithm name
- Update target names to match

### 11. Test locally (optional)

If you have MATLAB available:

```bash
# Run MATLAB tests
bash scripts/run_matlab_tests.sh my_algorithm

# Run codegen (if MATLAB Coder available)
bash scripts/run_codegen.sh my_algorithm
```

### 12. Commit and push

Use conventional commit messages:

```bash
git add algorithms/my_algorithm/
git commit -m "feat(my_algorithm): add initial implementation"
git push
```

The pipeline will automatically detect the new algorithm and run the full pipeline.

## Commit Message Conventions

Version bumps are determined from your commit messages:

| Prefix | Example | Version Bump |
|--------|---------|-------------|
| `fix(algo):` | `fix(my_algorithm): correct edge case` | PATCH (0.1.0 → 0.1.1) |
| `feat(algo):` | `feat(my_algorithm): add batch mode` | MINOR (0.1.0 → 0.2.0) |
| `feat(algo)!:` | `feat(my_algorithm)!: change signature` | MAJOR (0.1.0 → 1.0.0) |
| `refactor(algo):` | `refactor(my_algorithm): simplify` | PATCH |
| `perf(algo):` | `perf(my_algorithm): optimize loop` | PATCH |

## Troubleshooting

### Pipeline fails at "MATLAB Tests"
- Check that your test vector JSON is valid (use a JSON validator)
- Verify input field names match what your test harness expects
- Run `test_my_algorithm` locally in MATLAB to reproduce

### Pipeline fails at "Code Generation"
- Ensure `%#codegen` directive is in your function
- Check `codegen_config.m` input types match your function signature
- Run `codegen_config('/tmp/test')` locally to see detailed errors

### Pipeline fails at "Equivalence Check"
- MATLAB and C++ are producing different outputs for the same inputs
- Check for numerical precision issues (tighten or loosen tolerances)
- Look at the equivalence report for which test cases fail

## Generating Test Vectors from Real MATLAB

Instead of hand-computing expected outputs, run your algorithm in MATLAB and capture the results:

```matlab
function generate_vectors(output_file)
%GENERATE_VECTORS Create JSON test vectors from MATLAB outputs.

    test_cases = {};

    % --- Test case 1 ---
    inputs1.param_a = [1.0, 2.0, 3.0];
    inputs1.param_b = 0.5;
    [out1] = my_algorithm(inputs1.param_a, inputs1.param_b);

    tc1.name = 'nominal_case';
    tc1.description = 'Standard operating conditions';
    tc1.inputs = inputs1;
    tc1.expected_output.result = out1(:)';
    tc1.tolerance.absolute = 1e-10;
    test_cases{end+1} = tc1;

    % --- Add more test cases ---

    data.algorithm = 'my_algorithm';
    data.version = '1.0';
    data.global_tolerance.absolute = 1e-10;
    data.test_cases = test_cases;

    fid = fopen(output_file, 'w');
    fprintf(fid, '%s', jsonencode(data));
    fclose(fid);
end
```

Run: `generate_vectors('test_vectors/nominal.json')` in MATLAB.

## MATLAB Coder Compatibility Checklist

Before pushing, verify your code works with MATLAB Coder:

- [ ] `%#codegen` directive in every function
- [ ] No unsupported functions ([MathWorks list](https://www.mathworks.com/help/coder/ug/functions-and-objects-supported-for-cc-code-generation.html))
- [ ] All input sizes deterministic (or use `coder.typeof` for variable-size)
- [ ] No function handles passed as arguments
- [ ] No cell arrays in generated code paths
- [ ] No `try/catch` blocks in generated code paths
- [ ] No string objects (use char arrays)
- [ ] No global variables
- [ ] Local test: `codegen_config('/tmp/test_output')` succeeds

## Next Steps

- For transitioning to real MATLAB and production infrastructure, see [going_to_production.md](going_to_production.md)
- For how C++ developers consume your published packages, see [consuming_packages.md](consuming_packages.md)

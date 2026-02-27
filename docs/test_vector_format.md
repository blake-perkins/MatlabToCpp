# Test Vector Format Specification

Test vectors are JSON files that define input/output pairs for algorithm testing. The same test vectors are used by both MATLAB and C++ test harnesses, ensuring consistency.

## File Location

Test vectors live in each algorithm's `test_vectors/` directory:

```
algorithms/my_algorithm/test_vectors/
├── schema.json       # JSON Schema (validates all vector files)
├── nominal.json      # Standard operating conditions
├── edge_cases.json   # Boundary conditions, special values
└── regression_001.json  # Regression tests from bug fixes
```

You can create as many `.json` files as you want. The test harnesses load all `*.json` files in the directory (except `schema.json`).

## Structure

```json
{
  "algorithm": "my_algorithm",
  "version": "1.0",
  "description": "Human-readable description of this test set",
  "global_tolerance": {
    "absolute": 1e-10,
    "relative": 1e-8
  },
  "test_cases": [
    {
      "name": "test_case_name",
      "description": "What this test case verifies",
      "tags": ["nominal", "regression"],
      "inputs": {
        "param_a": [1.0, 2.0, 3.0],
        "param_b": 42.0
      },
      "expected_output": [4.0, 5.0, 6.0],
      "tolerance": {
        "absolute": 1e-6
      },
      "metadata": {
        "source": "analytical",
        "author": "jane.doe",
        "created": "2026-01-15"
      }
    }
  ]
}
```

## Field Reference

### Top-level fields

| Field | Required | Description |
|-------|----------|-------------|
| `algorithm` | Yes | Algorithm name (must match directory name) |
| `version` | Yes | Test vector format version (currently "1.0") |
| `description` | No | Human-readable description of this test set |
| `global_tolerance` | No | Default tolerances applied when test cases don't specify their own |
| `test_cases` | Yes | Array of test case objects (minimum 1) |

### Test case fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier for this test case. Must be a valid C++ and MATLAB identifier: `[a-zA-Z_][a-zA-Z0-9_]*` |
| `description` | No | Human-readable description |
| `tags` | No | Array of string tags for filtering/categorization |
| `inputs` | Yes | Object with named inputs matching the algorithm's function signature |
| `expected_output` | Yes | Expected output — can be a scalar, array, nested array, or object |
| `tolerance` | No | Per-test-case tolerance (overrides `global_tolerance`) |
| `metadata` | No | Optional metadata (author, date, source) |

### Tolerance fields

| Field | Description |
|-------|-------------|
| `absolute` | Maximum absolute difference: `|actual - expected| <= abs_tol` |
| `relative` | Maximum relative difference: `|actual - expected| / |expected| <= rel_tol` |

If neither is specified, the `global_tolerance` is used. If `global_tolerance` is also absent, the default is `absolute: 1e-10`.

## Data Types

### Scalars
```json
"inputs": { "x": 3.14 }
```

### 1D Arrays (Vectors)
```json
"inputs": { "state": [1.0, 2.0, 3.0] }
```

### 2D Arrays (Matrices)
Stored as flattened 1D arrays with dimensions documented:
```json
"inputs": {
  "covariance": [1.0, 0.0, 0.0, 1.0],
  "_covariance_shape": [2, 2]
}
```

Or as arrays of arrays:
```json
"inputs": {
  "matrix": [[1.0, 0.0], [0.0, 1.0]]
}
```

### Structured Outputs
When the algorithm returns multiple outputs, use an object:
```json
"expected_output": {
  "updated_state": [1.025, 0.49],
  "updated_covariance": [0.09, 0.0, 0.0, 1.01]
}
```

## Examples

### Simple scalar function
```json
{
  "algorithm": "square_root",
  "version": "1.0",
  "global_tolerance": { "absolute": 1e-15 },
  "test_cases": [
    {
      "name": "positive_integer",
      "inputs": { "x": 4.0 },
      "expected_output": 2.0
    },
    {
      "name": "large_number",
      "inputs": { "x": 1e20 },
      "expected_output": 1e10,
      "tolerance": { "relative": 1e-14 }
    }
  ]
}
```

### Multi-output function
```json
{
  "algorithm": "kalman_filter",
  "version": "1.0",
  "global_tolerance": { "absolute": 1e-10 },
  "test_cases": [
    {
      "name": "steady_state",
      "inputs": {
        "state": [1.0, 0.0],
        "measurement": 1.05,
        "state_covariance": [1.0, 0.0, 0.0, 1.0],
        "measurement_noise": 0.1,
        "process_noise": 0.01
      },
      "expected_output": {
        "updated_state": [1.045, 0.0],
        "updated_covariance": [0.091, 0.0, 0.0, 1.01]
      }
    }
  ]
}
```

### Edge case testing
```json
{
  "algorithm": "my_algorithm",
  "version": "1.0",
  "test_cases": [
    {
      "name": "zero_input",
      "description": "All-zero input should produce all-zero output",
      "tags": ["edge-case", "zero"],
      "inputs": { "x": [0.0, 0.0, 0.0] },
      "expected_output": [0.0, 0.0, 0.0],
      "tolerance": { "absolute": 0.0 }
    },
    {
      "name": "very_large_values",
      "description": "Near overflow — use relative tolerance",
      "tags": ["edge-case", "overflow"],
      "inputs": { "x": [1e300, 1e300, 1e300] },
      "expected_output": [1e300, 1e300, 1e300],
      "tolerance": { "relative": 1e-10 }
    }
  ]
}
```

## Best Practices

1. **Name test cases clearly.** Use descriptive names like `steady_state_tracking` instead of `test_1`. Names must be valid identifiers (letters, numbers, underscores).

2. **Start with analytical cases.** Test cases where you can compute the expected output by hand are the most trustworthy.

3. **Include edge cases.** Zero inputs, very large values, very small values, negative values, identity matrices.

4. **Set appropriate tolerances.** Floating-point arithmetic introduces small differences between MATLAB and C++. Use tolerances of `1e-10` to `1e-6` depending on your algorithm's numerical sensitivity.

5. **Use tags for organization.** Tags like `nominal`, `edge-case`, `regression`, `performance` help categorize test cases.

6. **Add regression tests.** When you fix a bug, add a test case that reproduces it. Name it `regression_NNN` with a description of what it catches.

7. **Document your inputs.** Input field names should match the MATLAB function's parameter names exactly.

8. **Keep files focused.** Group related test cases into files (e.g., `nominal.json`, `edge_cases.json`, `regression_001.json`) rather than putting everything in one file.

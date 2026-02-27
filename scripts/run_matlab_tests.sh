#!/bin/bash
# run_matlab_tests.sh — Run MATLAB unit tests for a single algorithm.
#
# Usage: bash scripts/run_matlab_tests.sh <algorithm_name>
#
# Validates test vector JSON schema, then runs the MATLAB test harness
# which reads test vectors, executes the algorithm, and compares results.
# Writes matlab_outputs.json for later equivalence comparison.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: run_matlab_tests.sh <algorithm_name>}"
ALGO_DIR="${REPO_ROOT}/algorithms/${ALGO}"
VECTORS_DIR="${ALGO_DIR}/test_vectors"
RESULTS_DIR=$(ensure_results_dir "$ALGO" "matlab")

validate_algorithm "$ALGO"

log_info "Running MATLAB tests for: $ALGO"

# Step 1: Validate test vectors against JSON schema (if python3 + jsonschema available)
if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys, os, glob

schema_file = os.path.join('${VECTORS_DIR}', 'schema.json')
if not os.path.exists(schema_file):
    print('No schema.json found, skipping validation')
    sys.exit(0)

try:
    import jsonschema
except ImportError:
    print('jsonschema not installed, skipping validation')
    sys.exit(0)

with open(schema_file) as f:
    schema = json.load(f)

errors = 0
for vector_file in glob.glob(os.path.join('${VECTORS_DIR}', '*.json')):
    if 'schema' in os.path.basename(vector_file):
        continue
    with open(vector_file) as f:
        data = json.load(f)
    try:
        jsonschema.validate(data, schema)
        print(f'  Schema OK: {os.path.basename(vector_file)}')
    except jsonschema.ValidationError as e:
        print(f'  Schema FAIL: {os.path.basename(vector_file)}: {e.message}', file=sys.stderr)
        errors += 1

if errors > 0:
    print(f'{errors} test vector file(s) failed schema validation', file=sys.stderr)
    sys.exit(1)

print('All test vectors passed schema validation')
" || { log_error "Test vector schema validation failed"; exit 1; }
else
    log_warn "python3 not available, skipping schema validation"
fi

# Step 2: Run MATLAB test harness
log_info "Launching MATLAB test harness..."

"${MATLAB_ROOT}/bin/matlab" -batch "
    addpath('${ALGO_DIR}/matlab');
    results = test_${ALGO}('${VECTORS_DIR}', '${RESULTS_DIR}');
    if results.Failed > 0
        fprintf('MATLAB tests FAILED: %d of %d\n', results.Failed, results.Total);
        exit(1);
    end
    fprintf('MATLAB tests PASSED: %d of %d\n', results.Passed, results.Total);
" 2>&1 | tee "${RESULTS_DIR}/matlab_test_output.log"

log_info "MATLAB tests passed for: $ALGO"

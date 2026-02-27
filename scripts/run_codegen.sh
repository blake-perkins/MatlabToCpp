#!/bin/bash
# run_codegen.sh — Run MATLAB Coder to generate C++ for a single algorithm.
#
# Usage: bash scripts/run_codegen.sh <algorithm_name>
#
# Invokes the algorithm's codegen_config.m, which configures and runs
# MATLAB Coder. Generated C++ source is written to algorithms/<name>/generated/.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: run_codegen.sh <algorithm_name>}"
ALGO_DIR="${REPO_ROOT}/algorithms/${ALGO}"
GEN_DIR="${ALGO_DIR}/generated"
RESULTS_DIR=$(ensure_results_dir "$ALGO")

validate_algorithm "$ALGO"

# Clean previous generated code
rm -rf "$GEN_DIR"
mkdir -p "$GEN_DIR"

log_info "Running MATLAB Coder for: $ALGO"

# Read the MATLAB entry point from algorithm.yaml
ENTRY_POINT=$(read_algo_yaml "$ALGO" "matlab_entry_point")
if [ -z "$ENTRY_POINT" ]; then
    ENTRY_POINT="$ALGO"
fi

# Run codegen
"${MATLAB_ROOT}/bin/matlab" -batch "
    addpath('${ALGO_DIR}/matlab');
    try
        codegen_config('${GEN_DIR}');
        fprintf('Code generation succeeded for ${ALGO}\n');
    catch e
        fprintf(2, 'Code generation FAILED for ${ALGO}: %s\n', e.message);
        exit(1);
    end
" 2>&1 | tee "${RESULTS_DIR}/codegen_output.log"

# Verify generated files exist
CPP_COUNT=$(find "$GEN_DIR" -name '*.cpp' -o -name '*.c' 2>/dev/null | wc -l)
HDR_COUNT=$(find "$GEN_DIR" -name '*.h' 2>/dev/null | wc -l)

if [ "$CPP_COUNT" -eq 0 ]; then
    log_error "No generated source files found in $GEN_DIR"
    exit 1
fi

# Record generated file manifest
find "$GEN_DIR" -type f | sort > "${RESULTS_DIR}/generated_manifest.txt"

# Extract function signatures from headers for API diff tracking
grep -hE '^\s*(extern\s+)?(void|int|double|float|bool|size_t)\s+\w+\(' \
    "$GEN_DIR"/*.h > "${RESULTS_DIR}/api_signatures.txt" 2>/dev/null || true

log_info "Code generation complete for: $ALGO ($CPP_COUNT source, $HDR_COUNT header files)"

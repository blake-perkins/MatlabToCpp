#!/bin/bash
# run_cpp_tests.sh — Run C++ unit tests (Google Test) for a single algorithm.
#
# Usage: bash scripts/run_cpp_tests.sh <algorithm_name>
#
# Runs CTest in the algorithm's build directory. The test binary also writes
# cpp_outputs.json for later equivalence comparison with MATLAB.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: run_cpp_tests.sh <algorithm_name>}"
BUILD_DIR="${WORKSPACE}/build/${ALGO}"
RESULTS_DIR=$(ensure_results_dir "$ALGO" "cpp")

if [ ! -d "$BUILD_DIR" ]; then
    log_error "Build directory not found: $BUILD_DIR. Run build_cpp.sh first."
    exit 1
fi

log_info "Running C++ tests for: $ALGO"

# Create output directory for cpp_outputs.json
mkdir -p "${BUILD_DIR}/test_outputs"

# Run tests via CTest
cd "$BUILD_DIR"
ctest --output-on-failure \
      --output-junit "${RESULTS_DIR}/cpp_test_results.xml" \
      --parallel "$(nproc 2>/dev/null || echo 4)" \
      2>&1 | tee "${RESULTS_DIR}/cpp_test_output.log"

# Copy test outputs for equivalence check
if [ -f "${BUILD_DIR}/test_outputs/cpp_outputs.json" ]; then
    cp "${BUILD_DIR}/test_outputs/cpp_outputs.json" "${RESULTS_DIR}/cpp_outputs.json"
    log_info "C++ outputs saved for equivalence check"
fi

log_info "C++ tests passed for: $ALGO"

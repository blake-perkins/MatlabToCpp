#!/bin/bash
# build_cpp.sh — CMake configure + build for a single algorithm.
#
# Usage: bash scripts/build_cpp.sh <algorithm_name>
#
# Installs Conan dependencies, then runs CMake configure and build.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: build_cpp.sh <algorithm_name>}"
ALGO_DIR="${REPO_ROOT}/algorithms/${ALGO}"
BUILD_DIR="${WORKSPACE}/build/${ALGO}"
RESULTS_DIR=$(ensure_results_dir "$ALGO")

validate_algorithm "$ALGO"

log_info "Building C++ for: $ALGO"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Ensure Conan has a default profile
conan profile detect --exist-ok 2>/dev/null || true

# Install Conan dependencies if conanfile exists
CONAN_TOOLCHAIN=""
if [ -f "${ALGO_DIR}/cpp/conanfile.py" ]; then
    log_info "Installing Conan dependencies..."

    # Use repo profile if it exists, otherwise default
    CONAN_PROFILE="${REPO_ROOT}/conan/profiles/linux-gcc12-release"
    if [ ! -f "$CONAN_PROFILE" ]; then
        CONAN_PROFILE="default"
    fi

    conan install "${ALGO_DIR}/cpp" \
        --output-folder="${BUILD_DIR}/conan" \
        --build=missing \
        --profile="${CONAN_PROFILE}" \
        2>&1 | tee "${RESULTS_DIR}/conan_install.log"

    # Conan 2 may place the toolchain in a nested directory
    TOOLCHAIN_FILE=$(find "${BUILD_DIR}/conan" -name "conan_toolchain.cmake" -print -quit 2>/dev/null)
    if [ -n "$TOOLCHAIN_FILE" ]; then
        CONAN_TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}"
    else
        log_warn "conan_toolchain.cmake not found — building without Conan toolchain"
    fi
fi

# CMake configure
log_info "CMake configure..."
cmake -S "${ALGO_DIR}/cpp" \
      -B "$BUILD_DIR" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTING=ON \
      -DGENERATED_DIR="${ALGO_DIR}/generated" \
      -DTEST_VECTORS_DIR="${ALGO_DIR}/test_vectors" \
      -DALGORITHM_NAME="${ALGO}" \
      ${CONAN_TOOLCHAIN} \
      2>&1 | tee "${RESULTS_DIR}/cmake_configure.log"

# CMake build
log_info "CMake build..."
cmake --build "$BUILD_DIR" \
      --parallel "$(nproc 2>/dev/null || echo 4)" \
      2>&1 | tee "${RESULTS_DIR}/build_output.log"

log_info "C++ build succeeded for: $ALGO"

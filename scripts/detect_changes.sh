#!/bin/bash
# detect_changes.sh — Determine which algorithms changed since a baseline commit.
#
# Usage: bash scripts/detect_changes.sh [BASELINE_COMMIT]
#
# Output: writes one algorithm name per line to ${WORKSPACE}/changed_algorithms.txt
# If no baseline is given, compares HEAD against HEAD~1.

source "$(dirname "$0")/common.sh"

BASELINE_COMMIT="${1:-}"
OUTPUT_FILE="${WORKSPACE}/changed_algorithms.txt"

# Default baseline: previous commit
if [ -z "$BASELINE_COMMIT" ]; then
    BASELINE_COMMIT=$(git -C "$REPO_ROOT" log --format='%H' -n 2 | tail -1)
fi

log_info "Detecting changes since ${BASELINE_COMMIT:0:12}..."

# Get list of changed files
CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only "$BASELINE_COMMIT" HEAD 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
    log_info "No changes detected."
    : > "$OUTPUT_FILE"
    exit 0
fi

# Track unique algorithm names
declare -A seen_algos
ALGOS=()

# Check if shared infrastructure changed (triggers rebuild of all algorithms)
REBUILD_ALL=false
while IFS= read -r file; do
    if [[ "$file" =~ ^(cmake/|scripts/|Jenkinsfile|algorithms/CMakeLists\.txt) ]]; then
        REBUILD_ALL=true
        break
    fi
done <<< "$CHANGED_FILES"

if [ "$REBUILD_ALL" = true ]; then
    log_info "Shared infrastructure changed — rebuilding all algorithms"
    for dir in "${REPO_ROOT}"/algorithms/*/; do
        algo=$(basename "$dir")
        if [ -f "$dir/algorithm.yaml" ]; then
            ALGOS+=("$algo")
        fi
    done
else
    # Extract algorithm names from changed file paths
    while IFS= read -r file; do
        if [[ "$file" =~ ^algorithms/([^/]+)/ ]]; then
            algo="${BASH_REMATCH[1]}"
            if [ -z "${seen_algos[$algo]:-}" ]; then
                seen_algos[$algo]=1
                # Verify it's actually an algorithm (has algorithm.yaml)
                if [ -f "${REPO_ROOT}/algorithms/${algo}/algorithm.yaml" ]; then
                    ALGOS+=("$algo")
                fi
            fi
        fi
    done <<< "$CHANGED_FILES"
fi

# Write output
if [ ${#ALGOS[@]} -eq 0 ]; then
    log_info "No algorithm changes detected."
    : > "$OUTPUT_FILE"
else
    printf "%s\n" "${ALGOS[@]}" > "$OUTPUT_FILE"
    log_info "Changed algorithms: ${ALGOS[*]}"
fi

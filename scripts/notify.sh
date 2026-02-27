#!/bin/bash
# notify.sh — Send notifications to algorithm owners and C++ consumers.
#
# Usage: bash scripts/notify.sh <algorithm_name> <success|failure>
#
# On success: emails C++ consumers with new version info and release notes.
# On failure: emails algorithm owner with failure diagnostics.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: notify.sh <algorithm_name> <success|failure>}"
STATUS="${2:?Usage: notify.sh <algorithm_name> <success|failure>}"

validate_algorithm "$ALGO"

OWNER=$(read_algo_yaml "$ALGO" "owner")
BUILD_URL="${BUILD_URL:-http://jenkins/job/unknown}"

if [ "$STATUS" = "success" ]; then
    NEW_VERSION=$(cat "${WORKSPACE}/results/${ALGO}/new_version.txt" 2>/dev/null || echo "unknown")

    SUBJECT="${ALGO} v${NEW_VERSION} published to Nexus"
    BODY="Algorithm: ${ALGO}
Version: ${NEW_VERSION}
Status: SUCCESS — Published to Nexus

To consume this package:
  conan install --requires=${ALGO}/${NEW_VERSION} --remote=nexus

Artifacts:
  Release notes: ${BUILD_URL}artifact/results/${ALGO}/reports/release_notes.md
  Equivalence report: ${BUILD_URL}artifact/results/${ALGO}/equivalence/equivalence_report.json
  API signature diff: ${BUILD_URL}artifact/results/${ALGO}/reports/api_signature_diff.txt
  MATLAB source diff: ${BUILD_URL}artifact/results/${ALGO}/reports/matlab_source_diff.patch

This is an automated notification from the MatlabToCpp pipeline."

    # Notify C++ consumers
    CONSUMERS=$(read_algo_consumers "$ALGO")
    while IFS= read -r consumer; do
        if [ -n "$consumer" ]; then
            send_email "$consumer" "$SUBJECT" "$BODY"
        fi
    done <<< "$CONSUMERS"

    # Also notify the algorithm owner
    if [ -n "$OWNER" ]; then
        send_email "$OWNER" "$SUBJECT" "$BODY"
    fi

    log_info "Success notifications sent for: ${ALGO} v${NEW_VERSION}"

elif [ "$STATUS" = "failure" ]; then
    SUBJECT="[FAILED] ${ALGO} pipeline failure"
    BODY="Algorithm: ${ALGO}
Status: FAILURE
Build URL: ${BUILD_URL}

The pipeline failed for this algorithm. Please check the Jenkins console output
for details and fix the issue before the next commit.

Common failure causes:
  - MATLAB test failures (check test vectors and algorithm logic)
  - MATLAB Coder errors (check codegen_config.m and type definitions)
  - C++ compilation errors (check generated code compatibility)
  - Equivalence check failures (MATLAB and C++ outputs differ beyond tolerance)

This is an automated notification from the MatlabToCpp pipeline."

    # Only notify the algorithm owner on failure
    if [ -n "$OWNER" ]; then
        send_email "$OWNER" "$SUBJECT" "$BODY"
    fi

    log_info "Failure notification sent to: $OWNER"
else
    log_error "Invalid status: $STATUS (expected 'success' or 'failure')"
    exit 1
fi

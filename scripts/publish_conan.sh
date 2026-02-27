#!/bin/bash
# publish_conan.sh — Create and upload Conan package to Nexus.
#
# Usage: bash scripts/publish_conan.sh <algorithm_name>
#
# Creates a Conan package from the built algorithm and uploads it
# to the configured Nexus Conan remote.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: publish_conan.sh <algorithm_name>}"
ALGO_DIR="${REPO_ROOT}/algorithms/${ALGO}"
NEW_VERSION=$(cat "${WORKSPACE}/results/${ALGO}/new_version.txt" 2>/dev/null)

if [ -z "$NEW_VERSION" ]; then
    log_error "No version found. Run bump_version.sh first."
    exit 1
fi

validate_algorithm "$ALGO"

log_info "Publishing Conan package: ${ALGO}/${NEW_VERSION}"

# Nexus credentials from environment (set by Jenkins credentials binding)
NEXUS_URL="${NEXUS_URL:?NEXUS_URL environment variable must be set}"
NEXUS_USER="${NEXUS_CREDS_USR:-${NEXUS_USER:-}}"
NEXUS_PASS="${NEXUS_CREDS_PSW:-${NEXUS_PASS:-}}"

if [ -z "$NEXUS_USER" ] || [ -z "$NEXUS_PASS" ]; then
    log_error "Nexus credentials not configured. Set NEXUS_CREDS_USR/NEXUS_CREDS_PSW or NEXUS_USER/NEXUS_PASS."
    exit 1
fi

# Configure Nexus remote (idempotent)
conan remote add nexus "$NEXUS_URL" --force 2>/dev/null || true
conan remote login nexus "$NEXUS_USER" -p "$NEXUS_PASS"

# Set GENERATED_DIR for the Conan build
export GENERATED_DIR="${ALGO_DIR}/generated"

# Create the package
conan create "${ALGO_DIR}/cpp" \
    --name="${ALGO}" \
    --version="${NEW_VERSION}" \
    -pr="${REPO_ROOT}/conan/profiles/linux-gcc12-release" \
    --build=missing \
    2>&1 | tee "${WORKSPACE}/results/${ALGO}/conan_create.log"

# Upload to Nexus
conan upload "${ALGO}/${NEW_VERSION}" \
    --remote=nexus \
    --confirm \
    2>&1 | tee -a "${WORKSPACE}/results/${ALGO}/conan_upload.log"

log_info "Published: ${ALGO}/${NEW_VERSION} to Nexus"

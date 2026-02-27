#!/bin/bash
# common.sh — Shared functions for all pipeline scripts.
#
# Source this at the top of every script:
#   source "$(dirname "$0")/common.sh"

set -euo pipefail

# ---- Logging ----

log_info() {
    echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_warn() {
    echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

# ---- Path resolution ----

# Repo root (parent of scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Workspace defaults to repo root when not running in Jenkins
WORKSPACE="${WORKSPACE:-${REPO_ROOT}}"

# MATLAB root — override via environment or Jenkins config
MATLAB_ROOT="${MATLAB_ROOT:-/opt/MATLAB/R2024b}"

# ---- Algorithm helpers ----

# Validate that an algorithm directory exists and has required files
validate_algorithm() {
    local algo="$1"
    local algo_dir="${REPO_ROOT}/algorithms/${algo}"

    if [ ! -d "$algo_dir" ]; then
        log_error "Algorithm directory not found: $algo_dir"
        return 1
    fi

    if [ ! -f "$algo_dir/algorithm.yaml" ]; then
        log_error "Missing algorithm.yaml in $algo_dir"
        return 1
    fi

    if [ ! -f "$algo_dir/VERSION" ]; then
        log_error "Missing VERSION file in $algo_dir"
        return 1
    fi

    return 0
}

# Read a field from algorithm.yaml (simple grep-based, no yq dependency)
read_algo_yaml() {
    local algo="$1"
    local field="$2"
    local yaml_file="${REPO_ROOT}/algorithms/${algo}/algorithm.yaml"

    grep "^${field}:" "$yaml_file" | sed "s/^${field}:[[:space:]]*//" | tr -d '"'
}

# Read the consumers list from algorithm.yaml
read_algo_consumers() {
    local algo="$1"
    local yaml_file="${REPO_ROOT}/algorithms/${algo}/algorithm.yaml"

    # Parse YAML list items under 'consumers:'
    awk '/^consumers:/{found=1; next} found && /^[[:space:]]+-/{gsub(/^[[:space:]]+-[[:space:]]*/, ""); print} found && /^[a-z]/{exit}' "$yaml_file"
}

# ---- Results directory ----

ensure_results_dir() {
    local algo="$1"
    local subdir="${2:-}"
    local dir="${WORKSPACE}/results/${algo}"

    if [ -n "$subdir" ]; then
        dir="${dir}/${subdir}"
    fi

    mkdir -p "$dir"
    echo "$dir"
}

# ---- Email helper ----

send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    # Use mail command if available, otherwise log the notification
    if command -v mail &>/dev/null; then
        echo "$body" | mail -s "$subject" "$to"
        log_info "Email sent to $to: $subject"
    else
        log_warn "mail command not available. Would send to $to:"
        log_warn "  Subject: $subject"
        log_warn "  Body: $body"
    fi
}

#!/bin/bash
# generate_reports.sh — Generate diff reports, release notes, and test comparison.
#
# Usage: bash scripts/generate_reports.sh <algorithm_name>
#
# Produces:
#   - MATLAB source diff (since last tag)
#   - Generated C++ diff (compared to cached previous build)
#   - API signature diff
#   - Release notes summary

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: generate_reports.sh <algorithm_name>}"
ALGO_DIR="${REPO_ROOT}/algorithms/${ALGO}"
REPORT_DIR=$(ensure_results_dir "$ALGO" "reports")
NEW_VERSION=$(cat "${WORKSPACE}/results/${ALGO}/new_version.txt" 2>/dev/null || echo "unknown")

log_info "Generating reports for: $ALGO v${NEW_VERSION}"

# ---- 1. MATLAB source diff ----
LAST_TAG=$(git -C "$REPO_ROOT" tag -l "${ALGO}/v*" --sort=-version:refname | head -2 | tail -1)
if [ -n "$LAST_TAG" ]; then
    git -C "$REPO_ROOT" diff "$LAST_TAG" HEAD -- "algorithms/${ALGO}/matlab/" \
        > "${REPORT_DIR}/matlab_source_diff.patch" 2>/dev/null || true
    log_info "MATLAB source diff generated (vs $LAST_TAG)"
else
    echo "Initial release — no previous version to diff" \
        > "${REPORT_DIR}/matlab_source_diff.patch"
fi

# ---- 2. Generated C++ diff ----
PREV_ARCHIVE="${WORKSPACE}/.cache/previous_builds/${ALGO}/generated"
CURR_GENERATED="${ALGO_DIR}/generated"

if [ -d "$PREV_ARCHIVE" ] && [ -d "$CURR_GENERATED" ]; then
    diff -rq "$PREV_ARCHIVE" "$CURR_GENERATED" \
        > "${REPORT_DIR}/generated_cpp_diff_summary.txt" 2>&1 || true
    diff -ru "$PREV_ARCHIVE" "$CURR_GENERATED" \
        > "${REPORT_DIR}/generated_cpp_diff.patch" 2>&1 || true
    log_info "Generated C++ diff computed"
else
    echo "No previous generated code to compare (first build or cache cleared)" \
        > "${REPORT_DIR}/generated_cpp_diff_summary.txt"
fi

# ---- 3. API signature diff ----
PREV_SIGS="${WORKSPACE}/.cache/previous_builds/${ALGO}/api_signatures.txt"
CURR_SIGS="${WORKSPACE}/results/${ALGO}/api_signatures.txt"

if [ -f "$PREV_SIGS" ] && [ -f "$CURR_SIGS" ]; then
    diff -u "$PREV_SIGS" "$CURR_SIGS" \
        > "${REPORT_DIR}/api_signature_diff.txt" 2>&1 || true
elif [ -f "$CURR_SIGS" ]; then
    cp "$CURR_SIGS" "${REPORT_DIR}/api_signature_diff.txt"
else
    echo "No API signatures available" > "${REPORT_DIR}/api_signature_diff.txt"
fi

# ---- 4. Archive current build for next run's comparison ----
ARCHIVE_DIR="${WORKSPACE}/.cache/previous_builds/${ALGO}"
rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

if [ -d "$CURR_GENERATED" ]; then
    cp -r "$CURR_GENERATED" "$ARCHIVE_DIR/generated"
fi
if [ -f "$CURR_SIGS" ]; then
    cp "$CURR_SIGS" "$ARCHIVE_DIR/api_signatures.txt"
fi

# ---- 5. Release notes ----
python3 - "$ALGO" "$NEW_VERSION" "$REPORT_DIR" "${WORKSPACE}" <<'PYEOF'
import json
import sys
import os
from datetime import date

algo = sys.argv[1]
version = sys.argv[2]
report_dir = sys.argv[3]
workspace = sys.argv[4]

# Load equivalence report if available
equiv = {}
equiv_file = os.path.join(workspace, "results", algo, "equivalence", "equivalence_report.json")
if os.path.exists(equiv_file):
    with open(equiv_file) as f:
        equiv = json.load(f)

# Load API diff if available
api_diff = ""
api_file = os.path.join(report_dir, "api_signature_diff.txt")
if os.path.exists(api_file):
    with open(api_file) as f:
        api_diff = f.read().strip()

# Load MATLAB source diff summary
matlab_diff = ""
matlab_diff_file = os.path.join(report_dir, "matlab_source_diff.patch")
if os.path.exists(matlab_diff_file):
    with open(matlab_diff_file) as f:
        content = f.read()
        # Count changed lines
        additions = content.count("\n+") - content.count("\n+++")
        deletions = content.count("\n-") - content.count("\n---")
        matlab_diff = f"{additions} additions, {deletions} deletions"

notes = f"""# {algo} v{version} — Release Notes

**Date**: {date.today().isoformat()}

## Equivalence Summary

| Metric | Value |
|--------|-------|
| Total tests | {equiv.get('total_tests', 'N/A')} |
| All passed | {equiv.get('all_passed', 'N/A')} |
| Max absolute error | {equiv.get('max_absolute_error', 'N/A')} |
| Max relative error | {equiv.get('max_relative_error', 'N/A')} |

## MATLAB Source Changes

{matlab_diff if matlab_diff else 'No MATLAB source changes'}

## API Changes

```
{api_diff if api_diff else 'No API changes'}
```

## Conan Install

```bash
conan install --requires={algo}/{version} --remote=nexus
```
"""

release_notes_path = os.path.join(report_dir, "release_notes.md")
with open(release_notes_path, "w") as f:
    f.write(notes)

print(f"Release notes written to {release_notes_path}")
PYEOF

log_info "Reports generated for: $ALGO v${NEW_VERSION}"

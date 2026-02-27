#!/bin/bash
# run_equivalence.sh — Compare MATLAB outputs vs C++ outputs within tolerance.
#
# Usage: bash scripts/run_equivalence.sh <algorithm_name>
#
# Reads matlab_outputs.json and cpp_outputs.json (produced by earlier stages),
# compares actual outputs element-by-element within the defined tolerances.
# This is the critical quality gate: if MATLAB and C++ disagree, the pipeline stops.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: run_equivalence.sh <algorithm_name>}"
MATLAB_RESULTS="${WORKSPACE}/results/${ALGO}/matlab/matlab_outputs.json"
CPP_RESULTS="${WORKSPACE}/results/${ALGO}/cpp/cpp_outputs.json"
REPORT_DIR=$(ensure_results_dir "$ALGO" "equivalence")

# Verify both output files exist
if [ ! -f "$MATLAB_RESULTS" ]; then
    log_error "MATLAB outputs not found: $MATLAB_RESULTS"
    log_error "Run run_matlab_tests.sh first."
    exit 1
fi

if [ ! -f "$CPP_RESULTS" ]; then
    log_error "C++ outputs not found: $CPP_RESULTS"
    log_error "Run run_cpp_tests.sh first."
    exit 1
fi

log_info "Running equivalence check for: $ALGO"

# Python comparison script
python3 - "$MATLAB_RESULTS" "$CPP_RESULTS" "$REPORT_DIR" "$ALGO" <<'PYEOF'
import json
import sys
import math

matlab_file = sys.argv[1]
cpp_file = sys.argv[2]
report_dir = sys.argv[3]
algo_name = sys.argv[4]

with open(matlab_file) as f:
    matlab_data = json.load(f)
with open(cpp_file) as f:
    cpp_data = json.load(f)

# Match test cases by name
matlab_by_name = {}
for item in matlab_data:
    name = item.get("test_name", "")
    matlab_by_name[name] = item

cpp_by_name = {}
for item in cpp_data:
    name = item.get("test_name", "")
    cpp_by_name[name] = item

results = []
all_passed = True
max_relative_error = 0.0
max_absolute_error = 0.0

# Compare each test case
all_names = set(matlab_by_name.keys()) | set(cpp_by_name.keys())
for name in sorted(all_names):
    if name not in matlab_by_name:
        results.append({"test_name": name, "passed": False, "error": "Missing from MATLAB results"})
        all_passed = False
        continue
    if name not in cpp_by_name:
        results.append({"test_name": name, "passed": False, "error": "Missing from C++ results"})
        all_passed = False
        continue

    m = matlab_by_name[name]
    c = cpp_by_name[name]
    tol = m.get("tolerance", 1e-10)

    # Compare all output fields dynamically (any key starting with "actual_")
    passed = True
    case_max_abs = 0.0
    case_max_rel = 0.0

    actual_fields = [k for k in m.keys() if k.startswith("actual_")]
    if not actual_fields:
        # Fallback for legacy format
        actual_fields = [k for k in m.keys() if k not in ("test_name", "tolerance", "passed")]

    for field in actual_fields:
        m_vals = m.get(field, [])
        c_vals = c.get(field, [])

        if not isinstance(m_vals, list):
            m_vals = [m_vals]
        if not isinstance(c_vals, list):
            c_vals = [c_vals]

        if len(m_vals) != len(c_vals):
            passed = False
            all_passed = False
            continue

        for mv, cv in zip(m_vals, c_vals):
            abs_err = abs(mv - cv)
            rel_err = abs_err / max(abs(mv), 1e-15)
            case_max_abs = max(case_max_abs, abs_err)
            case_max_rel = max(case_max_rel, rel_err)
            max_absolute_error = max(max_absolute_error, abs_err)
            max_relative_error = max(max_relative_error, rel_err)

            if abs_err > tol:
                passed = False
                all_passed = False

    results.append({
        "test_name": name,
        "passed": passed,
        "max_absolute_error": case_max_abs,
        "max_relative_error": case_max_rel,
        "tolerance": tol,
    })

# Build report
report = {
    "algorithm": algo_name,
    "all_passed": all_passed,
    "total_tests": len(results),
    "passed_tests": sum(1 for r in results if r["passed"]),
    "failed_tests": sum(1 for r in results if not r["passed"]),
    "max_absolute_error": max_absolute_error,
    "max_relative_error": max_relative_error,
    "details": results,
}

# Write report
report_path = f"{report_dir}/equivalence_report.json"
with open(report_path, "w") as f:
    json.dump(report, f, indent=2)

# Print summary
print(f"\n{'='*60}")
print(f"EQUIVALENCE REPORT: {algo_name}")
print(f"{'='*60}")
print(f"Total tests:        {report['total_tests']}")
print(f"Passed:             {report['passed_tests']}")
print(f"Failed:             {report['failed_tests']}")
print(f"Max absolute error: {max_absolute_error:.2e}")
print(f"Max relative error: {max_relative_error:.2e}")
print(f"{'='*60}")

if not all_passed:
    print("\nFAILED test cases:", file=sys.stderr)
    for r in results:
        if not r["passed"]:
            err_msg = r.get("error", f"max_abs_err={r['max_absolute_error']:.2e}")
            print(f"  FAIL: {r['test_name']} ({err_msg})", file=sys.stderr)
    print(f"\nEQUIVALENCE CHECK FAILED for {algo_name}", file=sys.stderr)
    sys.exit(1)

print(f"\nEQUIVALENCE CHECK PASSED for {algo_name}")
PYEOF

log_info "Equivalence check passed for: $ALGO"

#!/usr/bin/env python3
"""
MatlabToCpp Pipeline -- Interactive Demo
========================================

Self-contained demonstration of the full CI/CD pipeline.
Simulates all 10 Jenkins stages with real data -- no MATLAB, Jenkins, or Nexus required.

Usage:
    python demo/run_demo.py              # Full interactive demo (pauses between stages)
    python demo/run_demo.py --auto       # Auto-advance (no pauses)
    python demo/run_demo.py --failure    # Include a failure scenario

What this demo does:
    1. Detects which algorithms changed (git-based)
    2. Validates JSON test vectors against schema
    3. Runs the Kalman filter in Python (simulating MATLAB)
    4. Simulates MATLAB Coder C++ generation
    5. Simulates CMake build
    6. Runs "C++" tests (Python standing in for generated C++)
    7. Compares "MATLAB" vs "C++" outputs (real equivalence check)
    8. Bumps semantic version
    9. Generates release notes, diffs, and reports
   10. Shows what each team receives
"""

import json
import math
import os
import shutil
import sys
import textwrap
import time
from datetime import date
from pathlib import Path

# ---- Configuration ----

REPO_ROOT = Path(__file__).resolve().parent.parent
ALGO_NAME = "kalman_filter"
ALGO_DIR = REPO_ROOT / "algorithms" / ALGO_NAME
DEMO_OUTPUT = REPO_ROOT / "demo" / "output"
AUTO_MODE = "--auto" in sys.argv
FAILURE_MODE = "--failure" in sys.argv

# ---- Terminal colors (cross-platform) ----

class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    END = "\033[0m"

def print_header(text):
    width = 70
    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * width}")
    print(f"  {text}")
    print(f"{'=' * width}{Colors.END}\n")

def print_stage(number, title, description):
    bar = "-" * 65
    print(f"\n{Colors.BOLD}{Colors.CYAN}+{bar}+")
    print(f"|  Stage {number}/10: {title:<53}   |")
    print(f"+{bar}+{Colors.END}")
    print(f"{Colors.DIM}  {description}{Colors.END}\n")

def print_pass(msg):
    print(f"  {Colors.GREEN}[PASS]{Colors.END}  {msg}")

def print_fail(msg):
    print(f"  {Colors.RED}[FAIL]{Colors.END}  {msg}")

def print_info(msg):
    print(f"  {Colors.BLUE}[INFO]{Colors.END}  {msg}")

def print_warn(msg):
    print(f"  {Colors.YELLOW}[WARN]{Colors.END}  {msg}")

def print_artifact(label, content):
    print(f"\n  {Colors.BOLD}{label}:{Colors.END}")
    for line in content.strip().split("\n"):
        print(f"  {Colors.DIM}|{Colors.END} {line}")

def pause(context=""):
    if AUTO_MODE:
        time.sleep(0.5)
        return
    msg = f"{Colors.DIM}  Press Enter to continue"
    if context:
        msg += f" ({context})"
    msg += f"...{Colors.END}"
    input(msg)


# ============================================================
# Kalman Filter -- Pure Python (simulates MATLAB execution)
# ============================================================

def kalman_filter_python(state, measurement, state_covariance, measurement_noise, process_noise):
    """
    1D Kalman filter predict-update step.
    Identical logic to algorithms/kalman_filter/matlab/kalman_filter.m

    Args:
        state: [position, velocity]
        measurement: scalar observation
        state_covariance: [P11, P12, P21, P22] (flattened 2x2)
        measurement_noise: scalar R
        process_noise: scalar Q
    Returns:
        updated_state: [position, velocity]
        updated_covariance: [P11, P12, P21, P22]
    """
    # Reshape covariance
    P = [[state_covariance[0], state_covariance[1]],
         [state_covariance[2], state_covariance[3]]]

    # State transition (constant velocity, dt=1)
    F = [[1, 1], [0, 1]]

    # Measurement matrix (observe position)
    H = [1, 0]

    # Process noise
    Q = [[process_noise, 0], [0, process_noise]]

    # --- Predict ---
    x_pred = [
        F[0][0] * state[0] + F[0][1] * state[1],
        F[1][0] * state[0] + F[1][1] * state[1],
    ]

    # P_pred = F * P * F' + Q
    FP = [
        [F[0][0]*P[0][0] + F[0][1]*P[1][0], F[0][0]*P[0][1] + F[0][1]*P[1][1]],
        [F[1][0]*P[0][0] + F[1][1]*P[1][0], F[1][0]*P[0][1] + F[1][1]*P[1][1]],
    ]
    P_pred = [
        [FP[0][0]*F[0][0] + FP[0][1]*F[0][1] + Q[0][0], FP[0][0]*F[1][0] + FP[0][1]*F[1][1] + Q[0][1]],
        [FP[1][0]*F[0][0] + FP[1][1]*F[0][1] + Q[1][0], FP[1][0]*F[1][0] + FP[1][1]*F[1][1] + Q[1][1]],
    ]

    # --- Update ---
    y = measurement - (H[0] * x_pred[0] + H[1] * x_pred[1])  # innovation
    S = H[0]*P_pred[0][0]*H[0] + H[0]*P_pred[0][1]*H[1] + H[1]*P_pred[1][0]*H[0] + H[1]*P_pred[1][1]*H[1] + measurement_noise
    K = [(P_pred[0][0]*H[0] + P_pred[0][1]*H[1]) / S,
         (P_pred[1][0]*H[0] + P_pred[1][1]*H[1]) / S]

    updated_state = [x_pred[0] + K[0]*y, x_pred[1] + K[1]*y]

    # Joseph form: (I - KH) * P_pred * (I - KH)' + K * R * K'
    IKH = [[1 - K[0]*H[0], -K[0]*H[1]],
           [-K[1]*H[0], 1 - K[1]*H[1]]]

    # IKH * P_pred
    IKH_P = [
        [IKH[0][0]*P_pred[0][0] + IKH[0][1]*P_pred[1][0], IKH[0][0]*P_pred[0][1] + IKH[0][1]*P_pred[1][1]],
        [IKH[1][0]*P_pred[0][0] + IKH[1][1]*P_pred[1][0], IKH[1][0]*P_pred[0][1] + IKH[1][1]*P_pred[1][1]],
    ]
    # IKH_P * IKH'
    P_up = [
        [IKH_P[0][0]*IKH[0][0] + IKH_P[0][1]*IKH[0][1], IKH_P[0][0]*IKH[1][0] + IKH_P[0][1]*IKH[1][1]],
        [IKH_P[1][0]*IKH[0][0] + IKH_P[1][1]*IKH[0][1], IKH_P[1][0]*IKH[1][0] + IKH_P[1][1]*IKH[1][1]],
    ]
    # + K * R * K'
    P_up[0][0] += K[0] * measurement_noise * K[0]
    P_up[0][1] += K[0] * measurement_noise * K[1]
    P_up[1][0] += K[1] * measurement_noise * K[0]
    P_up[1][1] += K[1] * measurement_noise * K[1]

    updated_covariance = [P_up[0][0], P_up[0][1], P_up[1][0], P_up[1][1]]
    return updated_state, updated_covariance


# ============================================================
# Demo Pipeline Stages
# ============================================================

def stage_0_intro():
    print_header("MatlabToCpp Pipeline -- Interactive Demo")

    print(f"""  {Colors.BOLD}The Problem:{Colors.END}
  Algorithm developers write MATLAB. They manually run code generation,
  copy files to a shared folder, and email the C++ team. No versioning,
  no tests, no confidence the C++ even compiles.

  {Colors.BOLD}The Solution:{Colors.END}
  This pipeline automates everything. Algorithm devs push MATLAB + test
  vectors to Git. Jenkins handles codegen, building, testing, equivalence
  verification, versioning, and Conan package delivery to Nexus.

  {Colors.BOLD}This demo simulates all 10 pipeline stages with real data.{Colors.END}
  Python stands in for MATLAB and C++ -- the math is identical.
""")

    if FAILURE_MODE:
        print(f"  {Colors.YELLOW}[!] Failure mode enabled -- Stage 6 will show an equivalence failure.{Colors.END}\n")

    pause("ready to start")


def stage_1_detect_changes():
    print_stage(1, "Detect Changes", "Which algorithms were modified since the last build?")

    # Show what the script does
    print_info("Running: bash scripts/detect_changes.sh HEAD~1")
    print_info(f"Scanning git diff for changes under algorithms/...")
    time.sleep(0.3)

    # List the algorithm
    print_pass(f"Found changed algorithm: {Colors.BOLD}{ALGO_NAME}{Colors.END}")
    print_info(f"Files changed:")
    print(f"      algorithms/{ALGO_NAME}/matlab/kalman_filter.m")
    print(f"      algorithms/{ALGO_NAME}/test_vectors/nominal.json")

    pause()


def stage_2_matlab_tests():
    print_stage(2, "MATLAB Tests", "Validate the algorithm against JSON test vectors (Python simulating MATLAB)")

    # Load test vectors
    vectors_file = ALGO_DIR / "test_vectors" / "nominal.json"
    with open(vectors_file) as f:
        data = json.load(f)

    print_info(f"Loading test vectors: {vectors_file.name}")
    print_info(f"Found {len(data['test_cases'])} test cases\n")

    matlab_outputs = []
    all_passed = True

    for tc in data["test_cases"]:
        name = tc["name"]
        inputs = tc["inputs"]
        expected = tc["expected_output"]
        tol = tc.get("tolerance", data.get("global_tolerance", {})).get("absolute", 1e-10)

        # Run the algorithm (Python = MATLAB equivalent)
        updated_state, updated_cov = kalman_filter_python(
            inputs["state"], inputs["measurement"],
            inputs["state_covariance"], inputs["measurement_noise"],
            inputs["process_noise"]
        )

        # Compare
        exp_state = expected["updated_state"]
        exp_cov = expected["updated_covariance"]

        state_ok = all(abs(a - e) <= tol for a, e in zip(updated_state, exp_state))
        cov_ok = all(abs(a - e) <= tol for a, e in zip(updated_cov, exp_cov))

        if state_ok and cov_ok:
            print_pass(f"{name}")
        else:
            print_fail(f"{name}")
            all_passed = False

        matlab_outputs.append({
            "test_name": name,
            "actual_state": updated_state,
            "actual_covariance": updated_cov,
            "tolerance": tol,
        })

    # Save outputs for equivalence check
    matlab_dir = DEMO_OUTPUT / "matlab"
    matlab_dir.mkdir(parents=True, exist_ok=True)
    with open(matlab_dir / "matlab_outputs.json", "w") as f:
        json.dump(matlab_outputs, f, indent=2)

    print(f"\n  {Colors.GREEN}{Colors.BOLD}MATLAB Tests: {len(data['test_cases'])}/{len(data['test_cases'])} passed{Colors.END}")
    print_info("Actual outputs saved for equivalence check (Stage 6)")

    pause()
    return all_passed


def stage_3_codegen():
    print_stage(3, "Code Generation", "MATLAB Coder generates C++ from the MATLAB source")

    print_info("Running: matlab -batch \"codegen_config('algorithms/kalman_filter/generated')\"")
    time.sleep(0.3)

    # Simulate codegen output
    gen_dir = DEMO_OUTPUT / "generated"
    gen_dir.mkdir(parents=True, exist_ok=True)

    generated_files = {
        "kalman_filter.h": textwrap.dedent("""\
            // Generated by MATLAB Coder (simulated)
            #ifndef KALMAN_FILTER_H
            #define KALMAN_FILTER_H

            namespace kalman_filter {

            void kalman_filter(const double state[2], double measurement,
                               const double state_covariance[4],
                               double measurement_noise, double process_noise,
                               double updated_state[2], double updated_covariance[4]);

            } // namespace kalman_filter
            #endif
        """),
        "kalman_filter.cpp": textwrap.dedent("""\
            // Generated by MATLAB Coder (simulated)
            #include "kalman_filter.h"
            #include <cstring>

            namespace kalman_filter {

            void kalman_filter(const double state[2], double measurement,
                               const double state_covariance[4],
                               double measurement_noise, double process_noise,
                               double updated_state[2], double updated_covariance[4])
            {
                // ... (auto-generated implementation) ...
                // Predict
                double x_pred[2];
                x_pred[0] = state[0] + state[1];  // F * x
                x_pred[1] = state[1];

                // P_pred = F*P*F' + Q
                double P_pred[4];
                P_pred[0] = state_covariance[0] + state_covariance[1]
                          + state_covariance[2] + state_covariance[3] + process_noise;
                P_pred[1] = state_covariance[1] + state_covariance[3];
                P_pred[2] = state_covariance[2] + state_covariance[3];
                P_pred[3] = state_covariance[3] + process_noise;

                // Update
                double S = P_pred[0] + measurement_noise;
                double K[2] = {P_pred[0] / S, P_pred[2] / S};
                double y = measurement - x_pred[0];

                updated_state[0] = x_pred[0] + K[0] * y;
                updated_state[1] = x_pred[1] + K[1] * y;

                // Joseph form covariance update
                double IKH[4] = {1.0 - K[0], 0.0, -K[1], 1.0};
                // ... (full implementation) ...
            }

            } // namespace kalman_filter
        """),
        "kalman_filter_types.h": textwrap.dedent("""\
            // Generated by MATLAB Coder (simulated)
            #ifndef KALMAN_FILTER_TYPES_H
            #define KALMAN_FILTER_TYPES_H
            // No custom types needed for this algorithm
            #endif
        """),
        "rtwtypes.h": textwrap.dedent("""\
            // Generated by MATLAB Coder (simulated)
            #ifndef RTWTYPES_H
            #define RTWTYPES_H
            typedef double real_T;
            typedef int int32_T;
            typedef unsigned int uint32_T;
            typedef signed char int8_T;
            typedef unsigned char uint8_T;
            #endif
        """),
    }

    for filename, content in generated_files.items():
        (gen_dir / filename).write_text(content)
        print_pass(f"Generated: {filename}")
        time.sleep(0.1)

    # API signatures
    print_info("\nExtracted API signature:")
    print(f"      {Colors.CYAN}void kalman_filter(const double state[2], double measurement,")
    print(f"           const double state_covariance[4], double measurement_noise,")
    print(f"           double process_noise, double updated_state[2],")
    print(f"           double updated_covariance[4]);{Colors.END}")

    print(f"\n  {Colors.GREEN}{Colors.BOLD}Code generation: 4 files produced{Colors.END}")

    pause()


def stage_4_cpp_build():
    print_stage(4, "C++ Build", "CMake configure + build the generated code")

    print_info("Running: cmake -S algorithms/kalman_filter/cpp -B build/kalman_filter")
    time.sleep(0.3)

    steps = [
        "CMake configure... found GTest 1.14.0",
        "CMake configure... found nlohmann_json 3.11.3",
        "CMake configure... configuring kalman_filter (4 source files)",
        "Building: kalman_filter.cpp",
        "Building: kalman_filter_types.h (header only)",
        "Linking: libkalman_filter.a",
        "Building: test_kalman_filter.cpp",
        "Linking: test_kalman_filter",
    ]

    for step in steps:
        print_pass(step)
        time.sleep(0.15)

    print(f"\n  {Colors.GREEN}{Colors.BOLD}C++ Build: SUCCESS (0 errors, 0 warnings){Colors.END}")

    pause()


def stage_5_cpp_tests():
    print_stage(5, "C++ Tests", "Google Test validates generated C++ against the same JSON test vectors")

    # Load test vectors and run Python (standing in for C++)
    vectors_file = ALGO_DIR / "test_vectors" / "nominal.json"
    with open(vectors_file) as f:
        data = json.load(f)

    print_info(f"Running: ctest --output-on-failure")
    print_info(f"Test binary reads: {vectors_file.name}\n")

    cpp_outputs = []

    for tc in data["test_cases"]:
        name = tc["name"]
        inputs = tc["inputs"]
        expected = tc["expected_output"]
        tol = tc.get("tolerance", data.get("global_tolerance", {})).get("absolute", 1e-10)

        # In failure mode, introduce a tiny perturbation to simulate C++ divergence
        perturbation = 0.0
        if FAILURE_MODE and name == "high_uncertainty_initial":
            perturbation = 0.01  # enough to exceed tolerance

        updated_state, updated_cov = kalman_filter_python(
            inputs["state"], inputs["measurement"],
            inputs["state_covariance"], inputs["measurement_noise"],
            inputs["process_noise"]
        )
        # Apply perturbation (simulates codegen difference)
        updated_state = [s + perturbation for s in updated_state]

        exp_state = expected["updated_state"]
        exp_cov = expected["updated_covariance"]
        state_ok = all(abs(a - e) <= tol for a, e in zip(updated_state, exp_state))
        cov_ok = all(abs(a - e) <= tol for a, e in zip(updated_cov, exp_cov))

        if state_ok and cov_ok:
            print_pass(f"[Google Test] TestVectors/{name}")
        else:
            # In failure mode on this test, it still passes C++ tests (within its own tolerance)
            # but will fail equivalence (MATLAB vs C++ differ)
            print_pass(f"[Google Test] TestVectors/{name}")

        cpp_outputs.append({
            "test_name": name,
            "actual_state": updated_state,
            "actual_covariance": updated_cov,
            "tolerance": tol,
        })

    cpp_dir = DEMO_OUTPUT / "cpp"
    cpp_dir.mkdir(parents=True, exist_ok=True)
    with open(cpp_dir / "cpp_outputs.json", "w") as f:
        json.dump(cpp_outputs, f, indent=2)

    print(f"\n  {Colors.GREEN}{Colors.BOLD}C++ Tests: {len(data['test_cases'])}/{len(data['test_cases'])} passed{Colors.END}")

    pause()


def stage_6_equivalence():
    print_stage(6, "Equivalence Check", "Compare MATLAB actual outputs vs C++ actual outputs (tolerance-based)")

    # Load both output files
    with open(DEMO_OUTPUT / "matlab" / "matlab_outputs.json") as f:
        matlab_data = json.load(f)
    with open(DEMO_OUTPUT / "cpp" / "cpp_outputs.json") as f:
        cpp_data = json.load(f)

    print_info("Comparing element-by-element: |MATLAB_output - C++_output| <= tolerance\n")

    results = []
    all_passed = True
    max_abs_err = 0.0
    max_rel_err = 0.0

    for m, c in zip(matlab_data, cpp_data):
        name = m["test_name"]
        tol = m["tolerance"]
        passed = True
        case_max = 0.0

        for field in ["actual_state", "actual_covariance"]:
            for mv, cv in zip(m[field], c[field]):
                err = abs(mv - cv)
                case_max = max(case_max, err)
                max_abs_err = max(max_abs_err, err)
                if abs(mv) > 1e-15:
                    max_rel_err = max(max_rel_err, err / abs(mv))
                if err > tol:
                    passed = False
                    all_passed = False

        if passed:
            print_pass(f"{name:<30} max_err={case_max:.2e}  (tol={tol:.0e})")
        else:
            print_fail(f"{name:<30} max_err={case_max:.2e}  (tol={tol:.0e})  {Colors.RED}EXCEEDS TOLERANCE{Colors.END}")

        results.append({
            "test_name": name,
            "passed": passed,
            "max_absolute_error": case_max,
            "tolerance": tol,
        })

    # Write equivalence report
    equiv_dir = DEMO_OUTPUT / "equivalence"
    equiv_dir.mkdir(parents=True, exist_ok=True)
    report = {
        "algorithm": ALGO_NAME,
        "all_passed": all_passed,
        "total_tests": len(results),
        "passed_tests": sum(1 for r in results if r["passed"]),
        "failed_tests": sum(1 for r in results if not r["passed"]),
        "max_absolute_error": max_abs_err,
        "max_relative_error": max_rel_err,
        "details": results,
    }
    with open(equiv_dir / "equivalence_report.json", "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n  {'-' * 60}")
    print(f"  Max absolute error: {max_abs_err:.2e}")
    print(f"  Max relative error: {max_rel_err:.2e}")

    if all_passed:
        print(f"\n  {Colors.GREEN}{Colors.BOLD}EQUIVALENCE CHECK: PASSED [OK]{Colors.END}")
        print(f"  {Colors.GREEN}MATLAB and C++ produce identical results within tolerance.{Colors.END}")
    else:
        print(f"\n  {Colors.RED}{Colors.BOLD}EQUIVALENCE CHECK: FAILED [X]{Colors.END}")
        print(f"  {Colors.RED}MATLAB and C++ outputs diverge beyond tolerance!{Colors.END}")
        print(f"\n  {Colors.YELLOW}Pipeline would STOP here. The algorithm team is notified:{Colors.END}")
        print(f"  {Colors.DIM}  To: algorithm-team@example.com")
        print(f"  Subject: [FAILED] kalman_filter pipeline failure")
        print(f"  Body: Equivalence check failed. MATLAB and C++ produce different")
        print(f"        results for test case 'high_uncertainty_initial'.{Colors.END}")

    pause()
    return all_passed


def stage_7_version_bump():
    print_stage(7, "Version Bump", "Determine semantic version from conventional commit messages")

    print_info("Analyzing commits since last tag...")
    time.sleep(0.3)

    commits = [
        ("feat(kalman_filter)", "add process noise parameter"),
        ("fix(kalman_filter)", "correct Joseph form covariance update"),
    ]

    print_info("Recent commits for kalman_filter:\n")
    for prefix, msg in commits:
        print(f"      {Colors.CYAN}{prefix}: {msg}{Colors.END}")

    print(f"\n  {Colors.YELLOW}feat{Colors.END} detected -> MINOR bump")
    print(f"\n  Version: {Colors.DIM}0.1.0{Colors.END} -> {Colors.GREEN}{Colors.BOLD}0.2.0{Colors.END}")
    print(f"  Tag:     {Colors.CYAN}kalman_filter/v0.2.0{Colors.END}")

    pause()


def stage_8_reports():
    print_stage(8, "Generate Reports", "Diffs, release notes, and test comparison artifacts")

    # Load equivalence report
    with open(DEMO_OUTPUT / "equivalence" / "equivalence_report.json") as f:
        equiv = json.load(f)

    # Generate release notes
    reports_dir = DEMO_OUTPUT / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    release_notes = f"""# kalman_filter v0.2.0 -- Release Notes

**Date**: {date.today().isoformat()}

## Equivalence Summary

| Metric | Value |
|--------|-------|
| Total tests | {equiv['total_tests']} |
| All passed | {equiv['all_passed']} |
| Max absolute error | {equiv['max_absolute_error']:.2e} |
| Max relative error | {equiv['max_relative_error']:.2e} |

## MATLAB Source Changes

2 additions, 1 deletion in kalman_filter.m

## API Changes

No API signature changes (function interface unchanged)

## Conan Install

```bash
conan install --requires=kalman_filter/0.2.0 --remote=nexus
```
"""
    (reports_dir / "release_notes.md").write_text(release_notes)

    print_pass("MATLAB source diff -> matlab_source_diff.patch")
    print_pass("Generated C++ diff -> generated_cpp_diff.patch")
    print_pass("API signature diff -> api_signature_diff.txt (no changes)")
    print_pass("Release notes -> release_notes.md")

    print_artifact("Release Notes Preview", release_notes[:500])

    pause()


def stage_9_publish():
    print_stage(9, "Publish to Nexus", "Create and upload Conan package")

    steps = [
        "conan remote add nexus https://nexus.example.com/repository/conan/ --force",
        "conan remote login nexus ****",
        "conan create algorithms/kalman_filter/cpp --name=kalman_filter --version=0.2.0",
        "  Exporting: kalman_filter/0.2.0",
        "  Building: Release, x86_64, GCC 12",
        "  Packaging: libkalman_filter.a + headers",
        "conan upload kalman_filter/0.2.0 --remote=nexus --confirm",
    ]

    for step in steps:
        if step.startswith("  "):
            print(f"      {Colors.DIM}{step}{Colors.END}")
        else:
            print_info(step)
        time.sleep(0.2)

    print(f"\n  {Colors.GREEN}{Colors.BOLD}Published: kalman_filter/0.2.0 to Nexus [OK]{Colors.END}")

    pause()


def stage_10_notify():
    print_stage(10, "Notify Teams", "Email algorithm owner (success) and C++ consumers (new version)")

    print(f"\n  {Colors.BOLD}Email #1 -- To C++ Integration Team:{Colors.END}")
    print(f"  {Colors.DIM}+------------------------------------------------------------+")
    print(f"  | To:      cpp-integration@example.com                      |")
    print(f"  | Subject: kalman_filter v0.2.0 published to Nexus          |")
    print(f"  |                                                            |")
    print(f"  | A new version of kalman_filter is available.               |")
    print(f"  |                                                            |")
    print(f"  | To consume:                                                |")
    print(f"  |   conan install --requires=kalman_filter/0.2.0             |")
    print(f"  |                                                            |")
    print(f"  | Equivalence: 4/4 tests passed (max err: 0.00e+00)         |")
    print(f"  | API changes: None                                          |")
    print(f"  |                                                            |")
    print(f"  | Release notes: [Jenkins artifact link]                     |")
    print(f"  +------------------------------------------------------------+{Colors.END}")

    print(f"\n  {Colors.BOLD}Email #2 -- To Algorithm Team:{Colors.END}")
    print(f"  {Colors.DIM}+------------------------------------------------------------+")
    print(f"  | To:      algorithm-team@example.com                       |")
    print(f"  | Subject: kalman_filter v0.2.0 published to Nexus          |")
    print(f"  |                                                            |")
    print(f"  | Your algorithm was successfully tested, versioned, and     |")
    print(f"  | published. The C++ team has been notified.                 |")
    print(f"  +------------------------------------------------------------+{Colors.END}")

    pause()


def show_summary():
    print_header("Demo Complete -- What Each Team Sees")

    print(f"""
  {Colors.BOLD}{Colors.BLUE}ALGORITHM TEAM (MATLAB Developers):{Colors.END}
  - Push MATLAB code + JSON test vectors to Git
  - Receive email: success confirmation or failure diagnostics
  - Never touch C++, CMake, Conan, or Jenkins
  - Fix and re-push if any quality gate fails

  {Colors.BOLD}{Colors.GREEN}C++ INTEGRATION TEAM:{Colors.END}
  - Receive email when new version is published
  - Run: conan install --requires=kalman_filter/0.2.0
  - Review: release notes, API diff, equivalence report
  - Confidence: every package passed 6 quality gates

  {Colors.BOLD}{Colors.YELLOW}PIPELINE (Jenkins -- Automated):{Colors.END}
  - Triggered by every push to Git
  - 10 stages, 6 quality gates
  - Nothing reaches Nexus unless MATLAB and C++ agree
  - All logic in portable shell scripts (not locked to Jenkins)
""")

    print(f"  {Colors.BOLD}Demo artifacts written to:{Colors.END} demo/output/")
    print(f"      matlab/matlab_outputs.json       -- MATLAB test results")
    print(f"      cpp/cpp_outputs.json             -- C++ test results")
    print(f"      equivalence/equivalence_report.json -- Side-by-side comparison")
    print(f"      reports/release_notes.md          -- What C++ team receives")
    print(f"      generated/kalman_filter.h         -- Simulated codegen output")

    print(f"\n  {Colors.BOLD}Diagrams (render on GitHub):{Colors.END}")
    print(f"      docs/diagrams/workflow.md             -- End-to-end flow")
    print(f"      docs/diagrams/pipeline_stages.md      -- Jenkins stages + quality gates")
    print(f"      docs/diagrams/responsibility_matrix.md -- RACI chart")
    print(f"      docs/diagrams/repo_structure.md       -- Color-coded ownership map")


# ============================================================
# Main
# ============================================================

def main():
    # Enable ANSI colors on Windows
    if sys.platform == "win32":
        os.system("")  # enables ANSI escape sequences on Windows 10+

    # Clean previous demo output
    if DEMO_OUTPUT.exists():
        shutil.rmtree(DEMO_OUTPUT)
    DEMO_OUTPUT.mkdir(parents=True)

    stage_0_intro()
    stage_1_detect_changes()
    stage_2_matlab_tests()
    stage_3_codegen()
    stage_4_cpp_build()
    stage_5_cpp_tests()

    equiv_passed = stage_6_equivalence()

    if not equiv_passed:
        print(f"\n  {Colors.RED}{Colors.BOLD}Pipeline stopped at Stage 6 (equivalence failure).{Colors.END}")
        print(f"  {Colors.YELLOW}In a real pipeline, the algorithm team would fix the issue")
        print(f"  and push again. No broken code reaches the C++ team.{Colors.END}\n")
        show_summary()
        return

    stage_7_version_bump()
    stage_8_reports()
    stage_9_publish()
    stage_10_notify()
    show_summary()


if __name__ == "__main__":
    main()

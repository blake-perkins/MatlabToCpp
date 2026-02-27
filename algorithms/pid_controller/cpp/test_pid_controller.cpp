/**
 * test_pid_controller.cpp
 *
 * C++ test harness for the pid_controller algorithm.
 * Reads the same JSON test vectors used by the MATLAB test harness,
 * runs the generated C++ function, and validates outputs within tolerance.
 *
 * Also writes cpp_outputs.json for equivalence comparison with MATLAB.
 */

#include <gtest/gtest.h>
#include <nlohmann/json.hpp>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
#include <cmath>

// Generated header from MATLAB Coder
#include "pid_controller.h"

using json = nlohmann::json;
namespace fs = std::filesystem;

#ifndef TEST_VECTORS_DIR
#error "TEST_VECTORS_DIR must be defined at compile time"
#endif

#ifndef OUTPUT_DIR
#define OUTPUT_DIR "."
#endif

// ---- Test case data structure ----

struct TestCase {
    std::string name;
    std::string description;

    // Inputs
    double error;
    double integral;
    double prev_error;
    double kp;
    double ki;
    double kd;
    double dt;

    // Expected outputs
    double expected_output;
    double expected_new_integral;
    double expected_new_prev_error;

    // Tolerance
    double abs_tolerance;
};

// For Google Test to print test case names
std::string TestCaseName(const ::testing::TestParamInfo<TestCase>& info) {
    return info.param.name;
}

// ---- Load test vectors from JSON ----

std::vector<TestCase> LoadTestVectors(const std::string& dir) {
    std::vector<TestCase> cases;

    for (const auto& entry : fs::directory_iterator(dir)) {
        if (entry.path().extension() != ".json") continue;
        if (entry.path().filename() == "schema.json") continue;

        std::ifstream f(entry.path());
        if (!f.is_open()) continue;

        json data = json::parse(f);

        // Global tolerance defaults
        double global_abs_tol = 1e-10;
        if (data.contains("global_tolerance") &&
            data["global_tolerance"].contains("absolute")) {
            global_abs_tol = data["global_tolerance"]["absolute"].get<double>();
        }

        for (const auto& tc : data["test_cases"]) {
            TestCase t;
            t.name = tc["name"].get<std::string>();
            t.description = tc.value("description", "");

            // Parse inputs
            t.error = tc["inputs"]["error"].get<double>();
            t.integral = tc["inputs"]["integral"].get<double>();
            t.prev_error = tc["inputs"]["prev_error"].get<double>();
            t.kp = tc["inputs"]["kp"].get<double>();
            t.ki = tc["inputs"]["ki"].get<double>();
            t.kd = tc["inputs"]["kd"].get<double>();
            t.dt = tc["inputs"]["dt"].get<double>();

            // Parse expected outputs
            t.expected_output = tc["expected_output"]["output"].get<double>();
            t.expected_new_integral = tc["expected_output"]["new_integral"].get<double>();
            t.expected_new_prev_error = tc["expected_output"]["new_prev_error"].get<double>();

            // Per-case tolerance overrides global
            t.abs_tolerance = global_abs_tol;
            if (tc.contains("tolerance") && tc["tolerance"].contains("absolute")) {
                t.abs_tolerance = tc["tolerance"]["absolute"].get<double>();
            }

            cases.push_back(t);
        }
    }

    return cases;
}

// ---- Parameterized test ----

class PidControllerTest : public ::testing::TestWithParam<TestCase> {};

TEST_P(PidControllerTest, MatchesExpectedOutput) {
    const auto& tc = GetParam();

    // Output variables
    double output = 0.0;
    double new_integral = 0.0;
    double new_prev_error = 0.0;

    // Call generated C++ function
    pid_controller::pid_controller(
        tc.error, tc.integral, tc.prev_error,
        tc.kp, tc.ki, tc.kd, tc.dt,
        &output, &new_integral, &new_prev_error);

    // Validate outputs
    EXPECT_NEAR(output, tc.expected_output, tc.abs_tolerance)
        << "Output mismatch in test case: " << tc.name;
    EXPECT_NEAR(new_integral, tc.expected_new_integral, tc.abs_tolerance)
        << "Integral mismatch in test case: " << tc.name;
    EXPECT_NEAR(new_prev_error, tc.expected_new_prev_error, tc.abs_tolerance)
        << "Prev error mismatch in test case: " << tc.name;
}

INSTANTIATE_TEST_SUITE_P(
    TestVectors,
    PidControllerTest,
    ::testing::ValuesIn(LoadTestVectors(TEST_VECTORS_DIR)),
    TestCaseName
);

// ---- Write outputs for equivalence comparison ----

class CppOutputWriter : public ::testing::Environment {
public:
    void TearDown() override {
        auto cases = LoadTestVectors(TEST_VECTORS_DIR);
        json outputs = json::array();

        for (const auto& tc : cases) {
            double output = 0.0;
            double new_integral = 0.0;
            double new_prev_error = 0.0;

            pid_controller::pid_controller(
                tc.error, tc.integral, tc.prev_error,
                tc.kp, tc.ki, tc.kd, tc.dt,
                &output, &new_integral, &new_prev_error);

            json result;
            result["test_name"] = tc.name;
            result["actual_output"] = output;
            result["actual_new_integral"] = new_integral;
            result["actual_new_prev_error"] = new_prev_error;
            result["tolerance"] = tc.abs_tolerance;
            outputs.push_back(result);
        }

        // Write to output directory
        fs::path output_dir(OUTPUT_DIR);
        fs::create_directories(output_dir);
        std::ofstream f(output_dir / "cpp_outputs.json");
        f << outputs.dump(2);
    }
};

// Register the output writer
testing::Environment* const output_env =
    testing::AddGlobalTestEnvironment(new CppOutputWriter);

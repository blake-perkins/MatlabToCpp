/**
 * test_kalman_filter.cpp
 *
 * C++ test harness for the kalman_filter algorithm.
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
#include "kalman_filter.h"

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
    std::vector<double> state;           // 2x1
    double measurement;
    std::vector<double> state_covariance; // 4x1 (flattened 2x2)
    double measurement_noise;
    double process_noise;

    // Expected outputs
    std::vector<double> expected_state;       // 2x1
    std::vector<double> expected_covariance;  // 4x1

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
            t.state = tc["inputs"]["state"].get<std::vector<double>>();
            t.measurement = tc["inputs"]["measurement"].get<double>();
            t.state_covariance = tc["inputs"]["state_covariance"].get<std::vector<double>>();
            t.measurement_noise = tc["inputs"]["measurement_noise"].get<double>();
            t.process_noise = tc["inputs"]["process_noise"].get<double>();

            // Parse expected outputs
            t.expected_state = tc["expected_output"]["updated_state"].get<std::vector<double>>();
            t.expected_covariance = tc["expected_output"]["updated_covariance"].get<std::vector<double>>();

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

class KalmanFilterTest : public ::testing::TestWithParam<TestCase> {};

TEST_P(KalmanFilterTest, MatchesExpectedOutput) {
    const auto& tc = GetParam();

    // Prepare input arrays
    double state[2] = {tc.state[0], tc.state[1]};
    double cov[4] = {tc.state_covariance[0], tc.state_covariance[1],
                     tc.state_covariance[2], tc.state_covariance[3]};

    // Output arrays
    double updated_state[2] = {0.0, 0.0};
    double updated_cov[4] = {0.0, 0.0, 0.0, 0.0};

    // Call generated C++ function
    // NOTE: The exact function signature depends on MATLAB Coder output.
    // You may need to adjust this call to match the generated API.
    kalman_filter::kalman_filter(state, tc.measurement, cov,
                                tc.measurement_noise, tc.process_noise,
                                updated_state, updated_cov);

    // Validate state output
    for (size_t i = 0; i < tc.expected_state.size(); i++) {
        EXPECT_NEAR(updated_state[i], tc.expected_state[i], tc.abs_tolerance)
            << "State mismatch at index " << i
            << " in test case: " << tc.name;
    }

    // Validate covariance output
    for (size_t i = 0; i < tc.expected_covariance.size(); i++) {
        EXPECT_NEAR(updated_cov[i], tc.expected_covariance[i], tc.abs_tolerance)
            << "Covariance mismatch at index " << i
            << " in test case: " << tc.name;
    }
}

INSTANTIATE_TEST_SUITE_P(
    TestVectors,
    KalmanFilterTest,
    ::testing::ValuesIn(LoadTestVectors(TEST_VECTORS_DIR)),
    TestCaseName
);

// ---- Write outputs for equivalence comparison ----

class OutputCollector : public ::testing::EmptyTestEventListener {
public:
    json outputs = json::array();

    void OnTestEnd(const ::testing::TestInfo& test_info) override {
        // Record actual outputs for each test case
        // This is a simplified version — the full implementation would
        // re-run the algorithm and capture outputs
    }
};

// Write cpp_outputs.json after all tests complete
class CppOutputWriter : public ::testing::Environment {
public:
    void TearDown() override {
        // Re-run all test cases and write actual outputs for equivalence check
        auto cases = LoadTestVectors(TEST_VECTORS_DIR);
        json outputs = json::array();

        for (const auto& tc : cases) {
            double state[2] = {tc.state[0], tc.state[1]};
            double cov[4] = {tc.state_covariance[0], tc.state_covariance[1],
                             tc.state_covariance[2], tc.state_covariance[3]};
            double updated_state[2] = {0.0, 0.0};
            double updated_cov[4] = {0.0, 0.0, 0.0, 0.0};

            kalman_filter::kalman_filter(state, tc.measurement, cov,
                                        tc.measurement_noise, tc.process_noise,
                                        updated_state, updated_cov);

            json result;
            result["test_name"] = tc.name;
            result["actual_updated_state"] = {updated_state[0], updated_state[1]};
            result["actual_updated_covariance"] = {updated_cov[0], updated_cov[1],
                                                    updated_cov[2], updated_cov[3]};
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

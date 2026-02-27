/**
 * test_low_pass_filter.cpp
 *
 * C++ test harness for the low_pass_filter algorithm.
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
#include "low_pass_filter.h"

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
    std::vector<double> input_signal;
    double alpha;

    // Expected outputs
    std::vector<double> expected_output_signal;

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
            t.input_signal = tc["inputs"]["input_signal"].get<std::vector<double>>();
            t.alpha = tc["inputs"]["alpha"].get<double>();

            // Parse expected outputs
            t.expected_output_signal = tc["expected_output"]["output_signal"].get<std::vector<double>>();

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

class LowPassFilterTest : public ::testing::TestWithParam<TestCase> {};

TEST_P(LowPassFilterTest, MatchesExpectedOutput) {
    const auto& tc = GetParam();
    int n = static_cast<int>(tc.input_signal.size());

    // Allocate output buffer
    std::vector<double> output_signal(n, 0.0);

    // Call generated C++ function
    low_pass_filter::low_pass_filter(
        tc.input_signal.data(), tc.alpha, n, output_signal.data());

    // Validate output
    for (int i = 0; i < n; i++) {
        EXPECT_NEAR(output_signal[i], tc.expected_output_signal[i], tc.abs_tolerance)
            << "Output mismatch at index " << i
            << " in test case: " << tc.name;
    }
}

INSTANTIATE_TEST_SUITE_P(
    TestVectors,
    LowPassFilterTest,
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
            int n = static_cast<int>(tc.input_signal.size());
            std::vector<double> output_signal(n, 0.0);

            low_pass_filter::low_pass_filter(
                tc.input_signal.data(), tc.alpha, n, output_signal.data());

            json result;
            result["test_name"] = tc.name;
            result["actual_output_signal"] = output_signal;
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

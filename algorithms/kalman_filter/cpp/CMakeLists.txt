cmake_minimum_required(VERSION 3.20)

# Algorithm name — used for library target, test target, and install paths
set(ALGO_NAME kalman_filter)

# GENERATED_DIR must be passed by the build script (-DGENERATED_DIR=...)
# It points to the MATLAB Coder output directory
if(NOT DEFINED GENERATED_DIR)
    # Default to sibling generated/ directory (created by CI)
    set(GENERATED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../generated")
endif()

# TEST_VECTORS_DIR points to the shared JSON test vectors
if(NOT DEFINED TEST_VECTORS_DIR)
    set(TEST_VECTORS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../test_vectors")
endif()

# --- Collect generated source files ---
file(GLOB GENERATED_SOURCES "${GENERATED_DIR}/*.cpp" "${GENERATED_DIR}/*.c")
file(GLOB GENERATED_HEADERS "${GENERATED_DIR}/*.h")

if(NOT GENERATED_SOURCES)
    message(FATAL_ERROR
        "No generated source files found in ${GENERATED_DIR}. "
        "Run MATLAB Coder first (scripts/run_codegen.sh ${ALGO_NAME}).")
endif()

# --- Algorithm library ---
add_library(${ALGO_NAME} STATIC ${GENERATED_SOURCES})
target_include_directories(${ALGO_NAME} PUBLIC ${GENERATED_DIR})
set_target_properties(${ALGO_NAME} PROPERTIES
    CXX_STANDARD 17
    POSITION_INDEPENDENT_CODE ON
)

# --- Install rules (used by Conan packaging) ---
install(TARGETS ${ALGO_NAME} ARCHIVE DESTINATION lib)
install(FILES ${GENERATED_HEADERS} DESTINATION include/${ALGO_NAME})

# --- Tests ---
option(BUILD_TESTING "Build tests" ON)
if(BUILD_TESTING)
    enable_testing()
    find_package(GTest REQUIRED)
    find_package(nlohmann_json REQUIRED)

    add_executable(test_${ALGO_NAME} test_${ALGO_NAME}.cpp)
    target_link_libraries(test_${ALGO_NAME} PRIVATE
        ${ALGO_NAME}
        GTest::gtest_main
        nlohmann_json::nlohmann_json
    )
    target_compile_definitions(test_${ALGO_NAME} PRIVATE
        TEST_VECTORS_DIR="${TEST_VECTORS_DIR}"
        OUTPUT_DIR="${CMAKE_BINARY_DIR}/test_outputs"
    )

    include(GoogleTest)
    gtest_discover_tests(test_${ALGO_NAME})
endif()

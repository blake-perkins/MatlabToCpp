# FindGeneratedCode.cmake
#
# Helper module for locating MATLAB Coder generated C++ source files.
#
# Usage:
#   set(GENERATED_DIR "/path/to/generated")
#   include(FindGeneratedCode)
#   # Sets: GENERATED_SOURCES, GENERATED_HEADERS
#
# This module is included by per-algorithm CMakeLists.txt files when
# they need to locate the generated code directory dynamically.

if(NOT DEFINED GENERATED_DIR)
    message(FATAL_ERROR "GENERATED_DIR must be set before including FindGeneratedCode")
endif()

if(NOT IS_DIRECTORY "${GENERATED_DIR}")
    message(FATAL_ERROR "GENERATED_DIR does not exist: ${GENERATED_DIR}")
endif()

file(GLOB GENERATED_SOURCES "${GENERATED_DIR}/*.cpp" "${GENERATED_DIR}/*.c")
file(GLOB GENERATED_HEADERS "${GENERATED_DIR}/*.h")

list(LENGTH GENERATED_SOURCES _gen_src_count)
list(LENGTH GENERATED_HEADERS _gen_hdr_count)

message(STATUS "FindGeneratedCode: Found ${_gen_src_count} source(s), ${_gen_hdr_count} header(s) in ${GENERATED_DIR}")

if(_gen_src_count EQUAL 0)
    message(FATAL_ERROR "No generated source files found in ${GENERATED_DIR}")
endif()

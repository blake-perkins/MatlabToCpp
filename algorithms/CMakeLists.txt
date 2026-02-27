cmake_minimum_required(VERSION 3.20)
project(MatlabToCpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Auto-discover algorithm subdirectories
# Each algorithm must have a cpp/CMakeLists.txt to be included
file(GLOB algorithm_entries RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} */cpp/CMakeLists.txt)

foreach(entry ${algorithm_entries})
    # Extract algorithm name from path: "kalman_filter/cpp/CMakeLists.txt" -> "kalman_filter"
    get_filename_component(algo_cpp_dir ${entry} DIRECTORY)
    get_filename_component(algo_name ${algo_cpp_dir} DIRECTORY)

    message(STATUS "Found algorithm: ${algo_name}")
    add_subdirectory(${algo_name}/cpp ${algo_name})
endforeach()

if(NOT algorithm_entries)
    message(WARNING "No algorithms found. Each algorithm needs a cpp/CMakeLists.txt.")
endif()

cmake_minimum_required(VERSION 3.20)
project(sensor_pipeline CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(kalman_filter REQUIRED)
find_package(low_pass_filter REQUIRED)
find_package(pid_controller REQUIRED)

add_executable(sensor_pipeline src/main.cpp)
target_link_libraries(sensor_pipeline PRIVATE
    kalman_filter::kalman_filter
    low_pass_filter::low_pass_filter
    pid_controller::pid_controller
)

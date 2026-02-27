# Consuming MatlabToCpp Packages (C++ Developer Guide)

This guide covers how to use algorithm packages published by the MatlabToCpp pipeline. You'll receive Conan packages that are pre-tested and verified equivalent to the original MATLAB implementation.

## Prerequisites

- [Conan 2.x](https://docs.conan.io/2/installation.html) (`pip install conan`)
- CMake 3.20+
- GCC 12+ (or equivalent C++17 compiler)

## 1. Configure the Nexus Remote

Add the Nexus Conan repository as a remote:

```bash
# Add the remote (get the URL from your DevOps team)
conan remote add nexus http://<NEXUS_IP>:8081/repository/conan-hosted/

# Login (get credentials from your DevOps team)
conan remote login nexus <username> -p <password>
```

Verify connectivity:

```bash
conan search "*" --remote=nexus
```

You should see packages like `kalman_filter`, `low_pass_filter`, `pid_controller`.

## 2. Browse Available Packages

```bash
# List all packages
conan search "*" --remote=nexus

# Get details about a specific package
conan inspect kalman_filter/0.2.0 --remote=nexus
```

## 3. Add to Your CMake Project

### conanfile.py (recommended)

Create a `conanfile.py` in your project root:

```python
from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, CMakeDeps, cmake_layout


class MyApp(ConanFile):
    name = "my_app"
    version = "1.0.0"
    settings = "os", "compiler", "build_type", "arch"

    def requirements(self):
        self.requires("kalman_filter/[>=0.1.0]")
        # Add more algorithms as needed:
        # self.requires("low_pass_filter/[>=0.1.0]")
        # self.requires("pid_controller/[>=0.1.0]")

    def generate(self):
        tc = CMakeToolchain(self)
        tc.generate()
        deps = CMakeDeps(self)
        deps.generate()

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()
```

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)
project(my_app CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(kalman_filter REQUIRED)
# find_package(low_pass_filter REQUIRED)
# find_package(pid_controller REQUIRED)

add_executable(my_app src/main.cpp)
target_link_libraries(my_app PRIVATE
    kalman_filter::kalman_filter
    # low_pass_filter::low_pass_filter
    # pid_controller::pid_controller
)
```

### Build

```bash
# Install dependencies from Nexus
conan install . --build=missing

# Configure and build
cmake --preset conan-release
cmake --build --preset conan-release
```

## 4. Call the Algorithm

Each algorithm is generated in its own C++ namespace matching the algorithm name.

### Kalman Filter

```cpp
#include "kalman_filter.h"

// Inputs
double state[2] = {1.0, 0.0};           // [position, velocity]
double measurement = 1.05;
double covariance[4] = {1.0, 0.0, 0.0, 1.0};
double meas_noise = 0.1;
double proc_noise = 0.01;

// Outputs (filled by the function)
double updated_state[2];
double updated_cov[4];

kalman_filter::kalman_filter(
    state, measurement, covariance,
    meas_noise, proc_noise,
    updated_state, updated_cov);
```

### Low-Pass Filter

```cpp
#include "low_pass_filter.h"

double input_signal[] = {1.0, 3.0, 2.0, 5.0, 4.0};
double output_signal[5];
double alpha = 0.3;  // smoothing factor (0 = heavy smoothing, 1 = no smoothing)

low_pass_filter::low_pass_filter(input_signal, alpha, 5, output_signal);
```

### PID Controller

```cpp
#include "pid_controller.h"

double error = 1.5;
double integral = 0.0;
double prev_error = 0.0;
double kp = 1.0, ki = 0.1, kd = 0.05;
double dt = 0.01;

double output, new_integral, new_prev_error;

pid_controller::pid_controller(
    error, integral, prev_error,
    kp, ki, kd, dt,
    &output, &new_integral, &new_prev_error);
```

### Key patterns

- All functions use **raw C arrays** (not `std::vector`), since MATLAB Coder generates C-style code
- Input arrays are `const`; output arrays are filled by the function
- The namespace matches the algorithm name: `kalman_filter::kalman_filter(...)`
- Headers are at `<algorithm_name>.h` (Conan handles include paths)

## 5. Handle Version Updates

When a new algorithm version is published, you'll receive an email containing:

- **Conan install command**: `conan install --requires=kalman_filter/0.3.0 --remote=nexus`
- **Release notes**: what changed, why, and how
- **API signature diff**: shows if the function signature changed
- **Equivalence report**: confirms C++ matches MATLAB within tolerance

### What to check

| Version bump | What it means | Action needed |
|-------------|---------------|---------------|
| PATCH (0.1.0 → 0.1.1) | Bug fix, no API change | Update version, rebuild |
| MINOR (0.1.0 → 0.2.0) | New feature, backward compatible | Update version, check release notes |
| MAJOR (0.1.0 → 1.0.0) | Breaking API change | Review API diff, update calling code |

### Updating your version

In your `conanfile.py`, update the version range or pin:

```python
# Version range (auto-updates within range)
self.requires("kalman_filter/[>=0.2.0 <1.0.0]")

# Pinned version (explicit control)
self.requires("kalman_filter/0.2.1")
```

## 6. Working Example

See [examples/sensor_pipeline/](../examples/sensor_pipeline/) for a complete working application that chains all three algorithms:

1. Generates a noisy sine wave (simulating sensor readings)
2. Applies the **low-pass filter** to smooth the signal
3. Runs the **Kalman filter** to estimate position and velocity
4. Uses the **PID controller** to compute a control signal

Build and run:
```bash
cd examples/sensor_pipeline
conan install . --build=missing
cmake --preset conan-release
cmake --build --preset conan-release
./build/Release/sensor_pipeline
```

Output:
```
=============================================================
  Sensor Processing Pipeline — Example Consumer Application
=============================================================

Step        Raw  Filtered    KF Est       Ref   Control
-----  --------  --------  --------  --------  --------
0        -0.951    -0.951    -0.865     0.000     1.306
1         2.265     0.014    -0.218     1.545     2.238
...
Pipeline complete. All three algorithms consumed via Conan.
```

## 7. Troubleshooting

### "Package not found in remotes"

The Nexus remote is not configured:
```bash
conan remote list                    # Check configured remotes
conan remote add nexus http://...    # Add if missing
conan remote login nexus user -p pw  # Login
```

### "No compatible binary package"

Your Conan profile doesn't match the published binary. The pipeline publishes for `gcc 12, Release, Linux x86_64`. Options:

```bash
# Option A: Use a matching profile
conan install . -pr=path/to/matching-profile

# Option B: Build from source (requires conancenter for gtest/nlohmann_json)
conan install . --build=missing
```

### "Headers not found" after conan install

Ensure your CMakeLists.txt has:
```cmake
find_package(kalman_filter REQUIRED)
target_link_libraries(myapp PRIVATE kalman_filter::kalman_filter)
```

And your CMake configure uses the Conan toolchain:
```bash
cmake --preset conan-release
# or: cmake -DCMAKE_TOOLCHAIN_FILE=build/Release/generators/conan_toolchain.cmake
```

### "Multiple definitions" linker error

If linking multiple algorithms that have common dependencies, ensure you're using the Conan-generated targets (double-colon syntax) — they handle transitive dependencies correctly.

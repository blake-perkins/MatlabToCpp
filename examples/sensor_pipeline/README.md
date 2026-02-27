# Sensor Processing Pipeline — Example Consumer

Demonstrates consuming all three MatlabToCpp algorithms as Conan packages:

- **low_pass_filter** — smooths noisy sensor data
- **kalman_filter** — estimates state (position + velocity)
- **pid_controller** — generates control signals to track a reference

## Prerequisites

- Conan 2.x
- CMake 3.20+
- GCC 12+ or equivalent C++17 compiler
- Algorithms published to Nexus (run the Jenkins pipeline first)

## Build

```bash
# Add Nexus remote (if not already configured)
conan remote add nexus http://<EC2_IP>:8081/repository/conan-hosted/

# Install dependencies from Nexus
conan install . --build=missing --remote=nexus

# Build
cmake --preset conan-release
cmake --build --preset conan-release

# Run
./build/Release/sensor_pipeline
```

## What It Does

1. Generates a noisy sine wave (simulating sensor readings)
2. Applies the **low-pass filter** to smooth the signal
3. Runs the **Kalman filter** to estimate position and velocity
4. Uses the **PID controller** to compute a control signal tracking the reference
5. Prints a table showing raw, filtered, estimated, reference, and control values

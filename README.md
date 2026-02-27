# MatlabToCpp

Automated pipeline for converting MATLAB algorithms to C++ using MATLAB Coder, with equivalence testing, semantic versioning, and Conan package delivery.

## Overview

Algorithm developers write MATLAB code and define JSON test vectors (input/output pairs). A Jenkins pipeline automatically:

1. Runs MATLAB unit tests against the test vectors
2. Generates C++ via MATLAB Coder
3. Builds the C++ with CMake
4. Runs C++ unit tests against the **same** test vectors
5. Verifies MATLAB and C++ produce equivalent results (tolerance-based)
6. Bumps the semantic version
7. Generates release notes and reports
8. Publishes a Conan package to Nexus
9. Notifies the C++ integration team

Three algorithms are included as working examples: `kalman_filter`, `low_pass_filter`, and `pid_controller`. All pass the full 10-stage pipeline and are published to Nexus.

## Documentation

| Audience | Document | What it covers |
|----------|----------|---------------|
| Everyone | [Demo Walkthrough](docs/demo_walkthrough.md) | Scripted 15-min presentation with talking points |
| Algorithm devs | [Adding an Algorithm](docs/adding_an_algorithm.md) | Step-by-step: add your MATLAB algorithm to the pipeline |
| Algorithm devs | [Test Vector Format](docs/test_vector_format.md) | JSON test vector specification |
| C++ devs | [Consuming Packages](docs/consuming_packages.md) | How to use published Conan packages in your project |
| C++ devs | [Example Consumer App](examples/sensor_pipeline/) | Working app chaining all 3 algorithms |
| DevOps / Leads | [Going to Production](docs/going_to_production.md) | Replace all mocks with real MATLAB, algorithms, and credentials |
| DevOps | [EC2 Deployment](deploy/ec2/README.md) | One-command AWS deployment guide |

### Architecture diagrams

- [Pipeline Stages](docs/diagrams/pipeline_stages.md) — 10 stages with 6 quality gates
- [End-to-End Workflow](docs/diagrams/workflow.md) — Algorithm Team → Jenkins → C++ Team
- [Repository Ownership](docs/diagrams/repo_structure.md) — Who owns what
- [Responsibility Matrix](docs/diagrams/responsibility_matrix.md) — RACI chart

## Repository Structure

```
MatlabToCpp/
├── Jenkinsfile                  # CI/CD pipeline (delegates to scripts/)
├── algorithms/                  # One subdirectory per algorithm
│   ├── kalman_filter/           # Extended Kalman filter (state estimation)
│   ├── low_pass_filter/         # IIR low-pass filter (signal smoothing)
│   ├── pid_controller/          # Discrete PID controller (feedback control)
│   └── CMakeLists.txt           # Auto-discovers algorithm subdirectories
├── scripts/                     # Portable shell scripts (CI building blocks)
├── cmake/                       # Shared CMake modules
├── conan/                       # Conan profiles (linux-gcc12-release)
├── templates/                   # Report templates (release notes)
├── examples/
│   └── sensor_pipeline/         # Example C++ consumer app
├── demo/
│   └── run_demo.py              # Interactive Python demo (no MATLAB needed)
├── deploy/
│   └── ec2/                     # AWS deployment (Docker Compose, Jenkins, Nexus)
└── docs/                        # Guides and diagrams
```

Each algorithm directory follows the same structure:

```
algorithms/kalman_filter/
├── algorithm.yaml       # Metadata (owner, consumers, description)
├── VERSION              # Current semantic version (e.g., 0.1.0)
├── CHANGELOG.md         # Release history
├── matlab/              # MATLAB source + test harness + codegen config
├── test_vectors/        # JSON test cases (shared by MATLAB and C++)
├── generated/           # MATLAB Coder output (C++ source + headers)
└── cpp/                 # CMake build, C++ test harness, Conan recipe
```

## For Algorithm Developers

### Adding a new algorithm

See [docs/adding_an_algorithm.md](docs/adding_an_algorithm.md) for the full guide.

Quick summary:
1. Copy any existing algorithm as a template: `cp -r algorithms/kalman_filter algorithms/my_algorithm`
2. Replace the MATLAB source with your algorithm
3. Define test vectors in `test_vectors/*.json` (see [docs/test_vector_format.md](docs/test_vector_format.md))
4. Update `algorithm.yaml` with your metadata
5. Update `codegen_config.m` for your function signature
6. Push to Git — the pipeline handles everything else

### Defining tests

You define tests once as JSON — they run in both MATLAB and C++:

```json
{
  "test_cases": [
    {
      "name": "nominal_case",
      "inputs": { "state": [1.0, 0.5], "measurement": 1.05 },
      "expected_output": { "updated_state": [1.025, 0.49] },
      "tolerance": { "absolute": 1e-10 }
    }
  ]
}
```

### Commit message conventions

Version bumps are determined from commit messages:
- `fix(algo_name): description` — PATCH bump (0.1.0 → 0.1.1)
- `feat(algo_name): description` — MINOR bump (0.1.0 → 0.2.0)
- `feat(algo_name)!: description` — MAJOR bump (0.1.0 → 1.0.0)

## For C++ Developers

See [docs/consuming_packages.md](docs/consuming_packages.md) for the full guide.

### Quick start

```bash
# Add the Nexus remote
conan remote add nexus http://<NEXUS_IP>:8081/repository/conan-hosted/

# Install a package
conan install --requires=kalman_filter/0.1.0 --remote=nexus
```

### In your CMakeLists.txt

```cmake
find_package(kalman_filter REQUIRED)
target_link_libraries(myapp PRIVATE kalman_filter::kalman_filter)
```

### In your code

```cpp
#include "kalman_filter.h"

double state[2] = {1.0, 0.0};
double measurement = 1.05;
// ... (see consuming_packages.md for complete examples)

kalman_filter::kalman_filter(state, measurement, cov, meas_noise, proc_noise,
                             updated_state, updated_cov);
```

Each release includes release notes, API signature diffs, and an equivalence report confirming C++ matches MATLAB.

## Running the Pipeline Locally

All pipeline stages can be run locally via the shell scripts in `scripts/`:

```bash
# Detect which algorithms changed
bash scripts/detect_changes.sh HEAD~1

# Run MATLAB tests for one algorithm
bash scripts/run_matlab_tests.sh kalman_filter

# Run code generation
bash scripts/run_codegen.sh kalman_filter

# Build C++
bash scripts/build_cpp.sh kalman_filter

# Run C++ tests
bash scripts/run_cpp_tests.sh kalman_filter

# Check equivalence
bash scripts/run_equivalence.sh kalman_filter
```

## Demo

### Interactive Python demo (no MATLAB needed)

```bash
python demo/run_demo.py              # Full interactive demo
python demo/run_demo.py --auto       # Auto-advance (no pauses)
python demo/run_demo.py --failure    # Failure scenario demo
```

### Presenting to stakeholders

See [docs/demo_walkthrough.md](docs/demo_walkthrough.md) for a scripted 15-minute presentation with talking points for each pipeline stage.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Algorithm source | MATLAB |
| Code generation | MATLAB Coder |
| C++ build | CMake 3.20+ |
| C++ testing | Google Test |
| Package management | Conan 2.x |
| Artifact repository | Nexus 3 |
| CI/CD | Jenkins |
| Versioning | Semantic versioning (conventional commits) |

## Going to Production

The included algorithms and credentials are for demo purposes. See [docs/going_to_production.md](docs/going_to_production.md) for the step-by-step guide to replace all mock components with real MATLAB, real algorithms, and hardened infrastructure.

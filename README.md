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
7. Publishes a Conan package to Nexus
8. Notifies the C++ integration team

## Repository Structure

```
MatlabToCpp/
├── Jenkinsfile                  # CI/CD pipeline (delegates to scripts/)
├── algorithms/                  # One subdirectory per algorithm
│   ├── CMakeLists.txt           # Auto-discovers algorithm subdirectories
│   └── kalman_filter/           # Example algorithm
│       ├── algorithm.yaml       # Metadata (owner, consumers, description)
│       ├── VERSION              # Current semantic version
│       ├── CHANGELOG.md         # Release history
│       ├── matlab/              # MATLAB source + test harness + codegen config
│       ├── test_vectors/        # JSON test cases (shared by MATLAB and C++)
│       └── cpp/                 # CMake build, C++ test harness, Conan recipe
├── scripts/                     # Portable shell scripts (CI building blocks)
├── cmake/                       # Shared CMake modules
├── conan/                       # Conan profiles
├── templates/                   # Report templates
└── docs/                        # Guides and diagrams
```

## For Algorithm Developers

### Adding a new algorithm

See [docs/adding_an_algorithm.md](docs/adding_an_algorithm.md) for the full guide.

Quick summary:
1. Copy `algorithms/kalman_filter/` as a template
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
      "inputs": { "state": [1.0, 0.5], "measurement": [1.05] },
      "expected_output": [1.025, 0.49],
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

### Consuming packages

When a new version is published, you'll receive an email with the Conan install command:

```bash
conan install --requires=kalman_filter/1.2.3 --remote=nexus
```

Each release includes:
- Release notes with change summary
- API signature diff (so you know if your integration needs updating)
- Equivalence report (confidence that C++ matches MATLAB)

## Running the pipeline locally

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

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Algorithm source | MATLAB |
| Code generation | MATLAB Coder |
| C++ build | CMake 3.20+ |
| C++ testing | Google Test |
| Package management | Conan 2.x |
| Artifact repository | Nexus |
| CI/CD | Jenkins |
| Versioning | Semantic versioning (conventional commits) |

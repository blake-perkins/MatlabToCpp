# Repository Structure

## Ownership Map

Files are color-coded by who owns them:
- **Blue** = Algorithm Team
- **Green** = C++ Team (templates, rarely modified)
- **Yellow** = Pipeline / DevOps
- **Purple** = Shared / auto-generated

```mermaid
flowchart TB
    subgraph root ["MatlabToCpp/"]
        JF["Jenkinsfile"]
        GI[".gitignore"]
        RM["README.md"]

        subgraph algorithms ["algorithms/"]
            ACML["CMakeLists.txt<br>(auto-discovers algos)"]

            subgraph kf ["kalman_filter/ (example algorithm)"]
                AY["algorithm.yaml"]
                VF["VERSION"]
                CL["CHANGELOG.md"]

                subgraph matlab ["matlab/"]
                    KFM["kalman_filter.m<br>(algorithm source)"]
                    CGM["codegen_config.m<br>(coder config)"]
                    TKF["test_kalman_filter.m<br>(MATLAB test harness)"]
                end

                subgraph tv ["test_vectors/"]
                    SC["schema.json"]
                    NOM["nominal.json"]
                    EDGE["edge_cases.json"]
                end

                subgraph cpp ["cpp/"]
                    CCML["CMakeLists.txt"]
                    TCPP["test_kalman_filter.cpp<br>(C++ test harness)"]
                    CONAN["conanfile.py"]
                end

                subgraph gen ["generated/ (gitignored)"]
                    GCPP["*.cpp, *.h<br>(MATLAB Coder output)"]
                end
            end
        end

        subgraph scripts ["scripts/"]
            CMN["common.sh"]
            DET["detect_changes.sh"]
            RMT["run_matlab_tests.sh"]
            RCG["run_codegen.sh"]
            BLD["build_cpp.sh"]
            RCT["run_cpp_tests.sh"]
            REQ["run_equivalence.sh"]
            BMP["bump_version.sh"]
            GRP["generate_reports.sh"]
            PUB["publish_conan.sh"]
            NOT["notify.sh"]
        end

        subgraph cmake_dir ["cmake/"]
            FGC["FindGeneratedCode.cmake"]
        end

        subgraph conan_dir ["conan/"]
            PROF["profiles/linux-gcc12-release"]
        end

        subgraph docs_dir ["docs/"]
            ADD["adding_an_algorithm.md"]
            TVF["test_vector_format.md"]
            DIAG["diagrams/"]
        end
    end

    %% Color coding by ownership
    style KFM fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style CGM fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style TKF fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style AY fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style SC fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style NOM fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style EDGE fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style matlab fill:#e3f2fd,stroke:#1565c0
    style tv fill:#e3f2fd,stroke:#1565c0

    style CCML fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style TCPP fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style CONAN fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style FGC fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style PROF fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style cpp fill:#e8f5e9,stroke:#2e7d32

    style JF fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style CMN fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style DET fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style RMT fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style RCG fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style BLD fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style RCT fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style REQ fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style BMP fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style GRP fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style PUB fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style NOT fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style scripts fill:#fff8e1,stroke:#f9a825

    style GCPP fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style gen fill:#f3e5f5,stroke:#7b1fa2
    style VF fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style CL fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
```

## Legend

| Color | Owner | What they edit |
|-------|-------|---------------|
| Blue | Algorithm Team | MATLAB source, test vectors, codegen config, algorithm.yaml |
| Green | C++ Team / Shared | CMake files, C++ test harness, Conan recipes (rarely changes) |
| Yellow | DevOps / Pipeline | Jenkinsfile, all shell scripts |
| Purple | Auto-generated | VERSION, CHANGELOG (bumped by pipeline), generated C++ (gitignored) |

## Adding a New Algorithm

To add a new algorithm, copy the `kalman_filter/` directory:

```
algorithms/
├── kalman_filter/   <-- existing template
└── my_new_algo/     <-- copy and customize
    ├── algorithm.yaml
    ├── VERSION          (set to 0.1.0)
    ├── CHANGELOG.md
    ├── matlab/
    │   ├── my_new_algo.m
    │   ├── codegen_config.m
    │   └── test_my_new_algo.m
    ├── test_vectors/
    │   ├── schema.json
    │   └── nominal.json
    └── cpp/
        ├── CMakeLists.txt
        ├── test_my_new_algo.cpp
        └── conanfile.py
```

The top-level `algorithms/CMakeLists.txt` auto-discovers new directories — no changes needed there.

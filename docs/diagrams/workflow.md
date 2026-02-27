# End-to-End Workflow

```mermaid
flowchart TB
    subgraph algo_team ["Algorithm Team (MATLAB Developers)"]
        A1[Write / Update<br>MATLAB Algorithm] --> A2[Define Test Vectors<br>JSON: inputs, outputs, tolerances]
        A2 --> A3[Update codegen_config.m<br>if function signature changed]
        A3 --> A4[git commit & push<br>using conventional commits]
    end

    subgraph jenkins ["Jenkins Pipeline (Automated)"]
        J1[Detect Changed<br>Algorithms] --> J2{MATLAB Tests<br>Pass?}
        J2 -->|Yes| J3[Run MATLAB Coder<br>Generate C++]
        J2 -->|No| JF1[Notify Algorithm Team:<br>Fix MATLAB code]
        J3 --> J4{C++ Compiles?}
        J4 -->|Yes| J5[Run C++ Tests<br>Google Test]
        J4 -->|No| JF2[Notify Algorithm Team:<br>Fix codegen config]
        J5 --> J6{C++ Tests<br>Pass?}
        J6 -->|Yes| J7{MATLAB vs C++<br>Equivalent?}
        J6 -->|No| JF3[Notify Algorithm Team:<br>Generated code issue]
        J7 -->|Yes| J8[Bump Semantic Version]
        J7 -->|No| JF4[Notify Algorithm Team:<br>Equivalence failure]
        J8 --> J9[Generate Reports<br>Diffs, Release Notes]
        J9 --> J10[Publish Conan Package<br>to Nexus]
        J10 --> J11[Notify C++ Team:<br>New version available]
    end

    subgraph cpp_team ["C++ Integration Team"]
        C1[Receive Email<br>New version + release notes] --> C2[Review API Diff<br>& Equivalence Report]
        C2 --> C3[conan install<br>--requires=algo/x.y.z]
        C3 --> C4[Integrate into<br>C++ Application]
    end

    subgraph nexus ["Nexus Artifact Repository"]
        N1[(Conan Packages<br>Versioned Libraries)]
    end

    A4 --> J1
    J10 --> N1
    C3 --> N1
    JF1 --> A1
    JF2 --> A1
    JF3 --> A1
    JF4 --> A1

    style algo_team fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style jenkins fill:#fff8e1,stroke:#f9a825,stroke-width:2px
    style cpp_team fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style nexus fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style JF1 fill:#ffcdd2,stroke:#c62828
    style JF2 fill:#ffcdd2,stroke:#c62828
    style JF3 fill:#ffcdd2,stroke:#c62828
    style JF4 fill:#ffcdd2,stroke:#c62828
```

## Key Points

- **Algorithm Team** only touches MATLAB code + JSON test vectors. They never write C++.
- **Jenkins** handles everything from codegen through packaging. All 6 quality gates must pass.
- **C++ Team** receives ready-to-consume Conan packages with confidence reports.
- **Failure feedback** always flows back to the Algorithm Team — they own fixing issues before code is published.

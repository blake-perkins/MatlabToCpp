# Demo Walkthrough

Scripted guide for presenting the MatlabToCpp pipeline to stakeholders, algorithm developers, and C++ developers. Estimated time: 15-20 minutes.

## Before the Demo

### What to have open

1. **Browser tab: Jenkins** — `http://<EC2_IP>:8080` (admin/admin)
2. **Browser tab: Nexus** — `http://<EC2_IP>:8081` (admin/admin123)
3. **Terminal** — SSH'd into EC2 or ready to run `demo/run_demo.py` locally
4. **This document** — for talking points

### Quick connectivity check

```bash
# Verify Jenkins is up
curl -s -o /dev/null -w "%{http_code}" http://<EC2_IP>:8080

# Verify Nexus is up
curl -s -o /dev/null -w "%{http_code}" http://<EC2_IP>:8081
```

---

## Part 1: The Problem (2 minutes)

**Talking points:**

> "Today, algorithm developers write MATLAB code and then someone manually converts it to C++. This creates three problems:"

1. **No confidence** — How do you know the C++ matches the MATLAB? Manual testing, eyeball comparison, hope.
2. **No versioning** — Which version of the algorithm is the C++ team using? When did it change? What changed?
3. **Slow handoff** — Algorithm developer finishes, emails a zip file, C++ developer integrates weeks later. If there's a bug, the cycle restarts.

> "MatlabToCpp solves all three. The algorithm developer pushes MATLAB code. Everything else is automated."

**Show:** Open `docs/diagrams/workflow.md` (or render the Mermaid diagram) to show the end-to-end flow.

---

## Part 2: Live Pipeline on Jenkins (8 minutes)

### Trigger a build

1. Open Jenkins > **MatlabToCpp** job
2. Click **Build with Parameters**
3. Check **FORCE_ALL** > Click **Build**
4. Click into the running build to watch the console

### Stage-by-stage talking points

**Stage 1 — Detect Changes**
> "The pipeline only builds what changed. If you touched `kalman_filter`, only that algorithm rebuilds. Today we're forcing all three to demonstrate."

**Stage 2 — MATLAB Tests**
> "First gate: does the MATLAB code actually produce correct results? We run it against JSON test vectors — the same test vectors that C++ will use later."

**Stage 3 — Code Generation**
> "MATLAB Coder automatically generates C++ from the MATLAB source. No human writes C++. The algorithm developer never touches C++."

**Stage 4 — C++ Build**
> "Standard CMake build. The generated C++ compiles into a static library with Conan packaging."

**Stage 5 — C++ Tests**
> "The generated C++ runs against the *exact same* test vectors as MATLAB. Same inputs, same expected outputs, same tolerances."

**Stage 6 — Equivalence Check** *(pause here for emphasis)*
> "This is the critical gate. We compare MATLAB outputs vs C++ outputs element-by-element. If they differ beyond the tolerance, the pipeline STOPS. Nothing broken reaches the C++ team."

**Stage 7 — Version Bump**
> "Version is computed automatically from commit messages. `fix:` = patch, `feat:` = minor, `feat!:` = major. No manual version management."

**Stage 8 — Generate Reports**
> "Release notes, API diffs, equivalence reports — all generated automatically."

**Stage 9 — Publish to Nexus**
> "The C++ library is packaged as a Conan package and uploaded to Nexus. The C++ team installs it with one command."

**Stage 10 — Notify**
> "The C++ team gets an email: 'New version available. Here's what changed, here's the API diff, here's the equivalence report, here's the install command.'"

### After the build completes

Show the build result page:
- Green checkmarks on all stages
- Click **Artifacts** to show generated reports

---

## Part 3: Nexus Packages (2 minutes)

1. Switch to the **Nexus** browser tab
2. Click **Browse** > **conan-hosted**
3. Show the three published packages:
   - `kalman_filter/0.1.0`
   - `low_pass_filter/0.1.0`
   - `pid_controller/0.1.0`

**Talking point:**
> "These are real Conan packages. The C++ team doesn't download zip files or copy-paste headers. They add one line to their build file and Conan handles the rest — versioning, dependencies, include paths, linking."

---

## Part 4: Consumer Side (3 minutes)

Show the `examples/sensor_pipeline/` directory:

### conanfile.py

```python
self.requires("kalman_filter/[>=0.1.0]")
self.requires("low_pass_filter/[>=0.1.0]")
self.requires("pid_controller/[>=0.1.0]")
```

> "Three lines. That's all the C++ team writes to pull in three algorithms."

### CMakeLists.txt

```cmake
find_package(kalman_filter REQUIRED)
find_package(low_pass_filter REQUIRED)
find_package(pid_controller REQUIRED)

target_link_libraries(sensor_pipeline PRIVATE
    kalman_filter::kalman_filter
    low_pass_filter::low_pass_filter
    pid_controller::pid_controller
)
```

> "Standard CMake. `find_package`, `target_link_libraries`. Nothing custom."

### main.cpp

> "The consumer app generates a noisy sine wave, runs it through the low-pass filter, feeds it to the Kalman filter for state estimation, then uses the PID controller to track a reference signal."

### Show the output

If the example was built on EC2, show the output table:

```
Step        Raw  Filtered    KF Est       Ref   Control
-----  --------  --------  --------  --------  --------
0        -0.951    -0.951    -0.865     0.000     1.306
1         2.265     0.014    -0.218     1.545     2.238
...
Pipeline complete. All three algorithms consumed via Conan.
```

> "The C++ team gets pre-tested, versioned, equivalence-verified libraries. They integrate them like any other dependency."

---

## Part 5: Failure Scenario (3 minutes)

Run the Python demo with the failure flag:

```bash
python demo/run_demo.py --failure
```

> "Watch what happens when the algorithm has a bug..."

The demo will show:
- Stages 1-5 pass
- **Stage 6 (Equivalence Check) FAILS** — MATLAB and C++ outputs don't match
- Pipeline stops
- Algorithm developer gets notified
- C++ team is **never notified** — they don't even know a build was attempted

**Talking point:**
> "The pipeline has six quality gates. If any gate fails, nothing is published. The C++ team never receives broken code. The feedback goes directly to the algorithm developer who can fix it."

---

## Part 6: Adding a New Algorithm (2 minutes)

> "What does an algorithm developer actually do? Four things:"

1. **Write MATLAB** — `my_algorithm.m` with `%#codegen`
2. **Define test cases** — JSON with inputs, expected outputs, tolerances
3. **Configure codegen** — `codegen_config.m` specifying input types
4. **Push** — `git commit -m "feat(my_algorithm): initial implementation"` then `git push`

> "That's it. The developer never writes C++, never configures CMake, never touches Jenkins. Push and walk away."

**Show:** Open `docs/adding_an_algorithm.md` briefly to show the full guide exists.

---

## FAQ — Anticipated Questions

### From algorithm developers

**"What if MATLAB Coder doesn't support my function?"**
> Check the [MATLAB Coder compatibility list](https://www.mathworks.com/help/coder/ug/functions-and-objects-supported-for-cc-code-generation.html). Common issues: cell arrays, try/catch, string objects, function handles. The codegen config step catches these errors before the pipeline runs.

**"How do I know what tolerances to use?"**
> Start with 1e-10. The equivalence report shows the actual max error between MATLAB and C++. If your algorithm uses iterative solvers or matrix inversions, you may need to loosen to 1e-6 or 1e-8.

**"Can I test locally before pushing?"**
> Yes. Run `bash scripts/run_matlab_tests.sh my_algorithm` locally. If you have MATLAB Coder: `bash scripts/run_codegen.sh my_algorithm`.

**"What happens on feature branches?"**
> Stages 1-8 run (build, test, verify). Stages 9-10 (publish, notify) only run on `main`. So feature branches get full validation without publishing anything.

### From C++ developers

**"How do I know the C++ is correct?"**
> Every release includes an equivalence report showing MATLAB vs C++ outputs for every test case. The max absolute and relative errors are reported. If any test case exceeds tolerance, the package is not published.

**"What if the API changes?"**
> A MAJOR version bump signals an API change. The release notes include an API signature diff showing exactly what changed. MINOR and PATCH versions are backward-compatible.

**"Can I pin to a specific version?"**
> Yes. Use `self.requires("kalman_filter/0.2.1")` for an exact pin, or `"kalman_filter/[>=0.2.0 <1.0.0]"` for a range.

### From leadership

**"What does this cost?"**
> An EC2 t3.large (~$60/month) runs everything. MATLAB licenses are the main cost. Jenkins and Nexus are open source.

**"How long does a pipeline run take?"**
> Under a minute for three algorithms on the current setup. Most time is spent in MATLAB Coder (code generation).

**"What about security?"**
> See [docs/going_to_production.md](going_to_production.md) for hardening Jenkins, Nexus, and credentials. The demo uses default passwords that must be changed for production.

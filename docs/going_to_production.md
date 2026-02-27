# Going to Production: Replacing Demo Components

This guide covers transitioning from the demo environment (mock MATLAB, example algorithms, default credentials) to a production deployment with real MATLAB, real algorithms, and real team integration.

## What's Demo vs What's Real

| Component | Demo State | Production State | Owner |
|-----------|-----------|-----------------|-------|
| MATLAB | Python mock (`deploy/ec2/matlab-mock/`) | Real MATLAB R2024b + Coder license | DevOps |
| Algorithms | `kalman_filter`, `low_pass_filter`, `pid_controller` | Your proprietary algorithms | Algorithm Team |
| Test vectors | Synthetic data with hand-computed expected outputs | Real MATLAB outputs from real algorithms | Algorithm Team |
| Generated C++ | Pre-written C++ embedded in mock | Real MATLAB Coder output | Automatic |
| Jenkins | Docker on EC2, admin/admin | Hardened Jenkins, LDAP/SSO, real creds | DevOps |
| Nexus | Docker on EC2, admin/admin123 | Hardened Nexus, role-based access | DevOps |
| Email | `mail` command (not configured) | SMTP relay (SES, corporate SMTP) | DevOps |
| Git integration | SCM polling every 5 minutes | GitHub webhooks, branch protection | DevOps |
| Consumer apps | `examples/sensor_pipeline/` (demo) | Real C++ applications | C++ Team |

---

## Step 1: Install Real MATLAB

The pipeline auto-detects MATLAB. When it finds `/opt/matlab/R2024b/bin/matlab`, it runs real MATLAB tests and code generation. When MATLAB is absent, those stages are skipped and the mock handles them.

### What to install

- **MATLAB R2024b** (or later)
- **MATLAB Coder** toolbox (required for C++ generation)
- Any toolboxes your algorithms depend on (Signal Processing, Controls, etc.)

### Where to install

MATLAB must be accessible to the Jenkins build agent. Two options:

**Option A: Install on EC2 host, mount into Jenkins container**

```bash
# Download and install MATLAB on the EC2 host
sudo mkdir -p /opt/matlab
# (follow MathWorks installer instructions)
sudo /path/to/installer -mode silent \
    -destinationFolder /opt/matlab/R2024b \
    -agreeToLicense yes

# Verify
/opt/matlab/R2024b/bin/matlab -batch "disp('MATLAB OK'); ver('coder'); exit"
```

The `docker-compose.yml` already mounts `/opt/matlab` into the Jenkins container.

**Option B: Install directly in a custom Jenkins image**

Add MATLAB to the Jenkins Dockerfile in `deploy/ec2/jenkins/Dockerfile`.

### Update configuration

1. Verify `MATLAB_ROOT` in `Jenkinsfile` line 26 points to the correct path:
   ```groovy
   MATLAB_ROOT = '/opt/matlab/R2024b'
   ```

2. Verify the same path in `deploy/ec2/jenkins/casc.yaml` under `nodeProperties`.

3. Restart Jenkins:
   ```bash
   cd MatlabToCpp/deploy/ec2
   docker compose restart jenkins
   ```

### What changes in the pipeline

- **Stage 2 (MATLAB Tests)**: Now runs real `matlab -batch` instead of being skipped
- **Stage 3 (Code Generation)**: Runs real MATLAB Coder instead of mock
- **Stage 6 (Equivalence Check)**: Compares real MATLAB output vs real generated C++ output
- The pipeline scripts (`run_matlab_tests.sh`, `run_codegen.sh`) already handle both modes — no script changes needed

### Remove the mock (optional)

Once real MATLAB is working, you can remove the mock:
```bash
# On the EC2 host
sudo rm /opt/matlab/R2024b/bin/matlab  # the mock wrapper script
# Or: don't run deploy/ec2/matlab-mock/install.sh on future deployments
```

---

## Step 2: Replace Demo Algorithms with Real Ones

### For each real algorithm

Follow [adding_an_algorithm.md](adding_an_algorithm.md) for the full step-by-step. Summary:

1. `cp -r algorithms/kalman_filter algorithms/your_algorithm`
2. Edit `algorithm.yaml` — name, owner email, consumer emails
3. Set `VERSION` to `0.1.0`
4. Replace `matlab/your_algorithm.m` with your real MATLAB function
5. Update `matlab/codegen_config.m` for your function's input types
6. Write `matlab/test_your_algorithm.m` test harness
7. Define `test_vectors/nominal.json` with real test cases
8. Update `cpp/test_your_algorithm.cpp`, `cpp/conanfile.py`, `cpp/CMakeLists.txt`
9. Commit: `git commit -m "feat(your_algorithm): add initial implementation"`

### MATLAB Coder compatibility checklist

Before pushing, verify your MATLAB code is Coder-compatible:

- [ ] `%#codegen` directive in every function
- [ ] No unsupported functions ([check MathWorks list](https://www.mathworks.com/help/coder/ug/functions-and-objects-supported-for-cc-code-generation.html))
- [ ] All input sizes are deterministic (or use `coder.typeof` for variable-size)
- [ ] No function handles passed as arguments
- [ ] No cell arrays in generated code paths
- [ ] No `try/catch` blocks in generated code paths
- [ ] No string objects (use char arrays)
- [ ] No global variables
- [ ] Test locally: `codegen_config('/tmp/test_output')` succeeds

### Removing demo algorithms

The demo algorithms (`kalman_filter`, `low_pass_filter`, `pid_controller`) can be:
- **Deleted** — the pipeline auto-discovers algorithms from `algorithms/*/`
- **Kept as reference** — useful for new developers to see the complete pattern
- **Moved** to a `examples/` or `templates/` directory if you want them out of the build

---

## Step 3: Generate Real Test Vectors

Test vectors are the **contract** between MATLAB and C++. They must come from running your real algorithm in real MATLAB.

### Template: Generate test vectors from MATLAB

Save this as `matlab/generate_vectors.m` in your algorithm directory:

```matlab
function generate_vectors(output_file)
%GENERATE_VECTORS Create JSON test vectors from MATLAB outputs.
%   generate_vectors('test_vectors/nominal.json')

    test_cases = {};

    % --- Test case 1: nominal ---
    inputs1.param_a = [1.0, 2.0, 3.0];
    inputs1.param_b = 0.5;
    [out1_a, out1_b] = your_algorithm(inputs1.param_a, inputs1.param_b);

    tc1.name = 'nominal_case';
    tc1.description = 'Standard operating conditions';
    tc1.inputs = inputs1;
    tc1.expected_output.result_a = out1_a(:)';
    tc1.expected_output.result_b = out1_b;
    tc1.tolerance.absolute = 1e-10;
    test_cases{end+1} = tc1;

    % --- Test case 2: edge case ---
    inputs2.param_a = [0.0, 0.0, 0.0];
    inputs2.param_b = 0.0;
    [out2_a, out2_b] = your_algorithm(inputs2.param_a, inputs2.param_b);

    tc2.name = 'zero_input';
    tc2.description = 'All zeros should produce zero output';
    tc2.inputs = inputs2;
    tc2.expected_output.result_a = out2_a(:)';
    tc2.expected_output.result_b = out2_b;
    test_cases{end+1} = tc2;

    % --- Add more test cases as needed ---

    % Write JSON
    data.algorithm = 'your_algorithm';
    data.version = '1.0';
    data.description = 'Test vectors generated from MATLAB R2024b';
    data.global_tolerance.absolute = 1e-10;
    data.global_tolerance.relative = 1e-8;
    data.test_cases = test_cases;

    fid = fopen(output_file, 'w');
    fprintf(fid, '%s', jsonencode(data));
    fclose(fid);
    fprintf('Wrote %d test cases to %s\n', length(test_cases), output_file);
end
```

Run in MATLAB:
```matlab
cd algorithms/your_algorithm
generate_vectors('test_vectors/nominal.json')
```

### How many test vectors?

| Coverage | Minimum | Recommended |
|----------|---------|-------------|
| Nominal cases | 3-5 | 10+ |
| Edge cases (zeros, max, min) | 2-3 | 5+ |
| Boundary conditions | 1-2 | 3+ |
| Regression tests (known bugs) | as needed | all known |
| **Total** | **~10** | **20+** |

### Choosing tolerances

| Algorithm type | Typical tolerance | Why |
|---------------|------------------|-----|
| Simple arithmetic | 1e-15 | Machine epsilon |
| Matrix operations | 1e-10 to 1e-12 | Accumulation of rounding |
| Iterative solvers | 1e-6 to 1e-8 | Convergence differences |
| Trig / transcendental | 1e-12 to 1e-14 | Library implementation differences |

Start tight (1e-10) and loosen only if the equivalence check fails. The report shows the actual max error so you can tune precisely.

---

## Step 4: Harden Jenkins

### Authentication

Replace the local user database with your organization's identity provider:

```yaml
# In deploy/ec2/jenkins/casc.yaml, replace securityRealm.local with:
securityRealm:
  ldap:
    configurations:
      - server: "ldaps://ldap.yourcompany.com"
        rootDN: "dc=yourcompany,dc=com"
        userSearch: "uid={0}"
```

Or use OpenID Connect for SSO (requires the `oic-auth` Jenkins plugin).

### Authorization

Replace `loggedInUsersCanDoAnything` with role-based access:

```yaml
authorizationStrategy:
  roleBased:
    roles:
      global:
        - name: "admin"
          permissions: ["Overall/Administer"]
          entries:
            - user: "devops-team"
        - name: "developer"
          permissions: ["Job/Read", "Job/Build"]
          entries:
            - user: "algorithm-team"
        - name: "viewer"
          permissions: ["Job/Read"]
          entries:
            - user: "cpp-team"
```

### Credentials

Replace hardcoded credentials in `casc.yaml`:

1. Set environment variables on the EC2 host (or use a secrets manager):
   ```bash
   export NEXUS_ADMIN_PASSWORD="<strong-password>"
   export GITHUB_TOKEN="<github-pat>"
   ```

2. The `casc.yaml` already references these via `${NEXUS_ADMIN_PASSWORD:-admin123}` — just set the env vars to override defaults.

### Build agents

For heavier workloads, add dedicated Jenkins agents instead of running on the built-in node:
- Docker-based agents (ephemeral, clean environment)
- Permanent agents with MATLAB pre-installed
- Configure in `casc.yaml` under `nodes`

---

## Step 5: Harden Nexus

### Change default credentials

```bash
# Via Nexus REST API
curl -X PUT "http://localhost:8081/service/rest/v1/security/users/admin/change-password" \
    -u "admin:admin123" \
    -H "Content-Type: text/plain" \
    -d "your-strong-password"
```

### Disable anonymous access

```bash
curl -X PUT "http://localhost:8081/service/rest/v1/security/anonymous" \
    -u "admin:your-strong-password" \
    -H "Content-Type: application/json" \
    -d '{"enabled": false}'
```

### Create service accounts

Create separate accounts for Jenkins (publish) and developers (read):

1. Navigate to Nexus admin > Security > Users
2. Create `jenkins-publisher` with `nx-repository-admin-conan-hosted-*` privilege
3. Create `dev-reader` with `nx-repository-view-conan-hosted-read` privilege
4. Update Jenkins credentials to use `jenkins-publisher`
5. Distribute `dev-reader` credentials to C++ team

### Storage durability

For production, consider S3-backed blob storage:
1. Nexus admin > Repository > Blob Stores
2. Create an S3 blob store pointing to your S3 bucket
3. Update the `conan-hosted` repository to use the S3 blob store

---

## Step 6: Configure Email Notifications

The `scripts/notify.sh` script uses the `mail` command. For production:

### Option A: Install mailx on the Jenkins agent

```bash
# In the Jenkins Dockerfile or on the host
sudo dnf install -y mailx

# Configure SMTP relay
echo 'set smtp=smtp://smtp.yourcompany.com:587' >> /etc/mail.rc
echo 'set smtp-auth=login' >> /etc/mail.rc
echo 'set smtp-auth-user=noreply@yourcompany.com' >> /etc/mail.rc
echo 'set smtp-auth-password=<password>' >> /etc/mail.rc
```

### Option B: Amazon SES (if on AWS)

1. Create SES identity and verify your domain
2. Create SMTP credentials in SES console
3. Configure mailx with SES SMTP endpoint:
   ```
   set smtp=smtps://email-smtp.us-east-1.amazonaws.com:465
   set smtp-auth-user=<SES_SMTP_USER>
   set smtp-auth-password=<SES_SMTP_PASSWORD>
   ```

### Update notification recipients

Edit each algorithm's `algorithm.yaml`:
```yaml
owner: real-algo-developer@yourcompany.com
consumers:
  - cpp-team-lead@yourcompany.com
  - cpp-integration@yourcompany.com
```

---

## Step 7: Configure GitHub Integration

### Replace SCM polling with webhooks

1. In GitHub: Settings > Webhooks > Add webhook
   - URL: `http://<JENKINS_URL>/github-webhook/`
   - Content type: `application/json`
   - Secret: (set a shared secret)
   - Events: "Just the push event"

2. In `deploy/ec2/jenkins/seed-job.groovy`, replace:
   ```groovy
   triggers { pollSCM('H/5 * * * *') }
   ```
   with:
   ```groovy
   triggers { githubPush() }
   ```

### Branch protection (recommended)

In GitHub repository settings:
- Require pull request reviews before merging to `main`
- Require the Jenkins status check to pass
- Require linear history (optional, cleaner commit messages)

### Multibranch pipeline (optional upgrade)

For PR-based workflows, switch from the current `pipelineJob` to a Multibranch Pipeline:
- Each feature branch gets stages 1-8 (build + test, no publish)
- Merges to `main` trigger stages 1-10 (full pipeline including publish)
- PRs show inline pipeline status
- Requires updating `seed-job.groovy` to `multibranchPipelineJob`

---

## Step 8: Real Consumer Integration

### C++ team onboarding

1. Share [docs/consuming_packages.md](consuming_packages.md) with the C++ team
2. Provide Nexus URL and read-only credentials
3. Walk through `examples/sensor_pipeline/` as a starter template

### Consumer CI integration

C++ teams should add Nexus as a Conan remote in their own CI:
```bash
conan remote add nexus http://<NEXUS_URL>/repository/conan-hosted/
conan remote login nexus dev-reader -p <password>
conan install . --build=missing
```

### Conan lock files (recommended)

For reproducible builds, use Conan lock files:
```bash
# Generate lock file
conan lock create conanfile.py --remote=nexus

# Install from lock file (reproducible)
conan install . --lockfile=conan.lock
```

Commit `conan.lock` to the consumer repo. Update it intentionally when upgrading algorithm versions.

---

## Production Readiness Checklist

### MATLAB & Algorithms
- [ ] MATLAB R2024b + Coder installed and licensed
- [ ] At least one real algorithm added to `algorithms/`
- [ ] All MATLAB functions have `%#codegen` directive
- [ ] `codegen_config.m` tested locally: `codegen_config('/tmp/test')`
- [ ] Test vectors generated from real MATLAB outputs
- [ ] All 10 pipeline stages pass for every algorithm

### Infrastructure
- [ ] Jenkins credentials changed from admin/admin
- [ ] Nexus credentials changed from admin/admin123
- [ ] Anonymous Nexus access disabled
- [ ] Conan Bearer Token Realm enabled in Nexus (required for Conan 2)
- [ ] EC2 security group restricted to team IP ranges
- [ ] HTTPS configured (or accessed via VPN only)

### Integration
- [ ] Email notifications working (trigger a test build)
- [ ] GitHub webhook configured (push triggers build)
- [ ] `algorithm.yaml` owner/consumer emails set to real addresses
- [ ] C++ team can `conan install` from Nexus
- [ ] Backup strategy for Jenkins home and Nexus data

### Documentation
- [ ] Team has read [adding_an_algorithm.md](adding_an_algorithm.md)
- [ ] C++ team has read [consuming_packages.md](consuming_packages.md)
- [ ] Demo walkthrough completed with stakeholders

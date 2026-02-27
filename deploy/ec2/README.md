# EC2 Demo Deployment

Deploy the full MatlabToCpp pipeline on an AWS EC2 instance with Jenkins, Nexus, and optionally MATLAB.

## Architecture

```
EC2 Instance (Ubuntu 24.04)
+------------------------------------------+
|  Docker Compose                          |
|  +----------------+  +----------------+ |
|  | Jenkins :8080  |  | Nexus   :8081  | |
|  | (CI/CD)        |  | (Conan pkgs)   | |
|  +----------------+  +----------------+ |
|                                          |
|  Native on host                          |
|  - MATLAB R2024b (optional, /opt/matlab) |
|  - CMake, GCC, Conan 2, Python 3        |
+------------------------------------------+
```

## Quick Start

### 1. Launch EC2 Instance

| Setting | Value |
|---------|-------|
| AMI | Ubuntu 24.04 LTS |
| Instance type | m5.2xlarge (8 vCPU, 32 GB) or t3.xlarge (4 vCPU, 16 GB) for budget |
| Storage | 50 GB gp3 |
| Key pair | Your existing key pair |

**Security group inbound rules:**

| Port | Source | Purpose |
|------|--------|---------|
| 22 | Your IP | SSH |
| 8080 | Your IP | Jenkins |
| 8081 | Your IP | Nexus |

### 2. SSH In

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

### 3. Clone and Deploy

```bash
git clone https://github.com/blake-perkins/MatlabToCpp.git
cd MatlabToCpp
bash deploy/ec2/setup.sh
```

This takes ~5 minutes and will:
- Install Docker, CMake, GCC, Python, Conan
- Build a custom Jenkins image with plugins pre-baked
- Start Jenkins (port 8080) and Nexus (port 8081)
- Auto-configure Jenkins with the pipeline job
- Create a Conan repository in Nexus

### 4. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Jenkins | `http://<EC2_IP>:8080` | admin / admin |
| Nexus | `http://<EC2_IP>:8081` | admin / admin123 |

### 5. Run the Pipeline

1. Open Jenkins at `http://<EC2_IP>:8080`
2. Click **MatlabToCpp** job
3. Click **Build with Parameters**
4. Check **FORCE_ALL** and click **Build**
5. Watch the 10 stages execute

### 6. Verify in Nexus

After a successful pipeline run:
1. Open Nexus at `http://<EC2_IP>:8081`
2. Browse **conan-hosted** repository
3. You should see `kalman_filter/0.2.0`

## MATLAB Installation (Optional)

The pipeline works in two modes:
- **With MATLAB**: Full pipeline (codegen + MATLAB tests + C++ tests + equivalence)
- **Without MATLAB**: Pipeline skips MATLAB stages; use `python3 demo/run_demo.py` for the full simulation

### Installing MATLAB on EC2

1. Download the MATLAB installer from [mathworks.com](https://www.mathworks.com/downloads/)
   - You need: MATLAB + MATLAB Coder
   - A trial license works for demo purposes

2. Upload to EC2:
   ```bash
   scp -i your-key.pem matlab_installer.zip ubuntu@<EC2_IP>:~/
   ```

3. Install:
   ```bash
   unzip matlab_installer.zip -d ~/matlab_installer
   sudo ~/matlab_installer/install -mode silent \
       -destinationFolder /opt/matlab/R2024b \
       -agreeToLicense yes
   ```

4. Verify:
   ```bash
   /opt/matlab/R2024b/bin/matlab -batch "disp('MATLAB works'); exit"
   ```

5. Restart Jenkins to pick up MATLAB:
   ```bash
   cd MatlabToCpp/deploy/ec2
   docker compose restart jenkins
   ```

## Running on an Existing EC2 Instance

If you already have an EC2 instance running (e.g., for a web app), you can add Jenkins + Nexus alongside it:

1. Ensure ports 8080 and 8081 are open in the security group
2. Ensure at least 8 GB free RAM (16 GB+ recommended)
3. Clone the repo and run setup:
   ```bash
   git clone https://github.com/blake-perkins/MatlabToCpp.git
   cd MatlabToCpp
   bash deploy/ec2/setup.sh
   ```

The setup script is additive — it won't interfere with existing services.

## Cost

| Component | Monthly (on-demand) | Monthly (spot) |
|-----------|-------------------|---------------|
| m5.2xlarge | ~$280 | ~$85 |
| 50 GB gp3 | ~$4 | ~$4 |
| **Total** | **~$284** | **~$89** |

Tip: Stop the instance when not demoing to save costs.

## Troubleshooting

### Jenkins shows "Please wait while Jenkins is getting ready"
Wait 2-3 minutes on first boot. Check: `docker logs -f matlab-jenkins`

### Nexus is slow to start
Nexus needs 1-2 minutes to initialize. Check: `docker logs -f matlab-nexus`

### Pipeline fails at MATLAB stages
If MATLAB is not installed, pipeline stages that call `matlab -batch` will fail.
This is expected — the quality gate pattern means the pipeline correctly stops.

### Docker permission denied
Log out and back in, or run: `newgrp docker`

### Port conflicts
If 8080 or 8081 are in use, edit `deploy/ec2/docker-compose.yml` to change port mappings.

## Cleanup

```bash
# Stop and remove containers
cd MatlabToCpp/deploy/ec2
docker compose down

# Remove all data (Jenkins jobs, Nexus artifacts)
docker compose down -v

# Remove Docker images
docker rmi matlab-jenkins nexus3
```

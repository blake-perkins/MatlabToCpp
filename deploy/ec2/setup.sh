#!/bin/bash
# setup.sh — One-script deployment for MatlabToCpp demo environment.
#
# Run this on a fresh Amazon Linux 2023 or RHEL 9 EC2 instance:
#   git clone https://github.com/blake-perkins/MatlabToCpp.git
#   cd MatlabToCpp
#   bash deploy/ec2/setup.sh
#
# What it does:
#   1. Installs Docker + Docker Compose
#   2. Installs build tools (CMake, GCC, Python, Conan, Xvfb)
#   3. Optionally installs MATLAB (if installer path provided)
#   4. Builds and starts Jenkins + Nexus via Docker Compose
#   5. Configures Nexus with a Conan repository
#   6. Prints access URLs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "============================================================"
echo "  MatlabToCpp Demo Environment Setup"
echo "============================================================"
echo ""
echo "  Repo: $REPO_ROOT"
echo "  Deploy dir: $SCRIPT_DIR"
echo ""

# ---- Helpers ----

log_info()  { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
log_warn()  { echo "[WARN]  $(date '+%H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }

# ---- Step 1: Docker ----

log_info "Step 1/6: Installing Docker..."

if command -v docker &>/dev/null; then
    log_info "Docker already installed: $(docker --version)"
else
    # Install Docker from Amazon Linux repos
    sudo dnf install -y docker

    # Install Docker Compose plugin
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker

    # Allow current user to run docker without sudo
    sudo usermod -aG docker "$USER"
    log_info "Docker installed. You may need to log out and back in for group changes."
fi

# ---- Step 2: Build tools ----

log_info "Step 2/6: Installing build tools..."

sudo dnf install -y \
    cmake \
    gcc-c++ \
    make \
    python3 \
    python3-pip \
    xorg-x11-server-Xvfb \
    jq \
    git \
    curl

# Conan 2
if command -v conan &>/dev/null; then
    log_info "Conan already installed: $(conan --version)"
else
    pip3 install conan jsonschema
    log_info "Conan installed: $(conan --version 2>/dev/null || echo 'installed')"
fi

# ---- Step 3: MATLAB (optional) ----

log_info "Step 3/6: MATLAB setup..."

if [ -d "/opt/matlab" ]; then
    log_info "MATLAB found at /opt/matlab"
    MATLAB_VERSION=$(ls /opt/matlab/ | head -1)
    log_info "Version: $MATLAB_VERSION"
elif [ -n "${MATLAB_INSTALLER:-}" ] && [ -f "$MATLAB_INSTALLER" ]; then
    log_info "Installing MATLAB from: $MATLAB_INSTALLER"
    log_info "This may take 15-30 minutes..."

    sudo mkdir -p /opt/matlab
    sudo "$MATLAB_INSTALLER" \
        -mode silent \
        -destinationFolder /opt/matlab/R2024b \
        -agreeToLicense yes \
        || log_warn "MATLAB installation failed. You can install manually later."
else
    log_warn "MATLAB not found and no installer provided."
    log_warn "To install MATLAB later:"
    log_warn "  1. Download installer from mathworks.com"
    log_warn "  2. Run: MATLAB_INSTALLER=/path/to/installer bash deploy/ec2/setup.sh"
    log_warn "  Or install manually to /opt/matlab/R2024b"
    log_warn ""
    log_warn "The demo will work without MATLAB (using the Python simulation)."
    log_warn "Jenkins pipeline stages that need MATLAB will be skipped."
fi

# Create /opt/matlab directory if it doesn't exist (so Docker volume mount works)
sudo mkdir -p /opt/matlab

# ---- Step 4: Build and start containers ----

log_info "Step 4/6: Building and starting Jenkins + Nexus..."

cd "$SCRIPT_DIR"

# Build Jenkins image with plugins pre-installed
docker compose build jenkins 2>&1 | tail -5

# Start services
docker compose up -d

log_info "Containers starting... (Jenkins takes 2-3 minutes on first boot)"

# ---- Step 5: Wait for services ----

log_info "Step 5/6: Waiting for services to be healthy..."

# Wait for Nexus
echo -n "  Nexus: "
for i in $(seq 1 60); do
    if curl -sf http://localhost:8081/service/rest/v1/status > /dev/null 2>&1; then
        echo "ready"
        break
    fi
    echo -n "."
    sleep 5
done

# Wait for Jenkins
echo -n "  Jenkins: "
for i in $(seq 1 60); do
    if curl -sf http://localhost:8080/login > /dev/null 2>&1; then
        echo "ready"
        break
    fi
    echo -n "."
    sleep 5
done

# ---- Step 6: Configure Nexus ----

log_info "Step 6/6: Configuring Nexus Conan repository..."

bash "$SCRIPT_DIR/nexus/configure-conan.sh" "http://localhost:8081"

# ---- Done ----

EC2_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

echo ""
echo "============================================================"
echo "  Setup Complete!"
echo "============================================================"
echo ""
echo "  Jenkins:  http://${EC2_IP}:8080"
echo "  Nexus:    http://${EC2_IP}:8081"
echo ""
echo "  Jenkins credentials:  admin / admin"
echo "  Nexus credentials:    admin / admin123"
echo ""
echo "  Pipeline job: http://${EC2_IP}:8080/job/MatlabToCpp/"
echo ""
if [ -d "/opt/matlab/R2024b" ]; then
    echo "  MATLAB: /opt/matlab/R2024b (available to Jenkins)"
else
    echo "  MATLAB: Not installed (pipeline will use demo mode)"
fi
echo ""
echo "  Next steps:"
echo "    1. Open Jenkins in your browser"
echo "    2. Navigate to the MatlabToCpp job"
echo "    3. Click 'Build with Parameters' -> 'Build'"
echo "    4. Watch the pipeline execute all 10 stages"
echo "    5. Check Nexus for the published Conan package"
echo ""
echo "  To run the Python demo locally:"
echo "    python3 demo/run_demo.py"
echo ""
echo "============================================================"

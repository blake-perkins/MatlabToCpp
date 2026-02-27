#!/bin/bash
# install.sh — Install mock MATLAB binary for demo pipeline.
#
# Creates /opt/matlab/R2024b/bin/matlab as a mock that delegates
# to a Python script, allowing the Jenkins pipeline to run all
# 10 stages without a real MATLAB license.
#
# Usage: bash deploy/ec2/matlab-mock/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing mock MATLAB at /opt/matlab/R2024b ..."

sudo mkdir -p /opt/matlab/R2024b/bin
sudo mkdir -p /opt/matlab/R2024b/mock

sudo cp "$SCRIPT_DIR/bin/matlab" /opt/matlab/R2024b/bin/matlab
sudo cp "$SCRIPT_DIR/mock/mock_matlab.py" /opt/matlab/R2024b/mock/mock_matlab.py

sudo chmod +x /opt/matlab/R2024b/bin/matlab
sudo chmod +x /opt/matlab/R2024b/mock/mock_matlab.py

echo "Mock MATLAB installed. Verifying..."
/opt/matlab/R2024b/bin/matlab -batch "disp('Mock MATLAB is working')"
echo "Done."

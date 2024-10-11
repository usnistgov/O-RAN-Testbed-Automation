#!/bin/bash
echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

# Check if k9s is already installed
if command -v k9s &>/dev/null; then
    echo "Already installed k9s, skipping."
    exit 0
fi

echo "Downloading and extracting k9s..."

# Create and navigate to the installation directory
mkdir -p ~/k9s-installation
cd ~/k9s-installation

# Download and extract K9s
curl -LO https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar xf k9s_Linux_amd64.tar.gz

# Move the binary to a system path
sudo mv k9s /usr/local/bin

# Cleanup the downloaded archive
rm k9s_Linux_amd64.tar.gz

echo "K9s installation complete."


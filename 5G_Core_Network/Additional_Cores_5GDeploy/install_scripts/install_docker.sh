#!/bin/bash
#
# NIST-developed software is provided by NIST as a public service. You may use,
# copy, and distribute copies of the software in any medium, provided that you
# keep intact this entire notice. You may improve, modify, and create derivative
# works of the software or any portion of the software, and you may copy and
# distribute such modifications or works. Modified works should carry a notice
# stating that you changed the software and should note the date and nature of
# any such change. Please explicitly acknowledge the National Institute of
# Standards and Technology as the source of the software.
#
# NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
# OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
# NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
# UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
# NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
# THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
# RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
#
# You are solely responsible for determining the appropriateness of using and
# distributing the software and you assume all risks associated with its use,
# including but not limited to the risks and costs of program errors, compliance
# with applicable laws, damage to or loss of data, programs or equipment, and
# the unavailability or interruption of operation. This software is not intended
# to be used in any situation where a failure could cause risk of injury or
# damage to property. The software developed by NIST employees is not subject to
# copyright protection within the United States.

# Exit immediately if a command fails
set -e

# Echo every command as it is ran
set -x

SCRIPT_DIR=$(dirname "$(realpath "$0")")
BASE_DIR=$(realpath "$SCRIPT_DIR/../..")
cd "$SCRIPT_DIR"

get_latest_package_version() {
    PACKAGE_NAME=$1
    VERSION_PREFIX=$2
    # Fetch the version including the patch number (e.g., 20.10.21-0ubuntu4)
    LATEST_VERSION=$(apt-cache madison $PACKAGE_NAME | grep "$VERSION_PREFIX" | head -1 | awk '{print $3}')
    echo $LATEST_VERSION
}

remove_version_suffix() {
    FULL_VERSION=$1
    # Strip off the suffix after the dash, e.g., 1.28.14-2.1 --> 1.28.14
    VERSION_WITHOUT_SUFFIX=$(echo $FULL_VERSION | cut -d'-' -f1)
    echo $VERSION_WITHOUT_SUFFIX
}

# Fetch the Ubuntu release version regardless of the derivative distro
if [ -f /etc/upstream-release/lsb-release ]; then
    UBUNTU_RELEASE=$(cat /etc/upstream-release/lsb-release | grep 'DISTRIB_RELEASE' | sed 's/.*=\s*//')
else
    UBUNTU_RELEASE=$(lsb_release -sr)
fi

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"

USE_DOCKER_CE=1
if [ "$USE_DOCKER_CE" -eq 0 ]; then # Use docker.io
    DOCKERV="20.10"
    # Select a compatible Docker version for Ubuntu 24.*
    if [[ ${UBUNTU_RELEASE} == 24.* ]]; then
        DOCKERV="27.5"
    fi

else # Use docker.ce
    DOCKERV="28.1"
    UBUNTU_CODENAME=$(grep -oP '^UBUNTU_CODENAME=\K.*' /etc/os-release 2>/dev/null)
    # If not found, try to extract VERSION_CODENAME as a fallback
    if [[ -z "$UBUNTU_CODENAME" ]]; then
        UBUNTU_CODENAME=$(grep -oP '^VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null)
    fi
    # Check if UBUNTU_CODENAME is still empty
    if [[ -z "$UBUNTU_CODENAME" ]]; then
        echo "Error: Ubuntu codename not found in /etc/os-release."
        exit 1
    fi

    # Code from (https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository):
    sudo apt-get update
    sudo env $APTVARS apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # Add the repository to Apt sources:
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME}") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
fi

APTOPTS="--allow-downgrades --allow-change-held-packages --allow-unauthenticated --ignore-hold "

# Dynamically fetch the latest versions based on the available packages
if [ "$USE_DOCKER_CE" -eq 0 ]; then
    DOCKERVERSION=$(get_latest_package_version "docker.io" "${DOCKERV}")
else
    DOCKERVERSION=$(get_latest_package_version "docker-ce" "${DOCKERV}")
fi

if [ -z "${DOCKERVERSION}" ]; then
    echo "No Docker version found, exiting..."
    exit 1
fi

DOCKERVERSIONWITHOUTSUFFIX=$(remove_version_suffix "${DOCKERVERSION}")

echo
echo
echo "Docker version: ${DOCKERVERSION}"
echo "Docker version without suffix: ${DOCKERVERSIONWITHOUTSUFFIX}"
echo
echo

# Install Docker with the specified or latest available version
echo "Installing Docker..."
if ! command -v docker &>/dev/null; then
    if [ "$USE_DOCKER_CE" -eq 0 ]; then
        sudo env $APTVARS apt-get install -y $APTOPTS "docker.io=$DOCKERVERSION"
    else
        sudo env $APTVARS apt-get install -y $APTOPTS "docker-ce=$DOCKERVERSION"
    fi
fi

# Configure Docker daemon
echo "Configuring Docker daemon..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "features": {
    "buildkit": true
  },
  "max-concurrent-downloads": 10
}
EOF

# Validate Docker configuration (skip validation if dockerd does not support it)
if dockerd --help | grep --quiet -- "--validate"; then
    if ! dockerd --config-file=/etc/docker/daemon.json --validate; then
        echo "Invalid Docker configuration detected."
        exit 1
    else
        echo "Docker configuration is valid."
    fi
else
    echo "Skipping Docker configuration validation (unsupported flag)."
fi

echo "Ensure Docker group exists and add user to the group before starting Docker service..."
sudo groupadd -f docker
if [ -n "$SUDO_USER" ]; then
    sudo usermod -aG docker "${SUDO_USER:-root}"
else
    sudo usermod -aG docker "${USER:-root}"
fi

# Enable and attempt to start Docker service with retries
echo "Enabling and starting Docker service..."
sudo systemctl daemon-reload
sudo systemctl enable docker
ATTEMPT=0
MAX_ATTEMPTS=5
while ! sudo systemctl restart docker && [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Docker failed to start. Attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS..."
    echo "Checking service status..."
    sudo systemctl status docker.service | grep -A 2 "Active:"
    echo "Reviewing recent logs..."
    journalctl -xeu docker.service | tail -20
    sleep 10
    ((ATTEMPT++))
done

if ! sudo systemctl is-active --quiet docker; then
    echo "Failed to start Docker after $MAX_ATTEMPTS attempts."
    exit 1
else
    echo "Docker started successfully."
fi

echo "Setting Docker DNS servers..."
cd "$SCRIPT_DIR"
sudo ./update_docker_dns.sh

echo "Successfully installed Docker $DOCKERVERSION"

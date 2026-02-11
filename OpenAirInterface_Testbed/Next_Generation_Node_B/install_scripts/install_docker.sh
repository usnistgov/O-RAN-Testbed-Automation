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

# Detect if systemctl is available
USE_SYSTEMCTL=false
if command -v systemctl >/dev/null 2>&1; then
    if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        OUTPUT="$(systemctl 2>&1 || true)"
        if echo "$OUTPUT" | grep -qiE 'not supported|System has not been booted with systemd'; then
            echo "Detected systemctl is not supported. Using background processes instead."
        elif systemctl list-units >/dev/null 2>&1 || systemctl is-system-running --quiet >/dev/null 2>&1; then
            USE_SYSTEMCTL=true
        fi
    fi
fi

# Fetch the Ubuntu release version regardless of the derivative distro
if [ -f /etc/upstream-release/lsb-release ]; then
    UBUNTU_RELEASE=$(cat /etc/upstream-release/lsb-release | grep 'DISTRIB_RELEASE' | sed 's/.*=\s*//')
else
    UBUNTU_RELEASE=$(lsb_release -sr)
fi

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    sudo env $APTVARS apt-get install -y jq
fi

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
        echo "ERROR: Ubuntu codename not found in /etc/os-release."
        exit 1
    fi

    # Code from (https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository):
    sudo apt-get update
    sudo env $APTVARS apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # Add the repository to apt sources:
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
if ! command -v dockerd >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
    if [ "$USE_DOCKER_CE" -eq 0 ]; then
        sudo env $APTVARS apt-get install -y $APTOPTS "docker.io=$DOCKERVERSION"
    else
        sudo env $APTVARS apt-get install -y $APTOPTS "docker-ce=$DOCKERVERSION"
    fi
fi

# Configure Docker daemon
echo "Configuring Docker daemon..."
sudo mkdir -p /etc/docker

# Set DNS servers for Docker daemon
DNS_SERVERS=$(grep 'nameserver' /run/systemd/resolve/resolv.conf 2>/dev/null | awk '{print $2}' | jq -R . | jq -s . 2>/dev/null || echo '[]')
if [ -z "$(echo "$DNS_SERVERS" | jq '. | select(length > 0)')" ]; then
    echo "Could not find DNS servers in /run/systemd/resolve/resolv.conf, trying /etc/resolv.conf..."
    DNS_SERVERS=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | jq -R . | jq -s . 2>/dev/null || echo '[]')
fi
if [ -z "$(echo "$DNS_SERVERS" | jq '. | select(length > 0)')" ]; then
    echo "Could not find DNS servers in system resolv.conf files, defaulting to Google DNS..."
    DNS_SERVERS='["8.8.8.8", "8.8.4.4"]'
fi
echo "Using DNS servers: $DNS_SERVERS"

# Select storage driver (see https://docs.docker.com/engine/storage/drivers/select-storage-driver)
if [ "$USE_SYSTEMCTL" = true ]; then
    DRIVER="overlay2"
else
    DRIVER="vfs"
fi
if [ "$DRIVER" = "overlay2" ] && ! grep -qw overlay /proc/filesystems; then
    if ! sudo modprobe overlay >/dev/null 2>&1; then
        DRIVER="vfs"
    fi
fi
if [ "$DRIVER" = "overlay2" ]; then
    if ! sudo mkdir -p /var/lib/docker/test-overlay/upper /var/lib/docker/test-overlay/work /var/lib/docker/test-overlay/merged; then
        DRIVER="vfs"
    elif ! sudo mount -t overlay overlay -o lowerdir=/bin,upperdir=/var/lib/docker/test-overlay/upper,workdir=/var/lib/docker/test-overlay/work /var/lib/docker/test-overlay/merged 2>/dev/null; then
        DRIVER="vfs"
    else
        sudo umount /var/lib/docker/test-overlay/merged 2>/dev/null || true
    fi
    sudo rm -rf /var/lib/docker/test-overlay 2>/dev/null || true
fi

# Determine the cgroup driver
CGROUP_DRIVER="systemd"
if [ "$USE_SYSTEMCTL" != true ]; then
    CGROUP_DRIVER="cgroupfs"
fi
# Support overriding the cgroup driver from environment variable
if [ -n "${DOCKER_CGROUP_DRIVER:-}" ]; then
    CGROUP_DRIVER="${DOCKER_CGROUP_DRIVER}"
fi
sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
    "exec-opts": ["native.cgroupdriver=${CGROUP_DRIVER}"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "${DRIVER}",
    "features": {
        "buildkit": true
    },
    "max-concurrent-downloads": 10,
    "dns": ${DNS_SERVERS}
}
EOF

# Validate Docker configuration (skip validation if dockerd does not support it)
if dockerd --help | grep --quiet -- "--validate"; then
    if ! sudo dockerd --config-file=/etc/docker/daemon.json --validate; then
        echo "Invalid Docker configuration detected."
        exit 1
    else
        echo "Docker configuration is valid."
    fi
else
    echo "Skipping Docker configuration validation (unsupported flag)."
fi

echo "Ensuring Docker group exists and add user to the group before starting Docker service..."
sudo groupadd -f docker
if [ -n "$SUDO_USER" ]; then
    sudo usermod -aG docker "${SUDO_USER:-root}"
else
    sudo usermod -aG docker "${USER:-root}"
fi

# Enable and attempt to start Docker service with retries
echo "Enabling and starting Docker service..."
if [ "$USE_SYSTEMCTL" = true ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable docker
    ATTEMPT=0
    MAX_ATTEMPTS=5
    while ! sudo systemctl restart docker && [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        echo "Docker failed to start. Attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS..."
        echo "Checking service status..."
        sudo systemctl status docker.service | grep -A 2 "Active:" || true
        echo "Reviewing recent logs..."
        journalctl -xeu docker.service | tail -20 || true
        sleep 10
        ((ATTEMPT++))
    done

    if ! sudo systemctl is-active --quiet docker; then
        echo "Failed to start Docker after $MAX_ATTEMPTS attempts."
        exit 1
    else
        echo "Docker started successfully."
    fi
else
    echo "Starting Docker process..."
    if ! command -v dockerd >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
        echo "ERROR: Docker binaries not found in PATH."
        exit 1
    fi
    DOCKERD_LOG="/tmp/dockerd.log"
    # Stop running dockerd and containerd in background
    sudo pkill -x dockerd >/dev/null 2>&1 || true
    sudo pkill -x containerd >/dev/null 2>&1 || true
    sudo rm -f /var/run/docker.pid /var/run/docker.sock
    sudo mkdir -p /run /var/run
    sudo sh -c 'setsid dockerd --config-file=/etc/docker/daemon.json >>'"${DOCKERD_LOG}"' 2>&1 </dev/null &'
    # Wait for Docker to be ready
    for ATTEMPT in $(seq 1 60); do
        if sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    if ! (sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1); then
        echo "Docker failed to start with configured options. Retrying with cgroupfs driver..."
        sudo pkill -x dockerd >/dev/null 2>&1 || true
        # Update daemon.json temporarily
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
        sudo sed -i 's/"native.cgroupdriver=systemd"/"native.cgroupdriver=cgroupfs"/' /etc/docker/daemon.json || true
        # If the above sed did not find the line, add it
        if ! grep -q 'native.cgroupdriver' /etc/docker/daemon.json; then
            sudo jq '. + {"exec-opts": ["native.cgroupdriver=cgroupfs"]}' /etc/docker/daemon.json.bak | sudo tee /etc/docker/daemon.json >/dev/null
        fi
        sudo sh -c 'setsid dockerd --config-file=/etc/docker/daemon.json >>'"${DOCKERD_LOG}"' 2>&1 </dev/null &'
        for ATTEMPT in $(seq 1 60); do
            if sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        if ! (sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1); then
            # Restore the original daemon.json
            sudo mv /etc/docker/daemon.json.bak /etc/docker/daemon.json 2>/dev/null || true
            echo "ERROR: Docker daemon failed to start without systemd."
            tail -n 200 "${DOCKERD_LOG}" 2>/dev/null || true
            exit 1
        fi
    fi
    echo "Docker started successfully."
fi

echo "Successfully installed Docker $DOCKERVERSION"

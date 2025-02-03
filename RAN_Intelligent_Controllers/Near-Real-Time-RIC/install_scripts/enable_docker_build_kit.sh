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

echo "# Script: $(realpath $0)..."

CONFIG_FILE="/etc/docker/daemon.json"
TEMP_FILE="/tmp/daemon.json.tmp"

# Check if jq is installed; if not, install it
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update
    sudo apt-get install -y jq
fi

echo "Enabling Docker build kit..."

if ! grep -q "^DOCKER_BUILDKIT=1$" $HOME/.bashrc; then
    echo "Adding DOCKER_BUILDKIT=1 to .bashrc..."
    echo "export DOCKER_BUILDKIT=1" | sudo tee -a $HOME/.bashrc >/dev/null
fi
if ! grep -q "^export DOCKER_CLI_EXPERIMENTAL=enabled$" $HOME/.bashrc; then
    echo "Adding DOCKER_CLI_EXPERIMENTAL=enabled to .bashrc..."
    echo "export DOCKER_CLI_EXPERIMENTAL=enabled" | sudo tee -a $HOME/.bashrc >/dev/null
fi
source $HOME/.bashrc

# Check if Docker Buildx is installed by checking for the executable
BUILDX_PATH="$HOME/.docker/cli-plugins/docker-buildx"
if [ ! -f "$BUILDX_PATH" ]; then
    # Determine the processor architecture
    ARCH_SUFFIX=""
    case $(uname -m) in
    "x86_64")
        ARCH_SUFFIX="linux-amd64"
        ;;
    "aarch64")
        ARCH_SUFFIX="linux-arm64"
        ;;
    "armv7l")
        ARCH_SUFFIX="linux-arm-v7"
        ;;
    "armv6l")
        ARCH_SUFFIX="linux-arm-v6"
        ;;
    "ppc64le")
        ARCH_SUFFIX="linux-ppc64le"
        ;;
    "riscv64")
        ARCH_SUFFIX="linux-riscv64"
        ;;
    "s390x")
        ARCH_SUFFIX="linux-s390x"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)"
        ;;
    esac

    if [ -n "$ARCH_SUFFIX" ]; then
        echo "Docker Buildx not found, installing..."
        mkdir -p $HOME/.docker/cli-plugins
        # Fetch the latest version URL root and construct the full download URL
        BUILDX_BINARY_URL=$(curl -sL -o /dev/null -w %{url_effective} "https://github.com/docker/buildx/releases/latest/download")
        BUILDX_BINARY_URL="${BUILDX_BINARY_URL}/buildx-$(echo $BUILDX_BINARY_URL | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*').$ARCH_SUFFIX"
        HTTP_STATUS=$(curl -L -w "%{http_code}" -o "$BUILDX_PATH" "$BUILDX_BINARY_URL")
        if [ "$HTTP_STATUS" -eq 200 ]; then
            sudo chmod +x "$BUILDX_PATH"
            echo "Docker Buildx installed successfully."
        else
            echo "Failed to download Docker Buildx, HTTP status was $HTTP_STATUS. Skipping."
            rm -f "$BUILDX_PATH"
        fi
    fi
fi

# Check if the daemon.json file exists
if [ -f "$CONFIG_FILE" ]; then
    # The file exists, check for the necessary configurations
    if ! jq 'select(.features.buildkit == true) and select(.["max-concurrent-downloads"] == 10)' "$CONFIG_FILE" >/dev/null; then
        # Ensure the "features" object exists and set "buildkit"
        jq '.features |= (. // {}) | .features.buildkit |= true' "$CONFIG_FILE" >"$TEMP_FILE"
        jq '."max-concurrent-downloads" |= 10' "$TEMP_FILE" >"$CONFIG_FILE"
        rm "$TEMP_FILE"
        echo "Restarting Docker..."
        sudo systemctl restart docker
    else
        echo "All Docker configurations are already set correctly."
    fi
else
    # The file doesn't exist, create it with the required configuration
    echo "Creating new Docker configuration file..."
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

    echo "Restarting Docker..."
    sudo systemctl restart docker
fi

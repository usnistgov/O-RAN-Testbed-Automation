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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

cd "$PARENT_DIR"

# Ensure the correct YAML editor is installed
sudo "$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

# Ensure that 5G_Core_Network/options.yaml is configured to use 5gdeploy instead of Open5GS
if [ -f "options.yaml" ]; then
    CORE_TO_USE=$(yq eval '.core_to_use' options.yaml)
    UPF_TO_USE=$(yq eval '.upf_to_use' options.yaml)
fi
if [[ "$CORE_TO_USE" == "null" || -z "$CORE_TO_USE" ]]; then
    echo "No core specified in ../options.yaml, please ensure that \"core_to_use\" is set."
    exit 1
fi
if [[ "$UPF_TO_USE" == "null" || -z "$UPF_TO_USE" ]]; then
    UPF_TO_USE="$CORE_TO_USE" # Default to the same core if not specified
fi
if [ "$CORE_TO_USE" == "open5gs" ]; then
    echo
    echo "ERROR: The configuration file ../options.yaml needs \"core_to_use\" to be a 5gdeploy core in order to install 5gdeploy."
    echo "       Please set \"core_to_use\" to a 5gdeploy core in ../options.yaml, then re-run this script."
    echo "       For example, set \"core_to_use: 5gdeploy-oai\"."
    echo
    exit 1
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

echo
echo
echo "Installing 5G Core Deployment Helper (5gdeploy)..."
# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

echo "Using CP: $CORE_TO_USE"
echo "Using UP: $UPF_TO_USE"

cd "$SCRIPT_DIR"

if [ "$CORE_TO_USE" == "5gdeploy-phoenix" ]; then
    ./install_scripts/phoenix_validate.sh
fi

if [ ! -d "5gdeploy" ]; then
    echo "Cloning 5G Core Deployment Helper (5gdeploy)..."
    "$PARENT_DIR/./install_scripts/git_clone.sh" https://github.com/usnistgov/5gdeploy.git
fi

cd $SCRIPT_DIR/5gdeploy
echo "Patching netdef/helpers.ts to generate NR Cell ID starting at hex 0xE000 (aligning with OAI gNB) instead of 0x10"
sed -i '0,/^[[:space:]]*nci[[:space:]]*=.*$/s//      nci = hexPad(((3584 + i) << (36 - gnbIdLength)) | 0xF, 9),/' netdef/helpers.ts

cd $SCRIPT_DIR

# Step 1: Install dependencies
mkdir -p logs
if [ -f logs/full_install_step_1_complete ]; then
    if ! command -v docker &>/dev/null; then
        rm logs/full_install_step_1_complete
    fi
    # If node version is less than 22, re-run step 1
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node --version | sed 's/v//g' | cut -d. -f1)
        if [ "$NODE_VERSION" -lt 22 ]; then
            echo "Node.js version is less than 22, reinstalling Node.js 22.x"
            sudo apt-get purge -y nodejs npm || true
            rm logs/full_install_step_1_complete
        fi
    fi
fi
if [ ! -f logs/full_install_step_1_complete ]; then
    # Install system packages
    sudo apt-get update
    sudo env $APTVARS apt-get install -y linux-generic linux-lowlatency
    echo 'wireshark-common wireshark-common/install-setuid boolean true' | sudo debconf-set-selections
    sudo env $APTVARS apt-get install -y httpie jq wireshark-common
    sudo adduser $(id -un) wireshark
    if ! dpkg -s python3-libconf &>/dev/null; then
        if ! sudo env $APTVARS apt-get install -y python3-libconf; then
            echo "Package python3-libconf not found in apt, installing via pip..."
            python3 -m pip install --user libconf
        fi
    fi
    # Install Node.js 22.x
    sudo install -d -m 0755 /etc/apt/keyrings
    http --ignore-stdin GET https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false

    sudo env $APTVARS apt-get install -y -t nodistro nodejs
    touch logs/full_install_step_1_complete
else
    echo "Dependencies already installed, skipping step 1."
fi

if ! command -v docker &>/dev/null; then
    echo "Docker is not installed, installing..."
    "$SCRIPT_DIR/install_scripts/install_docker.sh"
fi

cd "$SCRIPT_DIR"

./install_scripts/install_lazydocker.sh

# Check if docker is accessible from the current user, and if not, repair its permissions
if [ -z "$FIXED_DOCKER_PERMS" ]; then
    if ! OUTPUT=$(docker info 2>&1); then
        if echo "$OUTPUT" | grep -qiE 'permission denied|cannot connect to the docker daemon'; then
            echo "Docker permissions will repair on reboot."
            sudo groupadd -f docker
            if [ -n "$SUDO_USER" ]; then
                sudo usermod -aG docker "${SUDO_USER:-root}"
            else
                sudo usermod -aG docker "${USER:-root}"
            fi
            # Rather than requiring a reboot to apply docker permissions, set the docker group and re-run the parent script
            export FIXED_DOCKER_PERMS=1
            if ! command -v sg &>/dev/null; then
                echo
                echo "WARNING: Could not find set group (sg) command, docker may fail without sudo until the system reboots."
                echo
            else
                exec sg docker -c "$(printf '%q ' "$CURRENT_DIR/$0" "$@")"
            fi
        fi
    fi
fi

if [ "$CORE_TO_USE" == "5gdeploy-phoenix" ]; then
    cd "$SCRIPT_DIR"
    ./install_scripts/phoenix_build.sh
fi

cd "$SCRIPT_DIR/5gdeploy"

# Step 2: Install 5gdeploy
# For more information, see the 5gdeploy documentation: https://github.com/usnistgov/5gdeploy/blob/main/docs/INSTALL.md
echo "Starting installation of 5G Core Deployment Helper (5gdeploy)..."
./install.sh \
    --dpdk-version v24.11 \
    --eupf-version 54ed069c6cdf1da18b09bd78cb166bc4e4dd1ceb \
    --free5gc-version v4.0.1 \
    --free5gc-webconsole-version v1.4.1 \
    --gnbsim-version d3fce7e35a69b9f5d670242a93b7d1bee8842ecf \
    --gtp5g-version v0.9.13 \
    --oai-fed-version 2024.w45 \
    --oai-nwdaf-version 6a1408c9be6f5cf0ddb6c1f1b527a04e36205471 \
    --open5gs-dbctl-version v2.7.6 \
    --open5gs-version 2.7.6 \
    --packetrusher-version 80a7f4bc63d9563a8ec58ba126440d94018a35a2 \
    --pipework-version 9ba97f1735022fb5f811d9c2a304dda33fae1ad1 \
    --sockperf-version 19accb5229503dac7833f03713b978cb7fc48762 \
    --srsran5g-version 24_10_1 \
    --ueransim-version 2fc85e3e422b9a981d330bf6ff945136bfae97f3

cd "$SCRIPT_DIR"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
    DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
    echo "The 5gdeploy installation process took $DURATION_MINUTES minutes to complete."
    mkdir -p logs
    echo "$DURATION_MINUTES minutes" >>install_time.txt
fi

./generate_configurations.sh

echo "Successfully installed and configured the 5G Core Deployment Helper (5gdeploy)."

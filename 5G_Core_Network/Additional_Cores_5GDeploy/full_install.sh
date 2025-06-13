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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$SCRIPT_DIR"

if [ ! -d "5gdeploy" ]; then
    echo "Cloning 5G Core Deployment Helper (5gdeploy)..."
    "$PARENT_DIR/./install_scripts/git_clone.sh" https://github.com/usnistgov/5gdeploy.git
fi

# cd $SCRIPT_DIR/5gdeploy
# echo "Patching netdef/helpers.ts to generate NR Cell ID starting at hex 0xE000 (aligning with OAI gNB) instead of 0x10"
# sed -i '0,/^[[:space:]]*nci[[:space:]]*=.*$/s//      nci = hexPad(((3584 + i) << (36 - gnbIdLength)) | 0xF, 9),/' netdef/helpers.ts

cd $SCRIPT_DIR

# Step 1: Install dependencies
mkdir -p logs
if [ -f logs/full_install_step_1_complete ]; then
    if ! command -v docker &>/dev/null; then
        rm logs/full_install_step_1_complete
    fi
fi
if [ ! -f logs/full_install_step_1_complete ]; then
    # Code from (https://github.com/usnistgov/5gdeploy/blob/main/docs/INSTALL.md):
    # Install system packages
    sudo apt update
    echo 'wireshark-common wireshark-common/install-setuid boolean true' | sudo debconf-set-selections
    sudo DEBIAN_FRONTEND=noninteractive apt install -y httpie jq python3-libconf wireshark-common
    #sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-lowlatency
    sudo adduser $(id -un) wireshark
    # Check if the YAML editor is installed, and install it if not
    if ! command -v yq &>/dev/null; then
        sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
    fi
    # Install Node.js 22.x
    http --ignore-stdin GET https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y nodejs
    # # Install Node.js 20.x
    # http --ignore-stdin GET https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
    # echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    # sudo apt update
    # sudo DEBIAN_FRONTEND=noninteractive apt install -y nodejs
    touch logs/full_install_step_1_complete
else
    echo "Dependencies already installed, skipping step 1."
fi

# if docker is not installed, run install_scripts/install_docker.sh
if ! command -v docker &>/dev/null; then
    echo "Docker is not installed, installing..."
    "$SCRIPT_DIR/install_scripts/install_docker.sh"
fi

cd "$SCRIPT_DIR"

./install_scripts/install_lazydocker.sh

# Check if docker is accessible from the current user, and if not, repair its permissions
if [ -z "$FIXED_DOCKER_PERMS" ]; then
    if ! output=$(docker info 2>&1); then
        if echo "$output" | grep -qiE 'permission denied|cannot connect to the docker daemon'; then
            echo "Repairing Docker permissions..."
            sudo groupadd -f docker
            if [ -n "$SUDO_USER" ]; then
                sudo usermod -aG docker "$SUDO_USER"
            else
                sudo usermod -aG docker "$USER"
            fi
            # Rather than requiring a reboot to apply docker permissions, set the docker group and re-run the parent script
            export FIXED_DOCKER_PERMS=1
            if ! command -v sg &>/dev/null; then
                echo
                echo "WARNING: Could not find set group (sg) command, docker may fail without sudo until the system reboots."
                echo
            else
                exec sg docker "$CURRENT_DIR/$0" "$@"
            fi
        fi
    fi
fi

cd "$SCRIPT_DIR/5gdeploy"

# Step 2: Install 5gdeploy
echo "Starting installation of 5G Core Deployment Helper (5gdeploy)..."
./install.sh

cd "$SCRIPT_DIR"
./generate_configurations.sh

echo "Successfully installed and configured the 5G Core Deployment Helper (5gdeploy)."

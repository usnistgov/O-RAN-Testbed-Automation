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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo $APTVARS apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ ! -f "compose/orantestbed/compose.sh" ]; then
    echo "Error: Cannot find compose.sh in compose/orantestbed/. Please run the generate_configurations.sh script first."
    exit 1
fi

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
                exec sg docker "$CURRENT_DIR/$0" "$@"
            fi
        fi
    fi
fi

cd compose/orantestbed/

echo "Starting the 5G Core Deployment Helper (5gdeploy) Core..."
./compose.sh up

cd "$SCRIPT_DIR"

# Update the get_amf_address.txt file to point to the AMF container's IP
mkdir -p configs
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
    sudo $APTVARS apt-get install -y jq
fi

# # Dynamic AMF IP support: Fetch the AMF IP, and it will be updated in the configuration file
# # This code is optional, since the AMF IP is fixed on configuration; dynamic IP is not needed
# AMF_IP=$(docker inspect amf | jq -r '.[0].NetworkSettings.Networks["br-n2"].IPAddress')
# AMF_IP_BIND=$(ip route get 1 | awk '{print $(NF-2); exit}') # Get the IP of the primary network interface
# AMF_ADDRESSES_OUTPUT="configs/get_amf_address.txt"
# echo "$AMF_IP" >$AMF_ADDRESSES_OUTPUT
# echo "$AMF_IP_BIND" >>$AMF_ADDRESSES_OUTPUT

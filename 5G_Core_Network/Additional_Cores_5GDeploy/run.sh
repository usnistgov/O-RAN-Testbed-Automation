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
    sudo env $APTVARS apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$SCRIPT_DIR"

if [ ! -f "compose/orantestbed/compose.sh" ]; then
    echo "ERROR: Cannot find compose.sh in compose/orantestbed/. Please run the generate_configurations.sh script first."
    exit 1
fi

# Fetch the core and UPF to use from options.yaml
if [ -f "$PARENT_DIR/options.yaml" ]; then
    CORE_TO_USE=$(yq eval '.core_to_use' "$PARENT_DIR/options.yaml")
    UPF_TO_USE=$(yq eval '.upf_to_use' "$PARENT_DIR/options.yaml")
fi
if [[ "$CORE_TO_USE" == "null" || -z "$CORE_TO_USE" ]]; then
    echo "No core specified in options.yaml, please ensure that \"core_to_use\" is set."
    exit 1
fi
if [[ "$UPF_TO_USE" == "null" || -z "$UPF_TO_USE" ]]; then
    UPF_TO_USE="$CORE_TO_USE" # Default to the same core if not specified
fi

cd compose/orantestbed/

# Verify that the selected core and UPF match the currently deployed ones
if [ -f "core_upf_used.txt" ]; then
    CURRENT_CORE=$(sed -n '1p' core_upf_used.txt)
    CURRENT_UPF=$(sed -n '2p' core_upf_used.txt)
    if [[ "$CURRENT_CORE" != "$CORE_TO_USE" || "$CURRENT_UPF" != "$UPF_TO_USE" ]]; then
        echo
        echo "ERROR: The selected core ($CORE_TO_USE) or UPF ($UPF_TO_USE) does not match the currently deployed core ($CURRENT_CORE) or UPF ($CURRENT_UPF)."
        echo "Please run the generate_configurations.sh script to update the configuration before deploying."
        echo
        exit 1
    fi
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
                exec sg docker -c "$(printf '%q ' "$CURRENT_DIR/$0" "$@")"
            fi
        fi
    fi
fi

echo "Starting the 5G Core Deployment Helper (5gdeploy) Core..."
./compose.sh up

cd "$SCRIPT_DIR"

# Update the get_amf_address.txt file to point to the AMF container's IP
mkdir -p configs
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    sudo env $APTVARS apt-get install -y jq
fi

# # Dynamic AMF IP support: Fetch the AMF IP, and it will be updated in the configuration file
# # This code is optional since the AMF IP is fixed on configuration; dynamic IP is not needed
# AMF_IP=$(docker inspect amf | jq -r '.[0].NetworkSettings.Networks["br-n2"].IPAddress')
# AMF_IP_BIND=$(ip route get 1 | awk '{print $(NF-2); exit}') # Get the IP of the primary network interface
# AMF_ADDRESSES_OUTPUT="configs/get_amf_address.txt"
# echo "$AMF_IP" >$AMF_ADDRESSES_OUTPUT
# echo "$AMF_IP_BIND" >>$AMF_ADDRESSES_OUTPUT

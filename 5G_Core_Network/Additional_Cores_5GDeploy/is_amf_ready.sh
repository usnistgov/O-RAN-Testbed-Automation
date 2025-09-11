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

# Ensure that the correct script is used
if [ -f "$PARENT_DIR/options.yaml" ]; then
    CORE_TO_USE=$(yq eval '.core_to_use' "$PARENT_DIR/options.yaml")
fi
if [[ "$CORE_TO_USE" == "null" || -z "$CORE_TO_USE" ]]; then
    CORE_TO_USE="open5gs" # Default
fi
if [[ "$CORE_TO_USE" == "open5gs" ]]; then
    cd "$PARENT_DIR"
    ./is_amf_ready.sh
    exit 0
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

AMF_LOG=$(docker logs amf 2>&1)

if ./is_running.sh >/dev/null 2>&1 | grep -q "NOT_RUNNING"; then
    echo false
    exit 0
fi

if [ -z "$AMF_LOG" ]; then
    echo false
    exit 0
fi

if [[ "$CORE_TO_USE" == "5gdeploy-open5gs" ]]; then
    if echo "$AMF_LOG" | grep -q "NF registered"; then
        # Also ensure that at least three subscribers have been created in MongoDB
        if [ "$(docker logs mongo 2>&1 | grep -c "Creating subscriber")" -gt 3 ]; then
            echo true
            exit 0
        fi
    fi
    echo false
    exit 0
elif [[ "$CORE_TO_USE" == "5gdeploy-oai" ]]; then
    if echo "$AMF_LOG" | grep -q "AMF has successfully registered to NRF"; then
        if [ "$(docker logs sql 2>&1 | grep -c "MariaDB setup finished")" -gt 0 ] &&
            docker logs udr 2>&1 | grep -q "Sending NF Registration request"; then
            echo true
            exit 0
        fi
    fi
elif [[ "$CORE_TO_USE" == "5gdeploy-free5gc" ]]; then
    if echo "$AMF_LOG" | grep -q "Start SBI server"; then
        echo true
        exit 0
    fi
elif [[ "$CORE_TO_USE" == "5gdeploy-phoenix" ]]; then
    if echo "$AMF_LOG" | grep -q "Successfully parsed command line"; then # TODO: Improve this check
        echo true
        exit 0
    fi
fi

echo false
exit 1

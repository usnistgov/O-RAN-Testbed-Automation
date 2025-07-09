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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

UE_NUMBER=""
if [ "$#" -eq 1 ]; then
    UE_NUMBER=$1
    if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
        echo "Error: UE number must be a number."
        exit 1
    fi
    if [ $UE_NUMBER -lt 1 ]; then
        echo "Error: UE number must be greater than or equal to 1."
        exit 1
    fi
fi

# Remove a network namespace given the UE number
remove_ue_namespace() {
    local UE_NUMBER="$1"
    echo "Removing namespace ue$UE_NUMBER..."
    sudo ./install_scripts/revert_ue_namespace.sh "$UE_NUMBER"
}

# Remove all UE network namespaces
remove_all_ue_namespaces() {
    # Get all active UE namespaces, and remove the namespaces
    UE_NETNS=($(ip netns list | grep -oP '^ue\K[0-9]+'))
    for UE_NUM in "${UE_NETNS[@]}"; do
        remove_ue_namespace "$UE_NUM"
    done
}

# Check if the UE is already stopped
if $(./is_running.sh | grep -q "User Equipment: NOT_RUNNING"); then
    # Remove UE namespaces
    if [ -z "$UE_NUMBER" ]; then
        remove_all_ue_namespaces
    else
        remove_ue_namespace "$UE_NUMBER"
    fi
    ./is_running.sh
    exit 0
fi

# Prevent the subsequent command from requiring credential input
sudo ls >/dev/null 2>&1

# Send a graceful shutdown signal to the UE process
if [ -z "$UE_NUMBER" ]; then
    sudo pkill -f "srsue" >/dev/null 2>&1 &
    remove_all_ue_namespaces
else
    sudo pkill -f "srsue --config_file configs/ue$UE_NUMBER.conf" >/dev/null 2>&1 &
    remove_ue_namespace "$UE_NUMBER"
fi

# Wait for the process to terminate gracefully
COUNT=0
MAX_COUNT=10
sleep 1
while [ $COUNT -lt $MAX_COUNT ]; do
    IS_RUNNING=$(./is_running.sh)
    if [ -z "$UE_NUMBER" ]; then
        if echo "$IS_RUNNING" | grep -q "User Equipment: NOT_RUNNING"; then
            echo "The User Equipment has stopped gracefully."
            ./is_running.sh
            exit 0
        fi
    else
        if ! echo "$IS_RUNNING" | grep -q "ue$UE_NUMBER"; then
            echo "The User Equipment $UE_NUMBER has stopped gracefully."
            ./is_running.sh
            exit 0
        fi
    fi
    COUNT=$((COUNT + 1))
    echo "$IS_RUNNING [$((MAX_COUNT - COUNT + 1))]"
    sleep 2
done

# If the process is still running after 20 seconds, send a forceful kill signal
if [ -z "$UE_NUMBER" ]; then
    echo "The User Equipment did not stop in time, sending forceful kill signal..."
    sudo pkill -9 -f "srsue" >/dev/null 2>&1 &
    remove_all_ue_namespaces
else
    echo "The User Equipment $UE_NUMBER did not stop in time, sending forceful kill signal..."
    sudo pkill -9 -f "srsue --config_file configs/ue$UE_NUMBER.conf" >/dev/null 2>&1 &
    remove_ue_namespace "$UE_NUMBER"
fi

sleep 2
./is_running.sh

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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Default values
UE_NUMBER=1
RFSIM_SERVER=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
    [0-9]*)
        UE_NUMBER="$1"
        shift
        ;;
    --rfsim-server)
        RFSIM_SERVER=1
        shift
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
    echo "Error: UE number must be a number."
    exit 1
fi
if [ $UE_NUMBER -lt 1 ]; then
    echo "Error: UE number must be greater than or equal to 1."
    exit 1
fi

if [ ! -f "configs/ue1.conf" ]; then
    echo "Configuration was not found for OAI UE 1. Please run ./generate_configurations.sh first."
    exit 1
fi

# Function to handle graceful shutdown
graceful_shutdown() {
    echo "Shutting down UE $UE_NUMBER gracefully..."
    ./stop.sh
    exit
}
trap graceful_shutdown SIGINT SIGTERM SIGQUIT

# Function to update or add configuration properties in .conf files, considering sections and uncommenting if needed
update_conf() {
    echo "update_conf($1, $2, $3)"
    local FILE_PATH="$1"
    local PROPERTY="$2"
    local VALUE="$3"

    # Check if the property exists in the file, and update or append it accordingly
    if grep -q "^\s*$PROPERTY\s*=" "$FILE_PATH"; then
        # Update existing property's value
        sed -i "s|^\(\s*$PROPERTY\s*=\).*|\1 $VALUE;|" "$FILE_PATH"
    else
        # Append new property-value pair if it does not exist
        echo "$PROPERTY = $VALUE;" >>"$FILE_PATH"
    fi
}

UE_CONF_PATH="configs/ue$UE_NUMBER.conf"

if [ ! -f "$UE_CONF_PATH" ]; then
    echo "Configuration file for UE $UE_NUMBER not found, creating..."
    ./generate_configurations.sh "$UE_NUMBER"
    if [ ! -f "$UE_CONF_PATH" ]; then
        echo "Configuration file for UE $UE_NUMBER still not found after generation."
        exit 1
    fi
fi

HOSTNAME_IP=$(hostname -I | awk '{print $1}')

if ./is_running.sh | grep -q "ue$UE_NUMBER"; then
    echo "Already running ue$UE_NUMBER."
else
    RFSIM_SERVER_ARG="--rfsimulator.serveraddr $HOSTNAME_IP"
    if [ "$RFSIM_SERVER" -ne 0 ]; then
        echo "RF simulator server mode enabled."
        RFSIM_SERVER_ARG="--rfsimulator.serveraddr server"
    fi

    if [ ! -f "$UE_CONF_PATH" ]; then
        echo "Configuration was not found for OAI UE $UE_NUMBER. Please run ./generate_configurations.sh first."
        exit 1
    fi
    mkdir -p logs
    >logs/ue${UE_NUMBER}_stdout.txt

    if ! command -v gdb &>/dev/null; then
        echo "Installing GNU Debugger..."
        sudo apt-get update
        sudo env $APTVARS apt-get install -y gdb
    fi

    echo "Starting nr-uesoftmodem (ue$UE_NUMBER)..."

    # Ensure the following command runs with sudo privileges
    sudo ls >/dev/null

    # Give the UE its own network namespace and configure it to access the host network
    sudo ./install_scripts/setup_ue_namespace.sh "$UE_NUMBER"

    cd "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build"

    BANDWIDTH_RBS=106
    NUMEROLOGY=1
    BAND=78
    DL_CARRIER_FREQUENCY_HZ=3619200000

    # sudo ip netns exec ue$UE_NUMBER sudo gdb --args ./nr-uesoftmodem -O "../../../../configs/ue$UE_NUMBER.conf" --rfsim $RFSIM_SERVER_ARG --rfsimulator.options chanmod -r $BANDWIDTH_RBS --numerology $NUMEROLOGY --band $BAND -C $DL_CARRIER_FREQUENCY_HZ
    if [ $RFSIM_SERVER -eq 0 ]; then
        sudo script -q -f -c "ip netns exec ue$UE_NUMBER sudo gdb --args ./nr-uesoftmodem -O \"../../../../configs/ue$UE_NUMBER.conf\" --rfsim $RFSIM_SERVER_ARG --rfsimulator.options chanmod -r $BANDWIDTH_RBS --numerology $NUMEROLOGY --band $BAND -C $DL_CARRIER_FREQUENCY_HZ" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_stdout.txt"
    else
        sudo script -q -f -c "sudo gdb --args ./nr-uesoftmodem -O \"../../../../configs/ue$UE_NUMBER.conf\" --rfsim $RFSIM_SERVER_ARG --rfsimulator.options chanmod -r $BANDWIDTH_RBS --numerology $NUMEROLOGY --band $BAND -C $DL_CARRIER_FREQUENCY_HZ" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_stdout.txt"
    fi
fi

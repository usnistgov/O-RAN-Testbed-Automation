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

USE_FLEXRIC=false
USE_ZMQ_CHANNEL_EMULATOR=true
USE_DURANTA_UE=false

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

UE_DIRECTORY="$SCRIPT_DIR/User_Equipment"
if [ "$USE_DURANTA_UE" = "true" ]; then
    UE_DIRECTORY="$SCRIPT_DIR/OpenAirInterface_Testbed/User_Equipment"

    if [ ! -f "$UE_DIRECTORY/run_background.sh" ]; then
        echo "User Equipment run script not found."
        exit 1
    fi
    if grep -q "USE_ZMQ_CHANNEL_EMULATOR=false" "$UE_DIRECTORY/run_background.sh"; then
        echo "ERROR: USE_DURANTA_UE=true, but USE_ZMQ_CHANNEL_EMULATOR=false. Enable the ZeroMQ channel emulator by following the instructions in the link below, then try again."
        echo "    https://github.com/usnistgov/O-RAN-Testbed-Automation/tree/main/OpenAirInterface_Testbed#simulating-multiple-ues-and-cells-with-a-zeromq-channel-emulator"
        exit 1
    fi
fi

sudo -v # Ensure sudo session is active

UE_NUMBERS=()
if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    if [ ! -f "Next_Generation_Node_B/zmq_channel_emulator/zmq_channel_emulator.py" ]; then
        echo "ZeroMQ channel emulator configuration was not found. Please run ./generate_configurations.sh first."
        exit 1
    fi
    if [ ! -f "Next_Generation_Node_B/install_scripts/validate_zmq_channel_emulator_config.sh" ]; then
        echo "ZeroMQ channel emulator verifier was not found. Please run ./generate_configurations.sh first."
        exit 1
    fi
    # Parse the ZeroMQ channel emulator for the list of UEs and cells
    UE_NUMBERS=($(grep -oP 'UE_CONFIG:\s+\K\d+' Next_Generation_Node_B/zmq_channel_emulator/zmq_channel_emulator.py))
    CELL_NUMBERS=($(grep -oP 'CELL_CONFIG:\s+\K\d+' Next_Generation_Node_B/zmq_channel_emulator/zmq_channel_emulator.py))
    UE_NUMBERS_STR=$(
        IFS=,
        echo "${UE_NUMBERS[*]}"
    )
    CELL_NUMBERS_STR=$(
        IFS=,
        echo "${CELL_NUMBERS[*]}"
    )
    if ! "Next_Generation_Node_B/install_scripts/validate_zmq_channel_emulator_config.sh" --ues "$UE_NUMBERS_STR" --cells "$CELL_NUMBERS_STR"; then
        echo "Run ./generate_configurations.sh with the same UE numbers before ./run.sh."
        exit 1
    fi
    echo "ZeroMQ channel emulator UEs: ${UE_NUMBERS[*]}"
else
    UE_NUMBERS=(1)
fi

if ! ip link show ogstun >/dev/null 2>&1 ||
    [ "$(sysctl -n net.ipv4.ip_forward)" != "1" ] ||
    [ "$(sysctl -n net.ipv6.conf.all.forwarding)" != "1" ]; then
    echo "Configuring Open5GS UE data-plane network..."
    sudo ./5G_Core_Network/install_scripts/network_config.sh
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo sysctl -w net.ipv6.conf.all.forwarding=1
fi

if ! lsmod | grep -q '^sctp '; then
    echo "Enabling SCTP kernel module..."
    sudo ./5G_Core_Network/install_scripts/enable_sctp.sh
fi

# Upon exit, gracefully stop all components and fix console in case it breaks
trap '
    EXIT_STATUS=$?
    trap - EXIT SIGINT SIGTERM
    echo "#################################  STOPPING... #################################"
    if [ "$USE_DURANTA_UE" = "true" ]; then
        "$UE_DIRECTORY/stop.sh" || true
    fi
    "$SCRIPT_DIR/stop.sh" || true
    stty sane || true
    exit "$EXIT_STATUS"
' EXIT SIGINT SIGTERM

echo "Running 5G Core components..."
cd 5G_Core_Network
./run.sh
cd ..

if [ "$USE_FLEXRIC" = "true" ]; then
    echo
    echo "Running FlexRIC..."
    cd OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC
    ./run_background.sh

    if $(./is_running.sh | grep -q "NOT_RUNNING"); then
        echo "ERROR: Could not start FlexRIC."
        exit 1
    fi
    cd ../../..
fi

echo
echo -n "Waiting for AMF to be ready"
attempt=0
while ! ./5G_Core_Network/is_amf_ready.sh | grep -q "true"; do
    echo -n "."
    sleep 0.5
    attempt=$((attempt + 1))
    if [ $attempt -ge 120 ]; then
        echo "5G Core components did not start after 60 seconds, exiting..."
        exit 1
    fi
done
echo -e "\nAMF is ready."

echo
echo "Running gNodeB..."
cd Next_Generation_Node_B
./run_background.sh
cd ..

echo
echo "Running User Equipment..."
cd "$UE_DIRECTORY"
if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ] && [ ${#UE_NUMBERS[@]} -gt 1 ]; then
    for ((i = 1; i < ${#UE_NUMBERS[@]}; i++)); do
        read -r _ _ UE_TX_PORT _ _ < <(
            "$SCRIPT_DIR/Next_Generation_Node_B/install_scripts/get_zmq_channel_emulator_config.sh" --ue "${UE_NUMBERS[$i]}"
        )
        if sudo ip netns exec "ue${UE_NUMBERS[$i]}" ss -ltnH 2>/dev/null |
            awk '{print $4}' | grep -Eq ":${UE_TX_PORT}$"; then
            echo "Using existing ZeroMQ instance for UE ${UE_NUMBERS[$i]}."
            continue
        fi
        echo "Running UE ${UE_NUMBERS[$i]} in background..."
        ./run_background.sh "${UE_NUMBERS[$i]}"
    done
fi
echo "Running UE ${UE_NUMBERS[0]}..."
./run.sh "${UE_NUMBERS[0]}"
cd "$SCRIPT_DIR"

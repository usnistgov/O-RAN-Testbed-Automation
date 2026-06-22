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

USE_FLEXRIC=true
USE_ZMQ_BROKER=false
ZMQ_BROKER_UE_START_TIMEOUT=90

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

UE_NUMBERS=()
for ARG in "$@"; do
    if [[ "$ARG" =~ ^[0-9]+$ ]]; then
        UE_NUMBERS+=("$ARG")
    fi
done

if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    if [ "$USE_ZMQ_BROKER" = "true" ]; then
        for UE_CONFIG in "$SCRIPT_DIR"/User_Equipment/configs/ue*.conf; do
            [ -e "$UE_CONFIG" ] || continue
            UE_CONFIG_NAME=$(basename "$UE_CONFIG")
            UE_NUMBER="${UE_CONFIG_NAME#ue}"
            UE_NUMBER="${UE_NUMBER%.conf}"
            if [[ "$UE_NUMBER" =~ ^[0-9]+$ ]]; then
                UE_NUMBERS+=("$UE_NUMBER")
            fi
        done
    fi

    if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
        UE_NUMBERS=(1)
    fi
fi

IFS=$'\n' UE_NUMBERS=($(printf "%s\n" "${UE_NUMBERS[@]}" | sort -nr))
unset IFS

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    ZMQ_BROKER_PYTHON="$SCRIPT_DIR/Next_Generation_Node_B/zmq_broker/multi_ue_scenario.py"
    ZMQ_BROKER_VERIFIER="$SCRIPT_DIR/Next_Generation_Node_B/install_scripts/validate_zmq_broker_config.sh"
    if [ ! -f "$ZMQ_BROKER_PYTHON" ]; then
        echo "ZMQ Broker configuration was not found. Please run ./generate_configurations.sh first."
        exit 1
    fi
    if [ ! -f "$ZMQ_BROKER_VERIFIER" ]; then
        echo "ZMQ Broker verifier was not found. Please run ./generate_configurations.sh first."
        exit 1
    fi
    VERIFY_ARGS=(
        "--gnb-config" "$SCRIPT_DIR/Next_Generation_Node_B/configs/gnb.yaml"
        "--broker" "$ZMQ_BROKER_PYTHON"
        "--ue-config-dir" "$SCRIPT_DIR/User_Equipment/configs"
    )
    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
        VERIFY_ARGS+=("--ue" "$UE_NUMBER")
    done
    if ! "$ZMQ_BROKER_VERIFIER" "${VERIFY_ARGS[@]}"; then
        echo "Run ./generate_configurations.sh with the same UE numbers before ./run.sh."
        exit 1
    fi
    echo "Broker-mode UE launch order: ${UE_NUMBERS[*]}"
    if [ ${#UE_NUMBERS[@]} -gt 1 ]; then
        echo "Broker-mode UEs will start together so all broker uplink inputs are active before PDU-session checks."
    fi
fi

monitor_ue_pdu_session() {
    UE_NUMBER=$1
    PARENT_PID=$2
    (
        ATTEMPT=0
        while ! ./install_scripts/get_pdu_sessions.sh "$UE_NUMBER" >/dev/null 2>&1; do
            if [ $ATTEMPT -gt 20 ] && ! ./is_running.sh | grep -q "ue$UE_NUMBER"; then
                echo
                echo "UE $UE_NUMBER stopped before receiving a PDU session."
                kill -TERM "$PARENT_PID" >/dev/null 2>&1 || true
                exit 1
            fi
            sleep 1
            ATTEMPT=$((ATTEMPT + 1))
            if [ $ATTEMPT -ge $ZMQ_BROKER_UE_START_TIMEOUT ]; then
                echo
                echo "UE $UE_NUMBER did not receive a PDU session after $ZMQ_BROKER_UE_START_TIMEOUT seconds."
                echo "Recent UE $UE_NUMBER stdout:"
                tail -n 80 "logs/ue${UE_NUMBER}_stdout.txt" || true
                echo "Recent gNodeB stdout:"
                tail -n 80 "../Next_Generation_Node_B/logs/gnb_stdout.txt" || true
                echo "Recent ZMQ Broker log:"
                tail -n 80 "../Next_Generation_Node_B/logs/zmq_broker.log" || true
                kill -TERM "$PARENT_PID" >/dev/null 2>&1 || true
                exit 1
            fi
        done
        echo
        echo "UE $UE_NUMBER received PDU session(s):"
        ./install_scripts/get_pdu_sessions.sh "$UE_NUMBER"
    ) &
}

sudo -v # Ensure sudo session is active

# Upon exit, gracefully stop all components and fix console in case it breaks
trap "trap - EXIT SIGINT SIGTERM; echo \"#################################  STOPPING... #################################\"; \"$SCRIPT_DIR/./stop.sh\"; stty sane || true; exit" EXIT SIGINT SIGTERM

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
        echo "Error starting FlexRIC."
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
cd User_Equipment
if [ "$USE_ZMQ_BROKER" = "true" ] && [ ${#UE_NUMBERS[@]} -gt 1 ]; then
    for ((i = 0; i < ${#UE_NUMBERS[@]} - 1; i++)); do
        ./run_background.sh "${UE_NUMBERS[$i]}"
    done
fi
if [ "$USE_ZMQ_BROKER" = "true" ]; then
    for ((i = 0; i < ${#UE_NUMBERS[@]} - 1; i++)); do
        monitor_ue_pdu_session "${UE_NUMBERS[$i]}" "$$"
    done
    monitor_ue_pdu_session "${UE_NUMBERS[-1]}" "$$"
fi
./run.sh "${UE_NUMBERS[-1]}"
cd ..

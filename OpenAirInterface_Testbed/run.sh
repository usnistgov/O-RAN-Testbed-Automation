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

USE_ZMQ_CHANNEL_EMULATOR=false
SHOW_ZMQ_CHANNEL_EMULATOR_UI=true
USE_SRSRAN_UE=false # Experimental
USE_IMSCOPE=false

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

while [[ $# -gt 0 ]]; do
    case "$1" in
    --imscope)
        USE_IMSCOPE=true
        shift
        ;;
    --no-imscope)
        USE_IMSCOPE=false
        shift
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

UE_DIRECTORY="$SCRIPT_DIR/User_Equipment"
UE_READY_MESSAGE="Received PDU Session Establishment Accept"
if [ "$USE_SRSRAN_UE" = "true" ]; then
    if [ "$USE_ZMQ_CHANNEL_EMULATOR" != "true" ]; then
        echo "ERROR: The srsRAN UE requires the ZeroMQ channel emulator with the Duranta gNodeB. It can be enabled with the following commands:"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' User_Equipment/full_install.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' User_Equipment/generate_configurations.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' Next_Generation_Node_B/full_install.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ"                   # Set to "SIMU", "ZMQ", or "USRP"/' Next_Generation_Node_B/generate_configurations.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run_handover_scenario.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run_with_grafana_dashboard.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' User_Equipment/run.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' User_Equipment/run_background.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' User_Equipment/run_gdb.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' Next_Generation_Node_B/run.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' Next_Generation_Node_B/run_background.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' Next_Generation_Node_B/run_gdb.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' Next_Generation_Node_B/run_split_du.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' Next_Generation_Node_B/is_running.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' Next_Generation_Node_B/stop.sh"
        exit 1
    fi
    UE_DIRECTORY="$SCRIPT_DIR/../User_Equipment"
    UE_READY_MESSAGE="PDU Session Establishment successful" # srsRAN_4G
    # UE_READY_MESSAGE="Attaching UE..." # srsRAN_4G
fi

if [ "$USE_IMSCOPE" = "true" ] && [ ! -f "$SCRIPT_DIR/Next_Generation_Node_B/openairinterface5g/cmake_targets/ran_build/build/libimscope.so" ]; then
    echo "ERROR: ImScope library not found. Rerun Next_Generation_Node_B/full_install.sh after setting USE_IMSCOPE=true."
    exit 1
fi

sudo -v # Ensure sudo session is active

UE_NUMBERS=()
CELL_NUMBERS=()
declare -A EXTERNAL_UE_ENDPOINTS=()
if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    ./Next_Generation_Node_B/install_scripts/validate_zmq_channel_emulator_config.sh --channel-emulator-only
    mapfile -t UE_NUMBERS < <(./Next_Generation_Node_B/install_scripts/get_zmq_channel_emulator_config.sh --ues)
    mapfile -t CELL_NUMBERS < <(./Next_Generation_Node_B/install_scripts/get_zmq_channel_emulator_config.sh --cells)

    GNB_ZMQ_LIBRARY="$SCRIPT_DIR/Next_Generation_Node_B/openairinterface5g/cmake_targets/ran_build/build/liboai_zmqdevif.so"
    if [ "$USE_SRSRAN_UE" = "true" ]; then
        UE_ZMQ_LIBRARY="$UE_DIRECTORY/srsRAN_4G/build/srsue/src/srsue"
    else
        UE_ZMQ_LIBRARY="$UE_DIRECTORY/openairinterface5g/cmake_targets/ran_build/build/liboai_zmqdevif.so"
    fi
    if [ ! -f "$GNB_ZMQ_LIBRARY" ] || [ ! -f "$UE_ZMQ_LIBRARY" ]; then
        echo "ERROR: The Duranta gNodeB and selected UE must be built with ZeroMQ support."
        if [ ! -f "$GNB_ZMQ_LIBRARY" ]; then
            echo "Missing gNodeB library: $GNB_ZMQ_LIBRARY"
        fi
        if [ ! -f "$UE_ZMQ_LIBRARY" ]; then
            echo "Missing UE library: $UE_ZMQ_LIBRARY"
        fi
        echo "Rerun the required full_install.sh scripts with ZeroMQ enabled."
        exit 1
    fi

    echo "ZeroMQ Channel Emulator Duranta UEs: ${UE_NUMBERS[*]}"
    echo "ZeroMQ Channel Emulator Duranta DUs: ${CELL_NUMBERS[*]}"
else
    UE_NUMBERS=(1)
fi

# Upon exit, gracefully stop all components and fix console in case it breaks
trap '
    EXIT_STATUS=$?
    trap - EXIT SIGINT SIGTERM
    stty sane || true
    echo "#################################  STOPPING... #################################"
    "$SCRIPT_DIR/stop.sh" || true
    stty sane || true
    exit "$EXIT_STATUS"
' EXIT SIGINT SIGTERM

echo "Running 5G Core components..."
cd 5G_Core_Network
./run.sh
cd ..

echo
echo "Running FlexRIC..."
cd RAN_Intelligent_Controllers/Flexible-RIC
./run_background.sh

if $(./is_running.sh | grep -q "NOT_RUNNING"); then
    echo "ERROR: Could not start FlexRIC."
    exit 1
fi
cd ../..

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

cd Next_Generation_Node_B
if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    echo
    ./install_scripts/run_zmq_channel_emulator.sh --show-ui "$SHOW_ZMQ_CHANNEL_EMULATOR_UI"
    echo
    echo "Running DUs..."
    # The first DU ensures that the CU is ready (starting it)
    PRIMARY_CELL=${CELL_NUMBERS[0]}
    for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
        if [ "$USE_IMSCOPE" = "true" ] && [ "$CELL_NUMBER" = "$PRIMARY_CELL" ]; then
            ./run_background_split_du.sh "$CELL_NUMBER" --imscope
        else
            ./run_background_split_du.sh "$CELL_NUMBER"
        fi
        stty sane || true
    done
else
    echo
    echo "Running gNodeB..."
    if [ "$USE_IMSCOPE" = "true" ]; then
        ./run_background.sh --imscope
    else
        ./run_background.sh
    fi
fi
stty sane || true
cd ..

if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    echo
    echo "Running User Equipment..."
    cd "$UE_DIRECTORY"
    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
        read -r _ _ UE_TX_PORT _ _ < <(
            "$SCRIPT_DIR/Next_Generation_Node_B/install_scripts/get_zmq_channel_emulator_config.sh" --ue "$UE_NUMBER"
        )
        if sudo ip netns exec "ue$UE_NUMBER" ss -ltnH 2>/dev/null |
            awk '{print $4}' | grep -Eq ":${UE_TX_PORT}$"; then
            EXTERNAL_UE_ENDPOINTS[$UE_NUMBER]=true
            echo "Using existing ZeroMQ instance for UE $UE_NUMBER."
            continue
        fi
        ./run_background.sh "$UE_NUMBER"
        stty sane || true
    done
    cd "$SCRIPT_DIR"
fi

cd Next_Generation_Node_B
if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
        LOG_FILE="logs/split_du${CELL_NUMBER}_stdout.txt"
        echo -en "\nWaiting for DU $CELL_NUMBER to be ready"
        ATTEMPT=0
        while ! ./is_du_ready.sh "$CELL_NUMBER" | grep -qx "true"; do
            stty sane || true
            echo -n "."
            sleep 0.5
            ATTEMPT=$((ATTEMPT + 1))
            if [ $ATTEMPT -ge 120 ]; then
                echo "DU $CELL_NUMBER did not start after 60 seconds, exiting..."
                exit 1
            fi
            if ! ./is_running.sh | grep -Eq "(^|[ (])du${CELL_NUMBER}([ )]|$)"; then
                echo "ERROR: Could not start DU $CELL_NUMBER. Check $LOG_FILE for more information."
                exit 1
            fi
        done
        echo -e "\nDU $CELL_NUMBER is ready."
    done
else
    LOG_FILE="logs/gnb_stdout.txt"
    echo -en "\nWaiting for gNodeB to be ready"
    ATTEMPT=0
    while ! ./is_gnb_ready.sh | grep -qx "true"; do
        stty sane || true
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "gNodeB did not start after 60 seconds, exiting..."
            exit 1
        fi
        if ! ./is_running.sh | grep -q "^gNodeB: RUNNING"; then
            echo "ERROR: Could not start gNodeB. Check $LOG_FILE for more information."
            exit 1
        fi
    done
    echo -e "\ngNodeB is ready."
fi
cd ..

if [ "$USE_ZMQ_CHANNEL_EMULATOR" != "true" ]; then
    echo
    echo "Running User Equipment..."
    cd "$UE_DIRECTORY"
    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
        ./run_background.sh "$UE_NUMBER"
        stty sane || true
    done
    cd "$SCRIPT_DIR"
fi

cd "$UE_DIRECTORY"
for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    if [ "${EXTERNAL_UE_ENDPOINTS[$UE_NUMBER]:-false}" = "true" ]; then
        read -r _ _ UE_TX_PORT _ _ < <(
            "$SCRIPT_DIR/Next_Generation_Node_B/install_scripts/get_zmq_channel_emulator_config.sh" --ue "$UE_NUMBER"
        )
        if ! sudo ip netns exec "ue$UE_NUMBER" ss -ltnH 2>/dev/null |
            awk '{print $4}' | grep -Eq ":${UE_TX_PORT}$"; then
            echo "ERROR: The external ZeroMQ instance for UE $UE_NUMBER is no longer running."
            exit 1
        fi
        echo -e "\nUsing existing ZeroMQ instance for UE $UE_NUMBER."
        continue
    fi
    LOG_FILE="logs/ue${UE_NUMBER}_stdout.txt"
    echo -en "\nWaiting for UE $UE_NUMBER to be ready"
    ATTEMPT=0
    while [ ! -f "$LOG_FILE" ] || ! grep -qaF "$UE_READY_MESSAGE" "$LOG_FILE"; do
        stty sane || true
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 240 ]; then
            echo "UE $UE_NUMBER did not start after 120 seconds, exiting..."
            exit 1
        fi
        if ! ./is_running.sh | grep -Eq "(^|[ (])ue${UE_NUMBER}([ )]|$)"; then
            echo "ERROR: Could not start UE $UE_NUMBER. Check $LOG_FILE for more information."
            exit 1
        fi
    done
    echo -e "\nUE $UE_NUMBER is ready."
done
cd "$SCRIPT_DIR"

echo
echo "Running xApp KPM Monitor..."
cd RAN_Intelligent_Controllers/Flexible-RIC
./run_xapp_kpm_moni.sh
# ./additional_scripts/run_xapp_kpm_moni_write_to_csv.sh
# ./additional_scripts/run_xapp_kpm_moni_write_to_influxdb.sh
# ./additional_scripts/run_xapp_kpm_rc.sh
# ./additional_scripts/run_xapp_rc_moni.sh
# ./additional_scripts/run_xapp_gtp_mac_rlc_pdcp_moni.sh

cd ../..

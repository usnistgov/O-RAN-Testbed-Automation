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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

UE_DIRECTORY="$SCRIPT_DIR/User_Equipment"
UE_READY_MESSAGE="Received PDU Session Establishment Accept"
if [ "$USE_SRSRAN_UE" = "true" ]; then
    if [ "$USE_ZMQ_CHANNEL_EMULATOR" != "true" ]; then
        echo "ERROR: The srsRAN UE requires the ZeroMQ channel emulator with the Duranta gNodeB. It can be enabled with the following commands:"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' User_Equipment/full_install.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' User_Equipment/generate_configurations.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' Next_Generation_Node_B/full_install.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' Next_Generation_Node_B/generate_configurations.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run_handover_scenario.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run_with_grafana_dashboard.sh"
        echo "    sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run_with_nrscope_gui.sh"
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

if [ ! -f "Next_Generation_Node_B/openairinterface5g/cmake_targets/ran_build/build/libimscope.so" ]; then
    echo "ERROR: ImScope library not found. Rerun Next_Generation_Node_B/full_install.sh after setting NRSCOPE_GUI=true."
    exit 1
fi

UE_NUMBERS=()
CELL_NUMBERS=()
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

if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    cd Next_Generation_Node_B
    echo
    ./install_scripts/run_zmq_channel_emulator.sh --show-ui "$SHOW_ZMQ_CHANNEL_EMULATOR_UI"
    echo
    echo "Running DUs..."
    # The first DU ensures that the CU is ready (starting it)
    PRIMARY_CELL=${CELL_NUMBERS[0]}
    for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
        if [ "$CELL_NUMBER" != "$PRIMARY_CELL" ]; then
            ./run_background_split_du.sh "$CELL_NUMBER"
            stty sane || true
        fi
    done
    echo
    echo "Running DU $PRIMARY_CELL with NR-Scope..."
    setsid --wait bash -c "exec stdbuf -oL -eL \"$SCRIPT_DIR/Next_Generation_Node_B/run_split_du.sh\" $PRIMARY_CELL --nrscope" </dev/null >/dev/null 2>&1 &
    PRIMARY_DU_PID=$!
    stty sane || true
    cd ..

    echo
    echo "Running User Equipment..."
    cd "$UE_DIRECTORY"
    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
        ./run_background.sh "$UE_NUMBER"
        stty sane || true
    done
    cd "$SCRIPT_DIR"

    cd Next_Generation_Node_B
    for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
        LOG_FILE="logs/split_du${CELL_NUMBER}_stdout.txt"
        echo -en "\nWaiting for DU $CELL_NUMBER to be ready"
        ATTEMPT=0
        while ! ./is_du_ready.sh "$CELL_NUMBER" | grep -qx "true"; do
            stty sane || true
            echo -n "."
            sleep 0.5
            ATTEMPT=$((ATTEMPT + 1))
            if [ "$CELL_NUMBER" = "$PRIMARY_CELL" ] && ! ps -p "$PRIMARY_DU_PID" >/dev/null; then
                wait "$PRIMARY_DU_PID" || true
                echo "DU $PRIMARY_CELL exited before it started. Check $LOG_FILE."
                exit 1
            fi
            if [ $ATTEMPT -ge 120 ]; then
                echo "DU $CELL_NUMBER did not start after 60 seconds, exiting..."
                exit 1
            fi
            if [ "$CELL_NUMBER" != "$PRIMARY_CELL" ] && ! ./is_running.sh | grep -Eq "(^|[ (])du${CELL_NUMBER}([ )]|$)"; then
                echo "ERROR: Could not start DU $CELL_NUMBER. Check $LOG_FILE for more information."
                exit 1
            fi
        done
        echo -e "\nDU $CELL_NUMBER is ready."
    done
    cd "$UE_DIRECTORY"

    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
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

    wait "$PRIMARY_DU_PID"
else
    echo
    echo "Running UE..."
    UE_ID=1
    cd "$UE_DIRECTORY"
    ./run_background.sh "$UE_ID"
    stty sane || true

    echo -en "\nWaiting for UE $UE_ID to be ready"
    ATTEMPT=0
    while [ ! -f logs/ue${UE_ID}_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/ue${UE_ID}_stdout.txt; do
        stty sane || true
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "UE $UE_ID did not start after 60 seconds, exiting..."
            exit 1
        fi
        if ! ./is_running.sh | grep -Eq "(^|[ (])ue${UE_ID}([ )]|$)"; then
            echo "ERROR: Could not start UE $UE_ID. Check logs/ue${UE_ID}_stdout.txt for more information."
            exit 1
        fi
    done
    echo -e "\nUE $UE_ID is ready."
    cd "$SCRIPT_DIR"

    echo
    echo "Running gNB..."
    cd Next_Generation_Node_B
    ./run.sh
fi

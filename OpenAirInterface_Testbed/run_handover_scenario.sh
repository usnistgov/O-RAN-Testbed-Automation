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

USE_ZMQ_BROKER=false
SHOW_ZMQ_BROKER_UI=true
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
    if [ "$USE_ZMQ_BROKER" != "true" ]; then
        echo "ERROR: The srsRAN UE requires the ZeroMQ broker with the Duranta gNodeB. It can be enabled with the following commands:"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' User_Equipment/full_install.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' User_Equipment/generate_configurations.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' Next_Generation_Node_B/full_install.sh"
        echo "    sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' Next_Generation_Node_B/generate_configurations.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' run.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' run_handover_scenario.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' run_with_grafana_dashboard.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' run_with_nrscope_gui.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' User_Equipment/run.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' User_Equipment/run_background.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' User_Equipment/run_gdb.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' Next_Generation_Node_B/run.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' Next_Generation_Node_B/run_background.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' Next_Generation_Node_B/run_gdb.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' Next_Generation_Node_B/run_split_du.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' Next_Generation_Node_B/is_running.sh"
        echo "    sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' Next_Generation_Node_B/stop.sh"
        exit 1
    fi
    UE_DIRECTORY="$SCRIPT_DIR/../User_Equipment"
    UE_READY_MESSAGE="PDU Session Establishment successful" # srsRAN_4G
    # UE_READY_MESSAGE="Attaching UE..." # srsRAN_4G
fi

RUN_TELNET_SESSION_AFTER=true
NUM_UES=1
NUM_DUS=2
RUN_XAPP_KPM_MONITOR=false
RUN_GRAFANA_DASHBOARD=false

if [ "$RUN_GRAFANA_DASHBOARD" = true ] && [ "$RUN_XAPP_KPM_MONITOR" = false ]; then
    echo "ERROR: Cannot run Grafana dashboard without running xApp KPM Monitor."
    exit 1
fi

SHOW_TERMINALS=false
while [[ $# -gt 0 ]]; do
    case "$1" in
    show | --show)
        SHOW_TERMINALS=true
        shift
        ;;
    help | -h | --help)
        echo "Usage: $0 [show] [--num-ues N] [--num-dus N] [help|-h|--help]"
        echo "  show           Show logs in new terminals"
        echo "  --num-ues N    Set number of UEs (default: 1)."
        echo "                 Note: RF simulator supports only one UE, while the ZeroMQ broker supports multiple UEs."
        echo "  --num-dus N    Set number of DUs (default: 2)"
        echo "  help, -h       Show this help message"
        exit 0
        ;;
        # NOTE: RF Simulator's client-server architecture does not currently support a virtual multi-UE handover scenario. However, handovers for multiple COTS UEs are supported over the air.
    --num-ues)
        NUM_UES="$2"
        shift 2
        ;;
    --num-dus)
        NUM_DUS="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

if ! [[ "$NUM_UES" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: Number of UEs must be a positive integer."
    exit 1
fi
if ! [[ "$NUM_DUS" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: Number of DUs must be a positive integer."
    exit 1
fi
if [ "$NUM_DUS" = 1 ]; then
    echo "ERROR: Number of UEs must be 1 or more, and number of DUs must be 2 or more."
    exit 1
fi
if [ "$USE_ZMQ_BROKER" != "true" ] && [ "$NUM_UES" != 1 ]; then
    echo "ERROR: The RF simulator handover scenario supports one virtual UE."
    exit 1
fi

cd "$SCRIPT_DIR"

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    mapfile -t BROKER_UE_NUMBERS < <(./Next_Generation_Node_B/install_scripts/get_zmq_broker_config.sh --ues)
    mapfile -t BROKER_CELL_NUMBERS < <(./Next_Generation_Node_B/install_scripts/get_zmq_broker_config.sh --cells)
    if [ "$NUM_UES" != "${#BROKER_UE_NUMBERS[@]}" ] || [ "$NUM_DUS" != "${#BROKER_CELL_NUMBERS[@]}" ]; then
        echo "WARNING: The requested number of UEs or DUs does not match the generated ZeroMQ Broker configuration."
        NUM_UES=${#BROKER_UE_NUMBERS[@]}
        NUM_DUS=${#BROKER_CELL_NUMBERS[@]}
        echo "Using $NUM_UES UE(s) and $NUM_DUS DU(s) from the ZeroMQ broker configuration."
    fi

    BROKER_UE_NUMBERS_STR=$(
        IFS=,
        echo "${BROKER_UE_NUMBERS[*]}"
    )
    BROKER_CELL_NUMBERS_STR=$(
        IFS=,
        echo "${BROKER_CELL_NUMBERS[*]}"
    )
    ./Next_Generation_Node_B/install_scripts/validate_zmq_broker_config.sh --broker-only --ues "$BROKER_UE_NUMBERS_STR" --cells "$BROKER_CELL_NUMBERS_STR"

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
if [ "$USE_ZMQ_BROKER" = "true" ]; then
    echo
    ./install_scripts/run_zmq_broker.sh --show-ui "$SHOW_ZMQ_BROKER_UI"
else
    echo
    echo "Running CU..."
    ./run_background_split_cu.sh
    stty sane || true
    if [ "$SHOW_TERMINALS" = true ]; then
        nohup x-terminal-emulator -T "CU Log" -e bash -c "tail -f logs/split_cu_stdout.txt; exec bash" >/dev/null 2>&1 &
    fi
fi
cd ..

start_ue() {
    UE_ID=$1
    IS_RFSIM_SERVER=$2
    echo
    echo "Running UE $UE_ID..."
    cd "$UE_DIRECTORY"
    if [ "$IS_RFSIM_SERVER" = true ]; then
        ./run_background.sh "$UE_ID" --rfsim-server
    else
        ./run_background.sh "$UE_ID"
    fi
    stty sane || true
    if [ "$SHOW_TERMINALS" = true ]; then
        nohup x-terminal-emulator -T "UE $UE_ID Log" -e bash -c "tail -f logs/ue${UE_ID}_stdout.txt; exec bash" >/dev/null 2>&1 &
    fi

    if [ "$USE_ZMQ_BROKER" = "true" ]; then
        cd "$SCRIPT_DIR"
        return
    fi

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
        if [ -f "logs/ue${UE_ID}_stdout.txt" ] && grep -q "State = NR_RRC_CONNECTED" "logs/ue${UE_ID}_stdout.txt"; then
            break
        elif ! ./is_running.sh | grep -Eq "(^|[ (])ue${UE_ID}([ )]|$)"; then
            echo "ERROR: Could not start UE $UE_ID. Check logs/ue${UE_ID}_stdout.txt for more information."
            exit 1
        fi
    done
    echo -e "\nUE $UE_ID is ready."
    cd "$SCRIPT_DIR"
}

wait_for_ue_to_connect() {
    UE_ID=$1
    LOG_FILE="$UE_DIRECTORY/logs/ue${UE_ID}_stdout.txt"
    echo -en "\nWaiting for UE $UE_ID to establish a PDU session"
    ATTEMPT=0
    while [ ! -f "$LOG_FILE" ] || ! grep -qaF "$UE_READY_MESSAGE" "$LOG_FILE"; do
        stty sane || true
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "UE $UE_ID did not establish a PDU session after 60 seconds, exiting..."
            exit 1
        fi
        if ! "$UE_DIRECTORY/is_running.sh" | grep -Eq "(^|[ (])ue${UE_ID}([ )]|$)" || ! ./Next_Generation_Node_B/is_running.sh | grep -Eq "(^|[ (])du1([ )]|$)"; then
            echo "ERROR: DU 1 or UE $UE_ID may not be running. Check logs for more information."
            exit 1
        fi
    done
    echo -e "\nUE $UE_ID has established a PDU session."
}

NEXT_UE_ID=1
if [ "$USE_ZMQ_BROKER" != "true" ]; then
    RFSIM_SERVER_IP=$(./User_Equipment/install_scripts/get_ue_namespace_ip.sh ue "$NEXT_UE_ID")
    echo "$RFSIM_SERVER_IP" >User_Equipment/configs/get_rfsim_server_address.txt
fi

echo
echo "Running DU 1..."
cd Next_Generation_Node_B
if [ "$USE_ZMQ_BROKER" = "true" ]; then
    ./run_background_split_du.sh 1
else
    ./run_background_split_du.sh 1 --no-rfsim-server
fi
stty sane || true
if [ "$SHOW_TERMINALS" = true ]; then
    nohup x-terminal-emulator -T "DU 1 Log" -e bash -c "tail -f logs/split_du1_stdout.txt; exec bash" >/dev/null 2>&1 &
    if [ "$USE_ZMQ_BROKER" = "true" ]; then
        nohup x-terminal-emulator -T "CU Log" -e bash -c "tail -f logs/split_cu_stdout.txt; exec bash" >/dev/null 2>&1 &
    fi
fi
cd ..

if [ "$USE_ZMQ_BROKER" != "true" ]; then
    # The first UE is the RF simulator server for the DUs
    start_ue "$NEXT_UE_ID" true
    NEXT_UE_ID=$((NEXT_UE_ID + 1))

    echo -en "\nWaiting for DU 1 to be ready"
    cd Next_Generation_Node_B
    ATTEMPT=0
    while ! ./is_du_ready.sh 1 | grep -qx "true"; do
        stty sane || true
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "DU 1 did not start after 60 seconds, exiting..."
            exit 1
        fi
        if ! ./is_running.sh | grep -Eq "(^|[ (])du1([ )]|$)"; then
            echo "ERROR: Could not start DU 1. Check logs/split_du1_stdout.txt for more information."
            exit 1
        fi
    done
    echo -e "\nDU 1 is ready."
    cd ..
fi

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    for DU_ID in "${BROKER_CELL_NUMBERS[@]}"; do
        if [ "$DU_ID" = "1" ]; then
            continue
        fi
        echo
        echo "Running DU $DU_ID..."
        cd Next_Generation_Node_B
        ./run_background_split_du.sh "$DU_ID"
        stty sane || true
        if [ "$SHOW_TERMINALS" = true ]; then
            nohup x-terminal-emulator -T "DU $DU_ID Log" -e bash -c "tail -f logs/split_du${DU_ID}_stdout.txt; exec bash" >/dev/null 2>&1 &
        fi
        cd ..
    done

    for UE_ID in "${BROKER_UE_NUMBERS[@]}"; do
        start_ue "$UE_ID" false
    done

    cd Next_Generation_Node_B
    for DU_ID in "${BROKER_CELL_NUMBERS[@]}"; do
        LOG_FILE="logs/split_du${DU_ID}_stdout.txt"
        echo -en "\nWaiting for DU $DU_ID to be ready"
        ATTEMPT=0
        while ! ./is_du_ready.sh "$DU_ID" | grep -qx "true"; do
            stty sane || true
            echo -n "."
            sleep 0.5
            ATTEMPT=$((ATTEMPT + 1))
            if [ $ATTEMPT -ge 120 ]; then
                echo "DU $DU_ID did not start after 60 seconds, exiting..."
                exit 1
            fi
            if ! ./is_running.sh | grep -Eq "(^|[ (])du${DU_ID}([ )]|$)"; then
                echo "ERROR: Could not start DU $DU_ID. Check $LOG_FILE for more information."
                exit 1
            fi
        done
        echo -e "\nDU $DU_ID is ready."
    done
    cd ..

    for UE_ID in "${BROKER_UE_NUMBERS[@]}"; do
        wait_for_ue_to_connect "$UE_ID"
    done
else
    # Ensure that DU 1 has connected to the UE before proceeding.
    wait_for_ue_to_connect 1
    while [ $NEXT_UE_ID -le "$NUM_UES" ]; do
        start_ue "$NEXT_UE_ID" false
        wait_for_ue_to_connect "$NEXT_UE_ID"
        NEXT_UE_ID=$((NEXT_UE_ID + 1))
    done
fi

if [ "$USE_ZMQ_BROKER" != "true" ]; then
    DU_ID=2
    while [ $DU_ID -le "$NUM_DUS" ]; do
        echo
        echo "Running DU $DU_ID..."
        cd Next_Generation_Node_B
        ./run_background_split_du.sh "$DU_ID" --no-rfsim-server
        stty sane || true
        if [ "$SHOW_TERMINALS" = true ]; then
            nohup x-terminal-emulator -T "DU $DU_ID Log" -e bash -c "tail -f logs/split_du${DU_ID}_stdout.txt; exec bash" >/dev/null 2>&1 &
        fi

        echo -en "\nWaiting for DU $DU_ID to be ready"
        ATTEMPT=0
        while ! ./is_du_ready.sh "$DU_ID" | grep -qx "true"; do
            stty sane || true
            echo -n "."
            sleep 0.5
            ATTEMPT=$((ATTEMPT + 1))
            if [ $ATTEMPT -ge 120 ]; then
                echo "DU $DU_ID did not start after 60 seconds, exiting..."
                exit 1
            fi
            if ! ./is_running.sh | grep -Eq "(^|[ (])du${DU_ID}([ )]|$)"; then
                echo "ERROR: Could not start DU $DU_ID. Check logs/split_du${DU_ID}_stdout.txt for more information."
                exit 1
            fi
        done
        echo -e "\nDU $DU_ID is ready."
        cd ..
        DU_ID=$((DU_ID + 1))
    done
fi

if [ "$RUN_XAPP_KPM_MONITOR" = true ]; then
    echo
    echo "Running xApp KPM Monitor in Background..."
    cd RAN_Intelligent_Controllers/Flexible-RIC/additional_scripts

    # Send metrics to CSV (Grafana dashboard provided)
    if [ "$RUN_GRAFANA_DASHBOARD" = true ]; then
        nohup ./start_grafana_with_csv_xapp_kpm_moni.sh >../logs/xapp_kpm_moni_stdout.txt 2>&1 &
    else
        nohup ./run_xapp_kpm_moni_write_to_csv.sh >../logs/xapp_kpm_moni_stdout.txt 2>&1 &
    fi
    if [ "$SHOW_TERMINALS" = true ]; then
        nohup x-terminal-emulator -T "xApp KPM Monitor Log" -e bash -c "tail -f ../logs/xapp_kpm_moni_stdout.txt; exec bash" >/dev/null 2>&1 &
    fi
    cd ../../..
fi

echo
echo
echo "Successfully started all components."
echo
echo
./is_running.sh

if [ "$RUN_TELNET_SESSION_AFTER" = true ]; then
    # if ! command -v rlwrap &>/dev/null; then
    #     echo "Package \"rlwrap\" not found, installing..."
    #     sudo env $APTVARS apt-get install -y rlwrap
    # fi

    # mkdir -p logs
    # sudo chown --recursive "${SUDO_USER:-$USER}" logs
    # LOG_FILE="logs/telnet.log"
    # HIST_FILE="logs/telnet_history"

    # exec 3<>/dev/tcp/127.0.0.1/9099
    # echo help >&3
    # stdbuf -o0 -i0 -e0 cat <&3 | stdbuf -o0 -i0 -e0 tee -a "$LOG_FILE" &
    # READER_PID=$!
    # trap 'exec 3<&-; exec 3>&-; kill "$READER_PID" 2>/dev/null' EXIT
    # echo "Connected to the CU telnet session."

    # rlwrap -H "$HIST_FILE" bash -c '
    #     while IFS= read -r line; do
    #         printf "%s\r\n" "$line" >&3
    #     done
    # ' 3>&3

    echo
    echo
    echo
    echo "Starting telnet session to CU..."
    echo "    Type 'help' for a list of commands."
    echo "    Type 'ci trigger_f1_ho 1' to trigger a handover for UE 1 from DU 1 to DU 2."
    echo

    # Open a single persistent connection for help and interactive session
    exec 3<>/dev/tcp/127.0.0.1/9099
    echo help >&3
    cat <&3 &
    echo "Connected to the CU telnet session."
    # Forward user input to the telnet session
    cat >&3
    # Close the connection when done
    exec 3<&-
    exec 3>&-
else
    echo "Successfully started all components. Waiting for user to terminate the script (press Ctrl+C to exit)..."
    while true; do
        sleep 10
    done
fi

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

SCRIPT_DIR=$(dirname "$(realpath "$0")")

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
        echo "Usage: $0 [show] [--num-dus N] [help|-h|--help]"
        echo "  show           Show logs in new terminals"
        echo "  --num-dus N    Set number of DUs (default: 2)"
        echo "  help, -h       Show this help message"
        exit 0
        ;;
    # NOTE: RF Simulator's client-server architecture does not currently support a virtual multi-UE handover scenario. However, handovers for multiple COTS UEs are supported over the air.
    # --num-ues)
    #     NUM_UES="$2"
    #     shift 2
    #     ;;
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

if [ "$NUM_UES" -lt 0 ] || [ "$NUM_DUS" -lt 2 ]; then
    echo "ERROR: Number of UEs must be 0 or more, and number of DUs must be 2 or more."
    exit 1
fi

cd "$SCRIPT_DIR"

# Upon exit, gracefully stop all components and fix console in case it breaks
trap 'trap - EXIT SIGINT SIGTERM; echo "#################################  STOPPING... #################################"; "$SCRIPT_DIR/./stop.sh"; stty sane; exit' EXIT SIGINT SIGTERM

echo "Running 5G Core components..."
cd 5G_Core_Network
./run.sh
cd ..

echo
echo "Running FlexRIC..."
cd RAN_Intelligent_Controllers/Flexible-RIC
./run_background.sh

if $(./is_running.sh | grep -q "NOT_RUNNING"); then
    echo "Error starting FlexRIC."
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

echo
echo "Running CU..."
cd Next_Generation_Node_B
./run_background_split_cu.sh
if [ "$SHOW_TERMINALS" = true ]; then
    gnome-terminal --title="CU Log" -- bash -c "tail -f logs/split_cu_stdout.txt; exec bash"
fi
cd ..

start_ue() {
    UE_ID=$1
    IS_RFSIM_SERVER=$2
    echo
    echo "Running UE $UE_ID..."
    cd User_Equipment
    if [ "$IS_RFSIM_SERVER" = true ]; then
        ./run_background.sh "$UE_ID" --rfsim-server
    else
        ./run_background.sh "$UE_ID"
    fi
    if [ "$SHOW_TERMINALS" = true ]; then
        gnome-terminal --title="UE $UE_ID Log" -- bash -c "tail -f logs/ue${UE_ID}_stdout.txt; exec bash"
    fi

    echo -en "\nWaiting for UE $UE_ID to be ready"
    ATTEMPT=0
    while [ ! -f logs/ue${UE_ID}_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/ue${UE_ID}_stdout.txt; do
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "UE $UE_ID did not start after 60 seconds, exiting..."
            exit 1
        fi
        if grep -q "State = NR_RRC_CONNECTED" logs/ue${UE_ID}_stdout.txt; then
            break
        elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
            echo "Error starting UE $UE_ID. Check logs/ue${UE_ID}_stdout.txt for more information."
            exit 1
        fi
    done
    echo -e "\nUE $UE_ID is ready."
    cd ..
}

wait_for_ue_to_connect_to_du_1() {
    UE_ID=$1
    echo -en "\nWaiting for UE $UE_ID to connect to DU 1"
    ATTEMPT=0
    while [ ! -f User_Equipment/logs/ue${UE_ID}_stdout.txt ] || ! grep -q "Received PDU Session Establishment Accept," User_Equipment/logs/ue${UE_ID}_stdout.txt; do
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "UE $UE_ID did not connect to DU 1 after 60 seconds, exiting..."
            exit 1
        fi
        if grep -q "Received PDU Session Establishment Accept," User_Equipment/logs/ue${UE_ID}_stdout.txt; then
            break
        elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
            echo "ERROR: DU 1 or UE $UE_ID may not be running. Check logs for more information."
            exit 1
        fi
    done
    echo -e "\nUE $UE_ID has connected to DU 1."
}

# Start the first UE since it will be the RF simulator server for the DUs
NEXT_UE_ID=1
start_ue $NEXT_UE_ID true
NEXT_UE_ID=$((NEXT_UE_ID + 1))

echo
echo "Running DU 1..."
cd Next_Generation_Node_B
./run_background_split_du.sh 1 --no-rfsim-server
if [ "$SHOW_TERMINALS" = true ]; then
    gnome-terminal --title="DU 1 Log" -- bash -c "tail -f logs/split_du1_stdout.txt; exec bash"
fi
cd ..

echo -en "\nWaiting for DU 1 to be ready"
cd Next_Generation_Node_B
ATTEMPT=0
while [ ! -f logs/split_du1_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/split_du1_stdout.txt; do
    echo -n "."
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 120 ]; then
        echo "DU 1 did not start after 60 seconds, exiting..."
        exit 1
    fi
    if grep -q "TYPE <CTRL-C> TO TERMINATE" logs/split_du1_stdout.txt; then
        break
    elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
        echo "Error starting DU 1. Check logs/split_du1_stdout.txt for more information."
        exit 1
    fi
done
echo -e "\nDU 1 is ready."
cd ..

# Ensure that DU 1 has connected to the UE before proceeding
wait_for_ue_to_connect_to_du_1 1

if [ "$NUM_UES" -gt 0 ]; then
    while [ $NEXT_UE_ID -le "$NUM_UES" ]; do
        start_ue "$NEXT_UE_ID" false
        wait_for_ue_to_connect_to_du_1 "$NEXT_UE_ID"
        NEXT_UE_ID=$((NEXT_UE_ID + 1))
    done
fi

DU_ID=2
while [ $DU_ID -le "$NUM_DUS" ]; do
    echo
    echo "Running DU $DU_ID..."
    cd Next_Generation_Node_B
    ./run_background_split_du.sh "$DU_ID" --no-rfsim-server
    if [ "$SHOW_TERMINALS" = true ]; then
        gnome-terminal --title="DU $DU_ID Log" -- bash -c "tail -f logs/split_du${DU_ID}_stdout.txt; exec bash"
    fi

    echo -en "\nWaiting for DU $DU_ID to be ready"
    ATTEMPT=0
    while [ ! -f logs/split_du${DU_ID}_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/split_du${DU_ID}_stdout.txt; do
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "DU $DU_ID did not start after 60 seconds, exiting..."
            exit 1
        fi
        if grep -q "TYPE <CTRL-C> TO TERMINATE" logs/split_du${DU_ID}_stdout.txt; then
            break
        elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
            echo "Error starting DU $DU_ID. Check logs/split_du${DU_ID}_stdout.txt for more information."
            exit 1
        fi
    done
    echo -e "\nDU $DU_ID is ready."
    cd ..
    DU_ID=$((DU_ID + 1))
done

if [ "$RUN_XAPP_KPM_MONITOR" = true ]; then
    echo
    echo "Running xApp KPM Monitor in Background..."
    cd RAN_Intelligent_Controllers/Flexible-RIC/additional_scripts

    # Send metrics to CSV (Grafana dashboard provided)
    if [ "$RUN_GRAFANA_DASHBOARD" = true ]; then
        nohup ./start_grafana_with_csv_xapp_kpm_moni.sh >../logs/xapp_kpm_moni_stdout.txt 2>&1 &
    else
        nohup ./run_xapp_kpm_moni.sh >../logs/xapp_kpm_moni_stdout.txt 2>&1 &
    fi
    if [ "$SHOW_TERMINALS" = true ]; then
        gnome-terminal --title="xApp KPM Monitor Log" -- bash -c "tail -f ../logs/xapp_kpm_moni_stdout.txt; exec bash"
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
    # sudo chown --recursive "$USER" logs
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

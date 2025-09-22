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

SHOW_TERMINALS=false
if [ "$1" == "show" ]; then
    SHOW_TERMINALS=true
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
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

echo
echo "Running DU 1..."
cd Next_Generation_Node_B
./run_background_split_du.sh 1 --no-rfsim-server
if [ "$SHOW_TERMINALS" = true ]; then
    gnome-terminal --title="DU 1 Log" -- bash -c "tail -f logs/split_du1_stdout.txt; exec bash"
fi

echo -en "\nWaiting for DU 1 to be ready"
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

echo
echo "Running User Equipment..."
cd User_Equipment
./run_background.sh 1 --rfsim-server
if [ "$SHOW_TERMINALS" = true ]; then
    gnome-terminal --title="UE 1 Log" -- bash -c "tail -f logs/ue1_stdout.txt; exec bash"
fi

echo -en "\nWaiting for UE to be ready"
ATTEMPT=0
while [ ! -f logs/ue1_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/ue1_stdout.txt; do
    echo -n "."
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 120 ]; then
        echo "UE did not start after 60 seconds, exiting..."
        exit 1
    fi
    if grep -q "State = NR_RRC_CONNECTED" logs/ue1_stdout.txt; then
        break
    elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
        echo "Error starting UE. Check logs/ue1_stdout.txt for more information."
        exit 1
    fi
done
echo -e "\nUE is ready."
cd ..

# Ensure that DU 1 has connected to the UE before starting DU 2
cd Next_Generation_Node_B
echo -en "\nWaiting for UE to connect to DU 1"
ATTEMPT=0
while [ ! -f ../User_Equipment/logs/ue1_stdout.txt ] || ! grep -q "Received PDU Session Establishment Accept," ../User_Equipment/logs/ue1_stdout.txt; do
    echo -n "."
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 120 ]; then
        echo "UE did not connect to DU 1 after 60 seconds, exiting..."
        exit 1
    fi
    if grep -q "Received PDU Session Establishment Accept," ../User_Equipment/logs/ue1_stdout.txt; then
        break
    elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
        echo "Error: DU 1 or UE may not be running. Check logs for more information."
        exit 1
    fi
done
echo -e "\nUE has connected to DU 1."
cd ..

echo
echo "Running DU 2..."
cd Next_Generation_Node_B
./run_background_split_du.sh 2 --no-rfsim-server
if [ "$SHOW_TERMINALS" = true ]; then
    gnome-terminal --title="DU 2 Log" -- bash -c "tail -f logs/split_du2_stdout.txt; exec bash"
fi

echo -en "\nWaiting for DU 2 to be ready"
ATTEMPT=0
while [ ! -f logs/split_du2_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/split_du2_stdout.txt; do
    echo -n "."
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 120 ]; then
        echo "DU 2 did not start after 60 seconds, exiting..."
        exit 1
    fi
    if grep -q "TYPE <CTRL-C> TO TERMINATE" logs/split_du2_stdout.txt; then
        break
    elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
        echo "Error starting DU 2. Check logs/split_du2_stdout.txt for more information."
        exit 1
    fi
done
echo -e "\nDU 2 is ready."
cd ..

echo "Successfully started all components."
echo
./is_running.sh

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

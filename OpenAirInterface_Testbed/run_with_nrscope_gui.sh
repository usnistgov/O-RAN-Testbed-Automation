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
cd "$SCRIPT_DIR"

if [ ! -f "Next_Generation_Node_B/openairinterface5g/cmake_targets/ran_build/build/libimscope.so" ]; then
    echo "ERROR: Library libimscope.so not found. Please install the gNB with NRSCOPE_GUI set to true."
    exit 1
fi

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
echo "Running UE..."
UE_ID=1
cd User_Equipment
./run_background.sh "$UE_ID"
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

echo
echo "Running gNB..."
cd Next_Generation_Node_B
./run.sh

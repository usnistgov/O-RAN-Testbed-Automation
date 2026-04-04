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

sudo -v # Ensure sudo session is active

# Upon exit, gracefully stop all components and fix console in case it breaks
trap 'trap - EXIT SIGINT SIGTERM; echo "#################################  STOPPING... #################################"; "$SCRIPT_DIR/./stop.sh"; stty sane || true; exit' EXIT SIGINT SIGTERM

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
echo "Running gNodeB..."
cd Next_Generation_Node_B
./run_background.sh

echo -en "\nWaiting for gNodeB to be ready"
ATTEMPT=0
while [ ! -f logs/gnb_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/gnb_stdout.txt; do
    echo -n "."
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 120 ]; then
        echo "gNodeB did not start after 60 seconds, exiting..."
        exit 1
    fi
    if grep -q "TYPE <CTRL-C> TO TERMINATE" logs/gnb_stdout.txt; then
        break
    elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
        echo "Error starting gNodeB. Check logs/gnb_stdout.txt for more information."
        stty sane || true
        exit 1
    fi
done
stty sane || true
echo -e "\ngNodeB is ready."
cd ..

echo
echo "Running User Equipment 1..."
cd User_Equipment
./run_background.sh 1

echo -en "\nWaiting for UE 1 to be ready"
ATTEMPT=0
while [ ! -f logs/ue1_stdout.txt ] || ! grep -q "TYPE <CTRL-C> TO TERMINATE" logs/ue1_stdout.txt; do
    echo -n "."
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 120 ]; then
        echo "UE 1 did not start after 60 seconds, exiting..."
        stty sane || true
        exit 1
    fi
    if grep -q "State = NR_RRC_CONNECTED" logs/ue1_stdout.txt; then
        break
    elif ! ./is_running.sh | grep -E "^User Equipment:" | grep -q "ue1"; then
        echo "Error starting UE 1. Check logs/ue1_stdout.txt for more information."
        stty sane || true
        exit 1
    fi
done
stty sane || true
echo -e "\nUE 1 is ready."
cd ..

echo
echo "Running xApp KPM Monitor to generate CSV metrics..."
cd RAN_Intelligent_Controllers/Flexible-RIC/additional_scripts
sudo bash -c "nohup ./run_xapp_kpm_moni_write_to_csv.sh </dev/null > ../logs/xapp_kpm_moni_stdout.txt 2>&1 &"
cd ../../..

echo
echo "Waiting 10 seconds after UE 1 connect to establish baseline..."
sleep 10

echo
echo "Connecting UE 2..."
cd User_Equipment
./run_background.sh 2
cd ..
stty sane || true
sleep 10

echo
echo "Connecting UE 3..."
cd User_Equipment
./run_background.sh 3
cd ..
stty sane || true
sleep 10

# Traffic: UE to Core
echo
echo "Generating UE 1 traffic to core (1M for 25s) & waiting 4s..."
sudo nohup ./User_Equipment/additional_scripts/simulate_ue_traffic_to_core.sh "1" "1M" "25" </dev/null >/dev/null 2>&1 &
sleep 4

echo "Generating UE 2 traffic to core (4M for 21s) & waiting 4s..."
sudo nohup ./User_Equipment/additional_scripts/simulate_ue_traffic_to_core.sh "2" "4M" "21" </dev/null >/dev/null 2>&1 &
sleep 4

echo "Generating UE 3 traffic to core (8M for 17s)..."
sudo nohup ./User_Equipment/additional_scripts/simulate_ue_traffic_to_core.sh "3" "8M" "17" </dev/null >/dev/null 2>&1 &

echo "Waiting for traffic to finish (17s)..."
sleep 17
echo "Waiting 4 seconds..."
sleep 4

# Traffic: Core to UE
echo
echo "Generating Core to UE 1 traffic (1M for 25s) & waiting 4s..."
sudo nohup ./User_Equipment/additional_scripts/simulate_core_traffic_to_ue.sh "1" "1M" "25" </dev/null >/dev/null 2>&1 &
sleep 4

echo "Generating Core to UE 2 traffic (4M for 21s) & waiting 4s..."
sudo nohup ./User_Equipment/additional_scripts/simulate_core_traffic_to_ue.sh "2" "4M" "21" </dev/null >/dev/null 2>&1 &
sleep 4

echo "Generating Core to UE 3 traffic (8M for 17s)..."
sudo nohup ./User_Equipment/additional_scripts/simulate_core_traffic_to_ue.sh "3" "8M" "17" </dev/null >/dev/null 2>&1 &

echo "Waiting for traffic to finish (17s)..."
sleep 17
echo "Waiting 4 seconds..."
sleep 4

# Connect more UEs
echo
echo "Connecting UE 4..."
cd User_Equipment
./run_background.sh 4
cd ..
stty sane || true
sleep 5

echo
echo "Connecting UE 5..."
cd User_Equipment
./run_background.sh 5
cd ..
stty sane || true
sleep 5

echo
echo "Connecting UE 6..."
cd User_Equipment
./run_background.sh 6
cd ..
stty sane || true
sleep 5

echo
echo "Waiting 4 seconds before bulk traffic..."
sleep 4

function run_bulk_traffic {
    local DIR=$1
    local BW=$2
    local DUR=$3
    echo "All UEs generating $BW $DIR traffic for $DUR seconds..."
    for i in {1..6}; do
        if [ "$DIR" == "uplink" ]; then
            sudo nohup ./User_Equipment/additional_scripts/simulate_ue_traffic_to_core.sh "$i" "$BW" "$DUR" </dev/null >/dev/null 2>&1 &
        else
            sudo nohup ./User_Equipment/additional_scripts/simulate_core_traffic_to_ue.sh "$i" "$BW" "$DUR" </dev/null >/dev/null 2>&1 &
        fi
    done
    sleep "$DUR"
}

run_bulk_traffic "uplink" "1M" "10"
run_bulk_traffic "downlink" "1M" "10"

run_bulk_traffic "uplink" "2M" "10"
run_bulk_traffic "downlink" "2M" "10"

run_bulk_traffic "uplink" "4M" "10"
run_bulk_traffic "downlink" "4M" "10"

echo
echo "All UEs generating 1M of both uplink and downlink for 60 seconds..."
for i in {1..6}; do
    sudo nohup ./User_Equipment/additional_scripts/simulate_ue_traffic_to_core.sh "$i" "1M" "60" </dev/null >/dev/null 2>&1 &
    sudo nohup ./User_Equipment/additional_scripts/simulate_core_traffic_to_ue.sh "$i" "1M" "60" </dev/null >/dev/null 2>&1 &
done

echo "Waiting for final 60-second traffic burst to complete..."
sleep 60

echo "Traffic ended. Waiting 10 seconds to capture final idle state..."
sleep 10

echo "Stopping xApp KPM Monitor to freeze CSV state with 6 UEs connected..."
sudo pkill -INT -f "xapp_kpm_moni" || true
cd "$SCRIPT_DIR/RAN_Intelligent_Controllers/Flexible-RIC/additional_scripts"
sudo ./stop_grafana_and_python_server.sh &>/dev/null || true
cd "$SCRIPT_DIR"

echo "Waiting 2 seconds for CSV cache to flush..."
sleep 2

echo "Successfully completed traffic generation and KPI metrics collection scenario."

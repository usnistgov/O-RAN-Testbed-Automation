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
BASE_DIR=$(dirname "$SCRIPT_DIR")

TEST_RESULTS_DIR="$SCRIPT_DIR/5.3_test_results"
sudo rm -rf "$TEST_RESULTS_DIR"
mkdir -p "$TEST_RESULTS_DIR"

CSV_FILE="$TEST_RESULTS_DIR/test_results.csv"
echo "UNIX Epoch,Test Index,Test Result" > "$CSV_FILE"

cd "$BASE_DIR"

echo "Stopping any running components from previous runs..."
./stop.sh

echo
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

for i in {1..10}; do
    echo
    echo "################################################################################"
    echo "############################## Starting Test Run $i #############################"
    echo "################################################################################"

    IS_TEST_SUCCESS=false

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
            echo "gNodeB did not start after 60 seconds."
            exit 1
        fi
        if grep -q "TYPE <CTRL-C> TO TERMINATE" logs/gnb_stdout.txt; then
            break
        elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
            echo "Error starting gNodeB. Check logs/gnb_stdout.txt for more information."
            exit 1
        fi
    done
    echo -e "\ngNodeB is ready."
    cd ..

    echo
    echo "Running User Equipment..."
    cd User_Equipment
    ./run_background.sh
    echo -en "\nWaiting for UE to be ready"
    ATTEMPT=0
    UE_READY=false
    while true; do
        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "UE did not start after 60 seconds."
            break
        fi
        if grep -q "State = NR_RRC_CONNECTED" logs/ue1_stdout.txt && grep -q "Received PDU Session Establishment Accept" logs/ue1_stdout.txt; then
            UE_READY=true
            break
        elif $(./is_running.sh | grep -q "NOT_RUNNING"); then
            echo "Error starting UE. Check logs/ue1_stdout.txt for more information."
            break
        fi
    done
    
    if [ "$UE_READY" = true ]; then
        echo -e "\nUE is ready and connected. Starting traffic for three minutes..."
        ./additional_scripts/simulate_ue_traffic_to_core.sh 1 1M 10 # 180
        IS_TEST_SUCCESS=true
    else
        echo -e "\nUE failed to connect."
    fi
    cd ..

    # Stop components for next run
    echo "Stopping UE..."
    cd User_Equipment
    ./stop.sh
    cd ..

    sleep 5

    echo "Stopping gNodeB..."
    cd Next_Generation_Node_B
    ./stop.sh
    cd ..
    
    # Save logs from this test run
    if [ -f Next_Generation_Node_B/logs/gnb_stdout.txt ]; then
        cp Next_Generation_Node_B/logs/gnb_stdout.txt "$TEST_RESULTS_DIR/test_${i}_gnb.log"
        sudo tee Next_Generation_Node_B/logs/gnb_stdout.txt >/dev/null <<< ""
    else
        echo "No gNB log found"
        touch "$TEST_RESULTS_DIR/test_${i}_gnb.log"
    fi
    if [ -f User_Equipment/logs/ue1_stdout.txt ]; then
        cp User_Equipment/logs/ue1_stdout.txt "$TEST_RESULTS_DIR/test_${i}_ue.log"
        sudo tee User_Equipment/logs/ue1_stdout.txt >/dev/null <<< ""
    else
        echo "No UE log found"
        touch "$TEST_RESULTS_DIR/test_${i}_ue.log"
    fi
    if [ -f 5G_Core_Network/logs/amf.log ]; then
        cp 5G_Core_Network/logs/amf.log "$TEST_RESULTS_DIR/test_${i}_amf.log"
        sudo tee 5G_Core_Network/logs/amf.log >/dev/null <<< ""
    else
        echo "No AMF log found"
        touch "$TEST_RESULTS_DIR/test_${i}_amf.log"
    fi

    # Record test result to CSV
    if [ "$IS_TEST_SUCCESS" = true ]; then
        echo "Test Run $i: SUCCESS"
        RESULT="SUCCESS"
    else
        echo "Test Run $i: FAILURE"
        RESULT="FAIL"
    fi
    echo "$(date +%s),$i,$RESULT" >> "$CSV_FILE"

    sleep 5
done

./stop.sh

echo
echo "Tests scenario 5.3 completed."
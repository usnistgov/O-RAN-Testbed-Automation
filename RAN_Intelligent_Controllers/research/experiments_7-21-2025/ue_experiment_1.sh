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

set +e

# Scenario 1: O-RAN Software Community Near-RT RIC with srsRAN gNB and OAI CN

NUM_SAMPLES=100

SCRIPT_DIR=$(dirname "$(realpath "$0")")
BASE_DIR=$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")

trap '"$BASE_DIR"/stop.sh; stty sane; exit' SIGINT

UE_DIR="$BASE_DIR/User_Equipment"
LOG_FILE="$UE_DIR/logs/ue1_stdout.txt"
OUT_FILE="$SCRIPT_DIR/ue_experiment_1.txt"

# Start fresh output file
if [ ! -f "$OUT_FILE" ]; then
    : >"$OUT_FILE"
fi

restart_other_components() {
    cd "$BASE_DIR"
    ./stop.sh

    yq eval -i '.core_to_use = "5gdeploy-oai"' 5G_Core_Network/options.yaml
    ./generate_configurations.sh

    cd "$BASE_DIR"
    echo "Running 5G Core components..."
    cd 5G_Core_Network
    ./run.sh
    cd ..

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

    echo "Starting UE experiment in 5 seconds..."
    sleep 5
}

restart_other_components

for ((i = 1; i <= NUM_SAMPLES; i++)); do
    cd "$UE_DIR"
    ./run_background.sh

    while [ ! -f "$LOG_FILE" ]; do
        sleep 0.1
    done
    START_TIME=$(date +%s.%N)
    FOUND=0
    for ((j = 1; j <= 600; j++)); do
        if grep -q -F "PDU Session" "$LOG_FILE"; then
            FOUND=1
            break
        fi
        sleep 0.1
    done
    if [ "$FOUND" -ne 1 ]; then
        echo "Sample $i: PDU Session not established within 60 seconds, redoing sample..."
        ./stop.sh
        restart_other_components
        i=$((i - 1))
        continue
    fi
    END_TIME=$(date +%s.%N)

    DURATION=$(awk -v s="$START_TIME" -v e="$END_TIME" 'BEGIN { print (e - s) }')
    echo "Saving sample $i duration: $DURATION"
    echo "$DURATION" >>"$OUT_FILE"

    ./stop.sh

    cd "$BASE_DIR/Next_Generation_Node_B"
    ./stop.sh
    ./run_background.sh

    stty sane
    sleep 5
done

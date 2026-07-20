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

NUMBER_OF_UES=3
NUMBER_OF_CELLS=2
JAMMER_UE_NUMBER=3

SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(realpath "$SCRIPT_DIR/../../..")
OAI_TESTBED_DIR="$ROOT_DIR/OpenAirInterface_Testbed"
JAMMER_RUNNER="$SCRIPT_DIR/run_partial_band_interference_n78_with_random_control.sh"
JAMMER_LOG="/tmp/partial_band_interference_n78_with_random_control_$$.log"

if ! [[ "$NUMBER_OF_UES" =~ ^[1-9][0-9]*$ ]] ||
    ! [[ "$NUMBER_OF_CELLS" =~ ^[1-9][0-9]*$ ]] ||
    ! [[ "$JAMMER_UE_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: UE, cell, and jammer UE numbers must be positive integers."
    exit 1
fi
if [ "$JAMMER_UE_NUMBER" -gt "$NUMBER_OF_UES" ]; then
    echo "ERROR: JAMMER_UE_NUMBER must be included in NUMBER_OF_UES."
    exit 1
fi
if [ "$JAMMER_UE_NUMBER" -ne 3 ]; then
    echo "ERROR: The partial-band jammer is configured as UE 3."
    exit 1
fi

echo "Select the testbed to run:"
echo "1) OCUDU"
echo "2) OpenAirInterface"
read -r -p "Selection [1-2]: " TESTBED_SELECTION

case "$TESTBED_SELECTION" in
1)
    TESTBED_DIR="$ROOT_DIR"
    TESTBED_NAME="OCUDU"
    ;;
2)
    TESTBED_DIR="$OAI_TESTBED_DIR"
    TESTBED_NAME="OpenAirInterface"
    ;;
*)
    echo "ERROR: Enter 1 or 2."
    exit 1
    ;;
esac

UE_NUMBERS=""
for ((UE_NUMBER = 1; UE_NUMBER <= NUMBER_OF_UES; UE_NUMBER++)); do
    UE_NUMBERS="${UE_NUMBERS:+$UE_NUMBERS,}$UE_NUMBER"
done

CELL_NUMBERS=""
for ((CELL_NUMBER = 1; CELL_NUMBER <= NUMBER_OF_CELLS; CELL_NUMBER++)); do
    CELL_NUMBERS="${CELL_NUMBERS:+$CELL_NUMBERS,}$CELL_NUMBER"
done

sed -i 's/^USE_ZMQ_BROKER=.*$/USE_ZMQ_BROKER=true/' \
    "$ROOT_DIR/generate_configurations.sh" \
    "$ROOT_DIR/run.sh"
sed -i 's/^RADIO_TYPE=.*$/RADIO_TYPE="ZMQ" # Set to "SIMU", "ZMQ", or "USRP"/' \
    "$OAI_TESTBED_DIR/Next_Generation_Node_B/generate_configurations.sh" \
    "$OAI_TESTBED_DIR/User_Equipment/generate_configurations.sh"
sed -i 's/^USE_ZMQ_BROKER=.*$/USE_ZMQ_BROKER=true/' \
    "$OAI_TESTBED_DIR/run.sh" \
    "$OAI_TESTBED_DIR/Next_Generation_Node_B/is_running.sh" \
    "$OAI_TESTBED_DIR/Next_Generation_Node_B/run_split_du.sh" \
    "$OAI_TESTBED_DIR/Next_Generation_Node_B/stop.sh" \
    "$OAI_TESTBED_DIR/User_Equipment/run_background.sh"

sudo -v

echo "Generating OCUDU configurations..."
cd "$ROOT_DIR"
./generate_configurations.sh --ues "$UE_NUMBERS" --cells "$CELL_NUMBERS"

echo
echo "Generating OpenAirInterface configurations..."
cd "$OAI_TESTBED_DIR"
./generate_configurations.sh --ues "$UE_NUMBERS" --cells "$CELL_NUMBERS"

read -r _ _ JAMMER_TX_PORT _ _ < <(
    "$ROOT_DIR/Next_Generation_Node_B/install_scripts/get_zmq_broker_config.sh" --ue "$JAMMER_UE_NUMBER"
)

JAMMER_PID=""
trap '
    EXIT_STATUS=$?
    trap - EXIT SIGINT SIGTERM
    if [ -n "${JAMMER_PID:-}" ] && kill -0 "$JAMMER_PID" 2>/dev/null; then
        kill -INT -- "-$JAMMER_PID" 2>/dev/null || true
        wait "$JAMMER_PID" 2>/dev/null || true
    fi
    stty sane || true
    exit "$EXIT_STATUS"
' EXIT SIGINT SIGTERM

echo
echo "Starting jammer as UE $JAMMER_UE_NUMBER..."
sudo -v
set -m
"$JAMMER_RUNNER" >"$JAMMER_LOG" 2>&1 &
JAMMER_PID=$!
set +m

echo -n "Waiting for jammer"
ATTEMPT=0
while ! sudo ip netns exec "ue$JAMMER_UE_NUMBER" ss -ltnH 2>/dev/null |
    awk '{print $4}' | grep -Eq ":${JAMMER_TX_PORT}$"; do
    if ! kill -0 "$JAMMER_PID" 2>/dev/null; then
        echo
        echo "ERROR: The jammer exited before its ZeroMQ was ready."
        tail -n 20 "$JAMMER_LOG" || true
        exit 1
    fi
    echo -n "."
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ "$ATTEMPT" -ge 120 ]; then
        echo
        echo "ERROR: The jammer did not start after 60 seconds."
        tail -n 20 "$JAMMER_LOG" || true
        exit 1
    fi
done
echo " ready."

echo
echo "Running $TESTBED_NAME with UEs $UE_NUMBERS and cells $CELL_NUMBERS..."
echo "UE $JAMMER_UE_NUMBER is provided by the jammer. Log: $JAMMER_LOG"
cd "$TESTBED_DIR"
./run.sh

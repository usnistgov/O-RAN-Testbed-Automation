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

set -e

JAMMER_UE_NUMBER=3
SHOW_JAMMER_UI=false

SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(realpath "$SCRIPT_DIR/../../..")
UE_DIRECTORY="$ROOT_DIR/User_Equipment"
CHANNEL_EMULATOR_FILE="$ROOT_DIR/Next_Generation_Node_B/zmq_channel_emulator/zmq_channel_emulator.py"
JAMMER_SCRIPT="$SCRIPT_DIR/partial_band_interference_n78_with_random_control.py"

if [ ! -f "$CHANNEL_EMULATOR_FILE" ] ||
    ! grep -q "^# UE_CONFIG: 3 2300 2301 10.201.0.14$" "$CHANNEL_EMULATOR_FILE"; then
    echo "UE 3 is not configured in the ZeroMQ channel emulator."
    echo "Run ./generate_configurations.sh --ues 1,2,3 --cells 1,2 first."
    exit 1
fi

sudo -v
sudo "$UE_DIRECTORY/install_scripts/setup_ue_namespace.sh" "$JAMMER_UE_NUMBER"

trap '
    EXIT_STATUS=$?
    trap - EXIT SIGINT SIGTERM
    if sudo ip netns list | grep -qE "^ue${JAMMER_UE_NUMBER}( |$)"; then
        sudo "$UE_DIRECTORY/install_scripts/revert_ue_namespace.sh" "$JAMMER_UE_NUMBER" || true
    fi
    exit "$EXIT_STATUS"
' EXIT SIGINT SIGTERM

cd "$SCRIPT_DIR"
RUN_USER=${SUDO_USER:-$USER}
RUN_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)

if [ "$SHOW_JAMMER_UI" = "true" ]; then
    sudo ip netns exec "ue$JAMMER_UE_NUMBER" sudo -u "$RUN_USER" env \
        HOME="$RUN_HOME" DISPLAY="${DISPLAY:-:0}" \
        XAUTHORITY="${XAUTHORITY:-$RUN_HOME/.Xauthority}" \
        python3 "$JAMMER_SCRIPT"
else
    sudo ip netns exec "ue$JAMMER_UE_NUMBER" sudo -u "$RUN_USER" env \
        HOME="$RUN_HOME" QT_QPA_PLATFORM=offscreen python3 "$JAMMER_SCRIPT"
fi

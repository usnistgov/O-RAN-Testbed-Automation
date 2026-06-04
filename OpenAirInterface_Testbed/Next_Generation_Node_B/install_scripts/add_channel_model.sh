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

# The script directory respects symbolic links so that the gNB and UE can patch their own openairinterface5g
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PARENT_DIR"

CONFIGURATION_PATH="configs/channelmod_rfsimu.conf"
MODEL_NAME="$1"

if [ -z "$MODEL_NAME" ]; then
    echo "Usage: $0 <model_name>"
    exit 1
fi

if grep -q "model_name[[:space:]]*=[[:space:]]*\"$MODEL_NAME\"" "$CONFIGURATION_PATH" 2>/dev/null; then
    exit 0
fi

REF_MODEL="rfsimu_channel_enB0"
if [[ "$MODEL_NAME" == *"ue"* ]]; then
    REF_MODEL="rfsimu_channel_ue0"
fi

# Find line starting with { right above the model name
START_LINE=$(grep -B 1 -n "$REF_MODEL" "$CONFIGURATION_PATH" | head -n 1 | cut -d- -f1)

# Find line closing with } after the starting line
END_LINE=$(tail -n +$START_LINE "$CONFIGURATION_PATH" | grep -n -m 1 "}" | cut -d: -f1)
END_LINE=$((START_LINE + END_LINE - 1))

# Extract reference block and replace model_name to $MODEL_NAME
NEW_BLOCK=$(sed -n "${START_LINE},${END_LINE}p" "$CONFIGURATION_PATH" | sed "s/},*/}/" | sed "s/model_name.*=.*/model_name     = \"$MODEL_NAME\";/")

# Insert new block before array's closing bracket ');'
awk -v new_block="$NEW_BLOCK" '
/^[[:space:]]*\)[[:space:]]*;/ && !inserted {
    print "    ,"
    print new_block
    inserted = 1
}
{ print }
' "$CONFIGURATION_PATH" >"${CONFIGURATION_PATH}.tmp"

mv "${CONFIGURATION_PATH}.tmp" "$CONFIGURATION_PATH"

NUM_CHANNELS=$(grep -c "model_name" "$CONFIGURATION_PATH")
MAX_CHANNELS=$(grep -oP 'max_chan\s*=\s*\K[0-9]+' "$CONFIGURATION_PATH")

if [ -n "$MAX_CHANNELS" ] && [ "$NUM_CHANNELS" -gt "$MAX_CHANNELS" ]; then
    sed -i "s/max_chan[[:space:]]*=[[:space:]]*[0-9]*[[:space:]]*;/max_chan = $NUM_CHANNELS;/" "$CONFIGURATION_PATH"
    echo "Increased max_chan to $NUM_CHANNELS"
fi

echo "Added $MODEL_NAME block to $CONFIGURATION_PATH"

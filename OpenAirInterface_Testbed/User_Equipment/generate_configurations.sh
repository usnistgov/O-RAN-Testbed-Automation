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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Function to update or add configuration properties in .conf files, considering sections and uncommenting if needed
update_conf() {
    echo "update_conf($1, $2, $3)"
    local FILE_PATH="$1"
    local PROPERTY="$2"
    local VALUE="$3"

    # Check if the property exists in the file, and update or append it accordingly
    if grep -q "^\s*$PROPERTY\s*=" "$FILE_PATH"; then
        # Update existing property's value
        sed -i "s|^\(\s*$PROPERTY\s*=\).*|\1 $VALUE;|" "$FILE_PATH"
    else
        # Append new property-value pair if it does not exist
        echo "$PROPERTY = $VALUE;" >>"$FILE_PATH"
    fi
}

# Function to comment out a line in a file
comment_out() {
    local FILE_PATH="$1"
    local STRING="$2"
    sed -i "s|^\(\s*\)$STRING|#\1$STRING|" "$FILE_PATH"
}

# Define the path to the YAML file
YAML_PATH="../../5G_Core_Network/options.yaml"
if [ ! -f "$YAML_PATH" ]; then
    echo "Configuration not found in $YAML_PATH, please generate the configuration for 5G_Core_Network first."
    exit 1
fi
# Read PLMN and TAC values from the YAML file using sed
PLMN=$(sed -n 's/^plmn: \([0-9]*\)/\1/p' "$YAML_PATH" | tr -d '[:space:]')
TAC=$(sed -n 's/^tac: \([0-9]*\)/\1/p' "$YAML_PATH" | tr -d '[:space:]')
# Check if PLMN and TAC values are found, if not, exit with an error message
if [ -z "$PLMN" ]; then
    echo "PLMN not configured in $YAML_PATH, please generate the configuration for 5G_Core_Network first."
    exit 1
fi
if [ -z "$TAC" ]; then
    echo "TAC not configured in $YAML_PATH, please generate the configuration for 5G_Core_Network first."
    exit 1
fi

MCC="${PLMN:0:3}"
MNC="${PLMN:3:2}"
if [ ${#MNC} -eq 2 ]; then
    MNC_LENGTH=2
else
    MNC_LENGTH=3
fi

echo "PLMN value: $PLMN"
echo "TAC value: $TAC"
echo "MCC value: $MCC"
echo "MNC value: $MNC"
echo "MNC_LENGTH value: $MNC_LENGTH"

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
fi

echo "Saving configuration file example..."
rm -rf configs
mkdir configs

# Only remove the logs if not running
RUNNING_STATUS=$(./is_running.sh)
if [[ $RUNNING_STATUS != *": RUNNING"* ]]; then
    rm -rf logs
    mkdir logs
fi

for UE_NUMBER in {1..3}; do
    cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.conf "configs/ue$UE_NUMBER.conf"

    UE_OPC="63BFA50EE6523365FF14C1F45F88737D"
    UE_APN="srsapn"
    UE_TX_PORT=2001
    UE_RX_PORT=2000
    if [ $UE_NUMBER -eq 1 ]; then # Following the blueprint for UE 1: https://doi.org/10.6028/NIST.TN.2311
        UE_IMEI="353490069873319"
        UE_IMSI="001010123456780"
        UE_KEY="00112233445566778899AABBCCDDEEFF"
        # UE_TX_PORT=2101
        # UE_RX_PORT=2100
        UE_NAMESPACE="ue1"

    elif [ $UE_NUMBER -eq 2 ]; then # Following the blueprint for UE 2: https://doi.org/10.6028/NIST.TN.2311
        UE_IMEI="353490069873318"
        UE_IMSI="001010123456790"
        UE_KEY="00112233445566778899AABBCCDDEF00"
        # UE_TX_PORT=2201
        # UE_RX_PORT=2200
        UE_NAMESPACE="ue2"

    elif [ $UE_NUMBER -eq 3 ]; then # Following the blueprint for UE 3: https://doi.org/10.6028/NIST.TN.2311
        UE_IMEI="353490069873312"
        UE_IMSI="001010123456791"
        UE_KEY="00112233445566778899AABBCCDDEF01"
        # UE_TX_PORT=2301
        # UE_RX_PORT=2300
        UE_NAMESPACE="ue3"

    elif [ $UE_NUMBER -gt 3 ]; then # Dynamic configurations for UE 4 and beyond
        UE_OFFSET=$((UE_NUMBER - 3))
        UE_IMEI=$(printf '%d' $((353490069873319 + UE_OFFSET)))
        UE_IMSI=$(printf '%015d' $((1010123456781 + UE_OFFSET)))
        UE_KEY="00112233445566778$(printf '%X' $((16#899AABBCCDDEF01 + UE_OFFSET)))"
        # UE_TX_PORT="$((23 + $UE_OFFSET))01"
        # UE_RX_PORT="$((23 + $UE_OFFSET))00"
        UE_NAMESPACE="ue$UE_NUMBER"
    fi

    # Unique identifier for the UE within the mobile network. Used by the network to identify the UE during authentication. It ensures that the UE is correctly identified by the network.
    update_conf "configs/ue$UE_NUMBER.conf" "imsi" "\"$UE_IMSI\""

    # Cryptographic key shared between the UE and the network, used for encryption during the authentication process.
    update_conf "configs/ue$UE_NUMBER.conf" "key" "\"$UE_KEY\""

    # Operator key for the Milenage Authentication and Key Agreement algorithm used for encryption during the authentication process.
    update_conf "configs/ue$UE_NUMBER.conf" "opc" "\"$UE_OPC\""

    # Specifies the name of the data network the UE wishes to connect to, similar to an APN in 4G networks.
    update_conf "configs/ue$UE_NUMBER.conf" "dnn" "\"$UE_APN\""

    # Allows the UE to select the appropriate network slice, which provides different QoS.
    update_conf "configs/ue$UE_NUMBER.conf" "nssai_sst" "1"

    # Ensures the PDU Session Establishment is successful (either setting to 0xFFFFFF or commenting it out).
    update_conf "configs/ue$UE_NUMBER.conf" "nssai_sd" "0xFFFFFF"
    comment_out "configs/ue$UE_NUMBER.conf" "nssai_sd"
done

cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/channelmod_rfsimu_LEO_satellite.conf "$SCRIPT_DIR/configs/channelmod_rfsimu_LEO_satellite.conf"

echo "Successfully configured the UE. The configuration file is located in the configs/ directory."

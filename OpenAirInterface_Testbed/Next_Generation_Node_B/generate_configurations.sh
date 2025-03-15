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
rm -rf logs
mkdir logs

cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.sa.band78.fr1.106PRB.usrpb210.conf "$SCRIPT_DIR/configs/gnb.conf"

echo "Fetching AMF addresses..."
FILE_PATH="../../5G_Core_Network/configs/get_amf_address.txt"

prompt_for_addresses() {
    echo "Please enter the AMF address and the AMF binding address manually." >&2
    echo "You can find this information in the 5G_Core_Network/configs/get_amf_addresses.txt file in the first two lines, respectively." >&2
    read -p "Enter AMF Address: " AMF_ADDR
    read -p "Enter AMF Binding Address: " AMF_ADDR_BIND
}

# Check if the file exists and has at least two lines
if [[ -f "$FILE_PATH" ]]; then
    # Read the file and check for at least two non-empty lines
    mapfile -t ADDRESSES <"$FILE_PATH"
    if [[ ${#ADDRESSES[@]} -ge 2 ]] && [[ -n ${ADDRESSES[0]} ]] && [[ -n ${ADDRESSES[1]} ]]; then
        AMF_ADDR="${ADDRESSES[0]}"
        AMF_ADDR_BIND="${ADDRESSES[1]}"
    else
        echo
        echo "AMF address file exists but does not contain valid data."
        prompt_for_addresses
    fi
else
    echo
    echo "Open5GS was not configured."
    prompt_for_addresses
fi

echo "AMF Address: $AMF_ADDR"
echo "AMF Binding Address: $AMF_ADDR_BIND"

# Update configuration values for RF front-end device
update_conf "configs/gnb.conf" "amf_ip_address" "({ ipv4 = \"$AMF_ADDR\"; })"
update_conf "configs/gnb.conf" "GNB_IPV4_ADDRESS_FOR_NG_AMF" "\"$AMF_ADDR_BIND/24\""
update_conf "configs/gnb.conf" "GNB_IPV4_ADDRESS_FOR_NGU" "\"$AMF_ADDR_BIND/24\""
update_conf "configs/gnb.conf" "tracking_area_code" "$TAC"
update_conf "configs/gnb.conf" "plmn_list" "({ mcc = $MCC; mnc = $MNC; mnc_length = $MNC_LENGTH; snssaiList = ({ sst = 1; }) })"

echo "Successfully configured the UE. The configuration file is located in the configs/ directory."

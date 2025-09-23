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

USE_RFSIM_CHANNELMOD=true

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

CLEAR_CONFIGS=false

# Support input argument for the UE number(s), for example:
# ./generate_configurations.sh --> configures UE 1, 2, and 3
# ./generate_configurations.sh 2 --> configures UE 2
# ./generate_configurations.sh 4 5 6 --> configures UE 4, 5, and 6
UE_NUMBERS=("$@")
if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    UE_NUMBERS=(3 2 1)
    CLEAR_CONFIGS=true
fi
# Check if the input is a number
for i in "${UE_NUMBERS[@]}"; do
    if ! [[ "$i" =~ ^[0-9]+$ ]]; then
        echo "Error: UE number must be a number."
        exit 1
    fi
    if [ "$i" -lt 1 ]; then
        echo "Error: UE number must be greater than or equal to 1."
        exit 1
    fi
    echo "UE $i will be configured."
done

# Ensure the correct YAML editor is installed
sudo "$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

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

# Read the PLMN value from the 5G Core, and apply it to the beginning of the UE's IMSI
YAML_PATH="../5G_Core_Network/options.yaml"
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

# Parse Mobile Country Code (MCC) and Mobile Network Code (MNC) from PLMN
MCC="${PLMN:0:3}"
if [ ${#PLMN} -eq 5 ]; then
    MNC="${PLMN:3:2}"
elif [ ${#PLMN} -eq 6 ]; then
    MNC="${PLMN:3:3}"
fi
MNC_LENGTH=${#MNC}

echo "PLMN value: $PLMN"
echo "TAC value: $TAC"
echo "MCC value: $MCC"
echo "MNC value: $MNC"
echo "MNC_LENGTH value: $MNC_LENGTH"

# Configure the DNN, SST, and SD values
DNN=$(sed -n 's/^dnn: //p' "$YAML_PATH")
SST=$(yq eval '.sst' "$YAML_PATH")
SD=$(yq eval '.sd' "$YAML_PATH")
if [[ -z "$DNN" || "$DNN" == "null" ]]; then
    echo "DNN is not set in "$YAML_PATH", please ensure that \"dnn\" is set."
    exit 1
fi
if [[ -z "$SST" || -z "$SD" || "$SST" == "null" || "$SD" == "null" ]]; then
    echo "SST or SD is not set in "$YAML_PATH", please ensure that \"sst\" and \"sd\" are set."
    exit 1
fi

OGSTUN_IPV4=$(yq eval '.ogstun_ipv4' "$YAML_PATH")
OGSTUN_IPV6=$(yq eval '.ogstun_ipv6' "$YAML_PATH")
if [[ "$OGSTUN_IPV4" == "null" || -z "$OGSTUN_IPV4" ]]; then
    echo "Missing parameter in "$YAML_PATH": ogstun_ipv4"
    exit 1
fi
if [[ "$OGSTUN_IPV6" == "null" || -z "$OGSTUN_IPV6" ]]; then
    echo "Missing parameter in "$YAML_PATH": ogstun_ipv6"
    exit 1
fi

echo "Saving configuration file example..."
if [ "$CLEAR_CONFIGS" = true ]; then
    sudo rm -rf configs

    # Only remove the logs if not running
    RUNNING_STATUS=$(./is_running.sh)
    if [[ $RUNNING_STATUS != *": RUNNING"* ]]; then
        sudo rm -rf logs
    fi
fi
mkdir -p configs
mkdir -p logs

if [ "$USE_RFSIM_CHANNELMOD" = true ]; then
    echo "Using the channelmod_rfsimu.conf file for the RFSIM channel model."
    cp install_patch_files/channelmod_rfsimu.conf "$SCRIPT_DIR/configs/channelmod_rfsimu.conf"
else
    echo "Using the channelmod_rfsimu_LEO_satellite.conf file for the RFSIM channel model."
    # Use the default channelmod_rfsimu_LEO_satellite.conf file
    cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/channelmod_rfsimu_LEO_satellite.conf configs/channelmod_rfsimu.conf
fi

UE_CREDENTIAL_GENERATOR_SCRIPT="$SCRIPT_DIR/ue_credentials_generator.sh"
if [ ! -f "$UE_CREDENTIAL_GENERATOR_SCRIPT" ]; then
    echo "Error: Cannot find $UE_CREDENTIAL_GENERATOR_SCRIPT to generate UE subscriber credentials."
    exit 1
fi

for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.conf "configs/ue$UE_NUMBER.conf"

    # Fetch the UE's OPc, IMEI, IMSI, KEY, and NAMESPACE
    read -r UE_OPC UE_IMEI UE_IMSI UE_KEY UE_NAMESPACE < <("$UE_CREDENTIAL_GENERATOR_SCRIPT" "$UE_NUMBER" "$PLMN")

    # Unique identifier for the UE within the mobile network. Used by the network to identify the UE during authentication. It ensures that the UE is correctly identified by the network.
    update_conf "configs/ue$UE_NUMBER.conf" "imsi" "\"$UE_IMSI\""

    # Cryptographic key shared between the UE and the network, used for encryption during the authentication process.
    update_conf "configs/ue$UE_NUMBER.conf" "key" "\"$UE_KEY\""

    # Operator key for the Milenage Authentication and Key Agreement algorithm used for encryption during the authentication process.
    update_conf "configs/ue$UE_NUMBER.conf" "opc" "\"$UE_OPC\""

    # Specifies the name of the data network the UE wishes to connect to
    update_conf "configs/ue$UE_NUMBER.conf" "dnn" "\"$DNN\""

    # Configure the Single Network Slice Selection Assistance Information (S-NSSAI)
    update_conf "configs/ue$UE_NUMBER.conf" "nssai_sst" "$((16#$SST))"
    update_conf "configs/ue$UE_NUMBER.conf" "nssai_sd" "0x$SD"
    # comment_out "configs/ue$UE_NUMBER.conf" "nssai_sd" # Optionally, comment out the SD from the file

    # Finally, ensure that it is referencing the channelmod_rfsimu.conf file
    sed -i "s|channelmod_rfsimu_LEO_satellite.conf|channelmod_rfsimu.conf|" "configs/ue$UE_NUMBER.conf"
    if ! grep -q "@include \"channelmod_rfsimu.conf\"" "configs/ue$UE_NUMBER.conf"; then
        echo "" >>"configs/ue$UE_NUMBER.conf"
        echo "@include \"channelmod_rfsimu.conf\"" >>"configs/ue$UE_NUMBER.conf"
    fi

    UE_IPV4=""
    if [ $UE_NUMBER -gt 3 ]; then
        echo "UE is greater than registered subscribers, registering UE $UE_NUMBER..."
        REGISTRATION_DIR=$(dirname "$SCRIPT_DIR")/5G_Core_Network/install_scripts
        if [ -f "$REGISTRATION_DIR/./register_subscriber.sh" ]; then
            UE_INDEX=$((UE_NUMBER + 99))
            UE_IPV4=$(python3 install_scripts/fetch_nth_ip.py "$OGSTUN_IPV4" "$UE_INDEX")
            if [ $? -eq 0 ]; then
                IPV4_LINE="--ipv4 $UE_IPV4"
            else
                IPV4_LINE=""
            fi
            "$REGISTRATION_DIR/./register_subscriber.sh" --imsi "$UE_IMSI" --key "$UE_KEY" --opc "$UE_OPC" --apn "$DNN" --sst "$SST" --sd "$SD" $IPV4_LINE || true
        fi
    fi

    echo
    echo "Successfully configured UE ${UE_NUMBER}."
    echo "    OPc:  $UE_OPC"
    echo "    IMEI: $UE_IMEI"
    echo "    IMSI: $UE_IMSI"
    echo "    KEY:  $UE_KEY"
    echo "    PLMN: $PLMN"
    echo "    DNN:  $DNN"
    echo "    SST:  $SST"
    echo "    SD:   $SD"
    if [ -n "$UE_IPV4" ]; then
        echo "    IPv4: $UE_IPV4"
    fi
    echo

    echo "The configuration file is located in the configs/ directory."
done

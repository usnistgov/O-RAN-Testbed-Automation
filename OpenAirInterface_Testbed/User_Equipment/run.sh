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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

UE_NUMBER=1
if [ "$#" -eq 1 ]; then
    UE_NUMBER=$1
fi
if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
    echo "Error: UE number must be a number."
    exit 1
fi
if [ $UE_NUMBER -lt 1 ]; then
    echo "Error: UE number must be greater than or equal to 1."
    exit 1
fi

if [ ! -f "configs/ue1.conf" ]; then
    echo "Configuration was not found for OAI UE 1. Please run ./generate_configurations.sh first."
    exit 1
fi

# Function to handle graceful shutdown
graceful_shutdown() {
    echo "Shutting down UE $UE_NUMBER gracefully..."
    ./stop.sh
    exit
}
trap graceful_shutdown SIGINT

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

UE_CONF_PATH="configs/ue$UE_NUMBER.conf"

if [ ! -f "$UE_CONF_PATH" ]; then
    echo "Configuration file for UE $UE_NUMBER not found, creating..."
    cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.conf "$UE_CONF_PATH"

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

    # Ensure that the beginning of the IMSI is the correct PLMN
    if [ ! -z "$PLMN" ]; then
        PLMN_LENGTH=${#PLMN}
        UE_IMSI="${PLMN}${UE_IMSI:$PLMN_LENGTH}"
    fi

    update_conf "configs/ue$UE_NUMBER.conf" "imsi" "\"$UE_IMSI\""
    update_conf "configs/ue$UE_NUMBER.conf" "key" "\"$UE_KEY\""
    update_conf "configs/ue$UE_NUMBER.conf" "opc" "\"$UE_OPC\""
    update_conf "configs/ue$UE_NUMBER.conf" "dnn" "\"$UE_APN\""
    update_conf "configs/ue$UE_NUMBER.conf" "nssai_sst" "1"
    update_conf "configs/ue$UE_NUMBER.conf" "nssai_sd" "0xFFFFFF"
    comment_out "configs/ue$UE_NUMBER.conf" "nssai_sd"
fi

if [ $UE_NUMBER -gt 3 ]; then
    echo "UE is greater than registered subscribers, registering UE $UE_NUMBER..."
    REGISTRATION_DIR=$(dirname "$SCRIPT_DIR")/5G_Core_Network/install_scripts
    "$REGISTRATION_DIR/./register_subscriber.sh" --imsi "$UE_IMSI" --key "$UE_KEY" --opc "$UE_OPC" --apn "$UE_APN"
fi

HOSTNAME_IP=$(hostname -I | awk '{print $1}')

if ./is_running.sh | grep -q "ue$UE_NUMBER"; then
    echo "Already running ue$UE_NUMBER."
else
    if [ ! -f "$UE_CONF_PATH" ]; then
        echo "Configuration was not found for OAI UE $UE_NUMBER. Please run ./generate_configurations.sh first."
        exit 1
    fi
    mkdir -p logs
    >logs/ue${UE_NUMBER}_stdout.txt
    echo "Starting nr-uesoftmodem (ue$UE_NUMBER)..."

    # Ensure the following command runs with sudo privileges
    sudo ls >/dev/null

    # Give the UE its own network namespace and configure it to access the host network
    sudo ./install_scripts/setup_ue_namespace.sh "$UE_NUMBER"

    cd "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build"
    sudo ./nr-uesoftmodem -O "../../../../configs/ue$UE_NUMBER.conf" --rfsim --rfsimulator.serveraddr $HOSTNAME_IP -r 106 --numerology 1 --band 78 -C 3619200000
fi

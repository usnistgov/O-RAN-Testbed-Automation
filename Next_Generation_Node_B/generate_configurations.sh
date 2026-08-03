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

echo "# Script: $(realpath "$0") $@"

# Exit immediately if a command fails
set -e

EXPOSE_GNB_TO_HOSTNAME=false
USE_FLEXRIC=false
USE_ZMQ_BROKER=true
PDU_SESSION_TIMEOUT=3

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    PDU_SESSION_TIMEOUT=30
fi

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Radio configuration presets (band 3 and band 78)
BASE_EXAMPLE_CONFIG_PATH="$SCRIPT_DIR/ocudu/configs/gnb_rf_b210_fdd_srsUE.yml"
GNB_DL_ARFCNS=("368500")
ZMQ_BROKER_CHANNEL_BW_MHZ=20
GNB_SRATE_MHZ=23.04
GNB_BASE_SRATE_HZ=23.04e6
#
# BASE_EXAMPLE_CONFIG_PATH="$SCRIPT_DIR/ocudu/configs/gnb_rf_b200_tdd_n78_20mhz.yml"
# GNB_DL_ARFCNS=("630048" "643296")
# ZMQ_BROKER_CHANNEL_BW_MHZ=40
# GNB_SRATE_MHZ=46.08
# GNB_BASE_SRATE_HZ=46.08e6

usage() {
    echo "Usage: $0 [--disable-e2-term] [--e2-term-address <address>] [--cells <cell_numbers>] [--ues <ue_numbers>]"
    echo "    For example: $0 --ues 4,5,6 --cells 1,2"
}

# Parse command-line arguments
ENABLE_E2_TERM="true"
E2_ADDRESS="null"
UE_NUMBERS=()
CELL_NUMBERS=()
while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    --disable-e2-term)
        ENABLE_E2_TERM="false"
        shift
        ;;
    --e2-term-address)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --e2-term-address requires an address."
            usage
            exit 1
        fi
        E2_ADDRESS="$2"
        shift 2
        ;;
    --cells)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --cells requires comma-separated cell numbers."
            usage
            exit 1
        fi
        IFS=',' read -r -a PARSED_CELL_NUMBERS <<<"$2"
        for CELL_NUMBER in "${PARSED_CELL_NUMBERS[@]}"; do
            if ! [[ "$CELL_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
                echo "ERROR: Cell numbers must be positive integers separated by commas."
                exit 1
            fi
            CELL_NUMBERS+=("$CELL_NUMBER")
        done
        shift 2
        ;;
    --ues)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --ues requires comma-separated UE numbers."
            usage
            exit 1
        fi
        IFS=',' read -r -a parsed_ues <<<"$2"
        for UE_NUMBER in "${parsed_ues[@]}"; do
            if ! [[ "$UE_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
                echo "ERROR: UE numbers must be positive integers separated by commas."
                exit 1
            fi
            UE_NUMBERS+=("$UE_NUMBER")
        done
        shift 2
        ;;
    *)
        echo "ERROR: Unknown argument: $1"
        echo
        usage
        exit 1
        ;;
    esac
done
if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    UE_NUMBERS=(1 2 3)
fi
if [ ${#CELL_NUMBERS[@]} -eq 0 ]; then
    CELL_NUMBERS=(1)
fi

# Define the path to the YAML file
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
echo "PLMN value: $PLMN"
echo "TAC value: $TAC"

# Ensure the correct YAML editor is installed
"$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

# Configure the DNN, SST, and SD values
DNN=($(yq eval '.slices[].dnn' "$YAML_PATH"))
SST=($(yq eval '.slices[].sst' "$YAML_PATH"))
SD=($(yq eval '.slices[].sd' "$YAML_PATH"))
if [[ -z "${DNN[0]}" || "${DNN[0]}" == "null" ]]; then
    echo "DNN is not set in $YAML_PATH, please ensure that \"dnn\" is set."
    exit 1
fi
if [[ -z "${SST[0]}" || "${SST[0]}" == "null" ]]; then
    echo "SST is not set in $YAML_PATH, please ensure that \"slices[].sst\" is set."
    exit 1
fi

# SST/SD are configured in options.yaml as hex without 0x prefix.
for i in "${!SST[@]}"; do
    CURRENT_DNN="${DNN[$i]}"
    CURRENT_SST="${SST[$i]}"
    CURRENT_SD="${SD[$i]}"

    CURRENT_SST="${CURRENT_SST#0x}"
    CURRENT_SST="${CURRENT_SST#0X}"
    CURRENT_SST="${CURRENT_SST^^}"

    if [[ ! "$CURRENT_SST" =~ ^[0-9A-F]{1,2}$ ]]; then
        echo "Invalid slices[$i].sst '${SST[$i]}'. Use hexadecimal (00-FF), no 0x prefix."
        exit 1
    fi
    SST[$i]="$((16#$CURRENT_SST))"

    if [[ "$CURRENT_SD" != "null" ]]; then
        CURRENT_SD="${CURRENT_SD#0x}"
        CURRENT_SD="${CURRENT_SD#0X}"
        CURRENT_SD="${CURRENT_SD^^}"
        if [[ ! "$CURRENT_SD" =~ ^[0-9A-F]{1,6}$ ]]; then
            echo "Invalid slices[$i].sd '${SD[$i]}'. Use hexadecimal (up to 6 hex digits), no 0x prefix."
            exit 1
        fi
        SD[$i]="$(printf "%06X" "$((16#$CURRENT_SD))")"
    fi
done

if [ ! -t 0 ] && [ -z "$("../5G_Core_Network/install_scripts/get_amf_address.sh")" ]; then
    echo "ERROR: Open5GS AMF addresses are not configured and standard input is not interactive."
    echo "Please run 5G_Core_Network/generate_configurations.sh before regenerating the gNodeB configuration."
    exit 1
fi

echo "Restoring gNodeB configuration file..."
rm -rf configs
mkdir configs

# Only remove the logs if is not running
RUNNING_STATUS=$(./is_running.sh)
if [[ $RUNNING_STATUS != *": RUNNING"* ]]; then
    rm -rf logs
    mkdir logs
fi

if [ ! -f "$BASE_EXAMPLE_CONFIG_PATH" ]; then
    echo "Configuration file not found in $BASE_EXAMPLE_CONFIG_PATH, please ensure that the file exists."
    exit 1
fi
cp "$BASE_EXAMPLE_CONFIG_PATH" configs/gnb.yaml
CELL_BAND=$(yq eval '.cell_cfg.band' configs/gnb.yaml)

if [ ! -d "../RAN_Intelligent_Controllers/Near-Real-Time-RIC" ] && [ "$USE_FLEXRIC" = "false" ]; then
    echo "Could not find the Near-Real-Time-RIC directory. Disabling E2 termination support."
    ENABLE_E2_TERM="false"
fi

if [ "$ENABLE_E2_TERM" = "true" ]; then
    if [ "$USE_FLEXRIC" = "true" ]; then
        PORT_E2TERM=36421
    else
        PORT_E2TERM=36422
    fi

    # If E2_ADDRESS is provided, override logic and force E2 address
    if [ "$E2_ADDRESS" != "null" ]; then
        IP_E2TERM="$E2_ADDRESS"
        IP_E2TERM_BIND="$E2_ADDRESS"
        echo "E2_ADDRESS provided: $E2_ADDRESS"
        echo "IP_E2TERM: $IP_E2TERM"
        echo "PORT_E2TERM: $PORT_E2TERM"
        echo "IP_E2TERM_BIND: $IP_E2TERM_BIND"
    elif [ "$USE_FLEXRIC" = "true" ]; then
        IP_E2TERM="127.0.0.1"
        IP_E2TERM_BIND="127.0.0.1"
        echo "FlexRIC selected. Using IP: $IP_E2TERM, Port: $PORT_E2TERM"
    else
        echo "Fetching E2 termination service IP address..."

        # Check if kubectl is installed
        PROMPT_FOR_E2_ADDRESS="false"
        if ! command -v kubectl &>/dev/null; then
            echo "Could not find kubectl."
            PROMPT_FOR_E2_ADDRESS="true"
        else
            SERVICE_INFO=$(kubectl get service -n ricplt 2>/dev/null | grep service-ricplt-e2term-sctp || echo "")

            # Check if SERVICE_INFO is empty
            if [ -z "$SERVICE_INFO" ]; then
                echo "No service found or kubectl command failed."
                PROMPT_FOR_E2_ADDRESS="true"
            else
                # Use awk to extract the IP and the correct port based on the connection context
                IP_E2TERM=$(echo "$SERVICE_INFO" | awk '{print $3}')
                PORT_E2TERM=$(echo "$SERVICE_INFO" | awk '{print $5}' | cut -d ':' -f1 | cut -d '/' -f1) # 36422

                if [ -z "$IP_E2TERM" ] || [ "$IP_E2TERM" == "<none>" ]; then
                    PROMPT_FOR_E2_ADDRESS="true"
                fi
            fi
        fi

        if [ "$PROMPT_FOR_E2_ADDRESS" = "true" ]; then
            echo
            echo "Please enter the IP address where the E2 termination service is located."
            echo "You can find this by running: kubectl get service -n ricplt | grep service-ricplt-e2term-sctp"
            echo "Type \"\" to disable E2 support in the gNodeB configuration."
            read -p "Enter IP Address: " IP_E2TERM
            IP_E2TERM=$(echo "$IP_E2TERM" | xargs) # Trim whitespace
        fi

        if [ -z "$IP_E2TERM" ]; then
            echo
            echo "No E2 address was provided, disabling E2 termination support."
            ENABLE_E2_TERM="false"
        else
            IP_E2TERM_BIND=$IP_E2TERM
            echo "IP_E2TERM: $IP_E2TERM"
            echo "PORT_E2TERM: $PORT_E2TERM"
            echo "IP_E2TERM_BIND: $IP_E2TERM_BIND"
        fi
    fi
fi

echo "Fetching AMF addresses..."
AMF_ADDRESSES=$("../5G_Core_Network/install_scripts/get_amf_address.sh")

prompt_for_addresses() {
    echo "Please enter the AMF address and the AMF binding address manually." >&2
    echo "You can find this information in the 5G_Core_Network/configs/get_amf_addresses.txt file in the first two lines, respectively." >&2
    read -p "Enter AMF Address: " AMF_ADDR
    read -p "Enter AMF Binding Address: " N3_ADDR_BIND
    N2_ADDR_BIND=$N3_ADDR_BIND
}

# Check if AMF_ADDRESSES has at least two non-empty lines
if [[ -n "$AMF_ADDRESSES" ]]; then
    # Read AMF_ADDRESSES into an array, splitting on newlines
    ADDRESSES=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue # skip blank lines
        ADDRESSES+=("$line")
    done <<<"$AMF_ADDRESSES"
    if [[ ${#ADDRESSES[@]} -ge 3 ]] && [[ -n ${ADDRESSES[0]} ]] && [[ -n ${ADDRESSES[1]} ]] && [[ -n ${ADDRESSES[2]} ]]; then
        AMF_ADDR="${ADDRESSES[0]}"
        N3_ADDR_BIND="${ADDRESSES[1]}"
        N2_ADDR_BIND="${ADDRESSES[2]}"
    elif [[ ${#ADDRESSES[@]} -ge 2 ]] && [[ -n ${ADDRESSES[0]} ]] && [[ -n ${ADDRESSES[1]} ]]; then
        AMF_ADDR="${ADDRESSES[0]}"
        N3_ADDR_BIND="${ADDRESSES[1]}"
        N2_ADDR_BIND="${ADDRESSES[1]}"
    else
        echo
        echo "AMF address script did not return valid data."
        prompt_for_addresses
    fi
else
    echo
    echo "Open5GS was not configured."
    prompt_for_addresses
fi

echo "AMF Address: $AMF_ADDR"
echo "NGAP Binding Address: $N2_ADDR_BIND"

# Function to update or add YAML configuration properties using yq
update_yaml() {
    echo "update_yaml($1, $2, $3, $4)"
    local FILE_PATH=$1
    local SECTION=$2
    local PROPERTY=$3
    local VALUE=$4

    # Three arguments: file, property_path, value
    if [ "$#" -eq 3 ]; then
        SECTION=""
        PROPERTY=$2
        VALUE=$3
    fi

    if [[ ! -z "$SECTION" ]]; then
        SECTION=".$SECTION"
    fi
    # Check if the value is specifically intended to be null
    if [[ "$VALUE" == "null" ]]; then
        yq eval -i "${SECTION}.${PROPERTY} = null" "$FILE_PATH"
        return
    fi
    # If value is empty or undefined, skip the update
    if [[ -z "$VALUE" ]]; then
        echo "Skipping empty value for $SECTION.$PROPERTY"
        return
    fi

    # If the value is numeric or boolean, don't quote it
    # PLMN should be treated as string
    if [[ "$PROPERTY" == "plmn" || "$PROPERTY" == "plmn_list" || "$PROPERTY" == *".plmn" || "$PROPERTY" == *".plmn_list" ]]; then
        yq eval -i "${SECTION}.${PROPERTY} = \"$VALUE\"" "$FILE_PATH"
    elif [[ "$VALUE" =~ ^-?[0-9]+$ || "$VALUE" =~ ^-?[0-9]+\.[0-9]+$ || "$VALUE" =~ ^(true|false)$ ]]; then
        yq eval -i "${SECTION}.${PROPERTY} = ${VALUE}" "$FILE_PATH"
    else
        yq eval -i "${SECTION}.${PROPERTY} = \"$VALUE\"" "$FILE_PATH"
    fi
}

mkdir -p "$SCRIPT_DIR/logs"

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    DEVICE_ARGS="fail_unlocked=true,"
    CELL_COUNT=0
    for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
        CELL_RX_PORT=$((2000 + (CELL_NUMBER - 1) * 2))
        CELL_TX_PORT=$((CELL_RX_PORT + 1))
        if [ "$CELL_TX_PORT" -gt 65535 ]; then
            echo "ERROR: Cell $CELL_NUMBER has a ZeroMQ port above 65535."
            exit 1
        fi
        DEVICE_ARGS="${DEVICE_ARGS}tx_port${CELL_COUNT}=tcp://127.0.0.1:${CELL_RX_PORT},rx_port${CELL_COUNT}=tcp://127.0.0.1:${CELL_TX_PORT},"
        CELL_COUNT=$((CELL_COUNT + 1))
    done
else
    UE_NUMBER="${UE_NUMBERS[0]}"
    UE_IP=$(../User_Equipment/install_scripts/get_ue_namespace_ip.sh ue "$UE_NUMBER")
    DEVICE_ARGS="${DEVICE_ARGS}fail_unlocked=true,tx_port=tcp://*:2100,rx_port=tcp://$UE_IP:2101,"
fi

DEVICE_ARGS="${DEVICE_ARGS}base_srate=$GNB_BASE_SRATE_HZ"

# Update configuration values for AMF connection
update_yaml "configs/gnb.yaml" "cu_cp.amf" "addrs" "$AMF_ADDR"

if [ -n "$N2_ADDR_BIND" ]; then
    update_yaml "configs/gnb.yaml" "cu_cp.amf" "bind_addrs" "$N2_ADDR_BIND"
elif [ "$EXPOSE_GNB_TO_HOSTNAME" = "false" ]; then
    update_yaml "configs/gnb.yaml" "cu_cp.amf" "bind_addrs" "127.0.0.1"
else
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
    IP_ADDRESS=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    update_yaml "configs/gnb.yaml" "cu_cp.amf" "bind_addrs" "$IP_ADDRESS"
fi
update_yaml "configs/gnb.yaml" "cu_cp.amf.supported_tracking_areas[0]" "tac" $TAC
update_yaml "configs/gnb.yaml" "cu_cp.amf.supported_tracking_areas[0].plmn_list[0]" "plmn" $PLMN
update_yaml "configs/gnb.yaml" "cu_cp.inactivity_timer" "7200"

# Update configuration values for RF front-end device
update_yaml "configs/gnb.yaml" "ru_sdr" "device_driver" "zmq"
update_yaml "configs/gnb.yaml" "ru_sdr" "device_args" "$DEVICE_ARGS"
update_yaml "configs/gnb.yaml" "ru_sdr" "srate" "$GNB_SRATE_MHZ"
update_yaml "configs/gnb.yaml" "ru_sdr" "tx_gain" "0" # https://gitlab.com/ocudu/ocudu/-/commit/8c922b067749d89d60c37b60c4bc6292b79a0183
update_yaml "configs/gnb.yaml" "ru_sdr" "rx_gain" "0"
update_yaml "configs/gnb.yaml" "ru_sdr" "clock" "default"
update_yaml "configs/gnb.yaml" "ru_sdr" "sync" "default"

# Update configuration values for 5G cell parameters
BASE_CELL_NUMBER="${CELL_NUMBERS[0]}"
BASE_RADIO_PROFILE_INDEX=$(((BASE_CELL_NUMBER - 1) % ${#GNB_DL_ARFCNS[@]}))
update_yaml "configs/gnb.yaml" "cell_cfg" "dl_arfcn" "${GNB_DL_ARFCNS[$BASE_RADIO_PROFILE_INDEX]}"
update_yaml "configs/gnb.yaml" "cell_cfg" "pci" "$((BASE_CELL_NUMBER - 1))"
update_yaml "configs/gnb.yaml" "cell_cfg" "nof_antennas_dl" "1"
update_yaml "configs/gnb.yaml" "cell_cfg" "nof_antennas_ul" "1"
update_yaml "configs/gnb.yaml" "cell_cfg" "plmn" $PLMN
update_yaml "configs/gnb.yaml" "cell_cfg" "tac" $TAC
update_yaml "configs/gnb.yaml" "cell_cfg.pdsch" "mcs_table" "qam64"
update_yaml "configs/gnb.yaml" "cell_cfg.pusch" "mcs_table" "qam64"

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    update_yaml "configs/gnb.yaml" "cell_cfg" "channel_bandwidth_MHz" "$ZMQ_BROKER_CHANNEL_BW_MHZ"
    update_yaml "configs/gnb.yaml" "ru_sdr.amplitude_control" "tx_gain_backoff" "22"
    update_yaml "configs/gnb.yaml" "cell_cfg.prach" "total_nof_ra_preambles" "60"
    update_yaml "configs/gnb.yaml" "cell_cfg.prach" "nof_ssb_per_ro" "1"
    update_yaml "configs/gnb.yaml" "cell_cfg.prach" "nof_cb_preambles_per_ssb" "60"
    if [ "$CELL_BAND" = "3" ]; then
        update_yaml "configs/gnb.yaml" "cell_cfg.prach" "prach_frequency_start" "3"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "resource_set_size" "7"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "nof_cell_res_set_configs" "1"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "f1_nof_cyclic_shifts" "1"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "f1_enable_occ" "true"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "nof_cell_sr_res" "7"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "nof_cell_csi_res" "7"
    elif [ "$CELL_BAND" = "78" ]; then
        update_yaml "configs/gnb.yaml" "cell_cfg.csi" "csi_rs_enabled" "false"
        update_yaml "configs/gnb.yaml" "cell_cfg.pdcch.common" "coreset0_index" "11"
        update_yaml "configs/gnb.yaml" "cell_cfg.prach" "prach_config_index" "159"
        update_yaml "configs/gnb.yaml" "cell_cfg.prach" "prach_root_sequence_index" "1"
        update_yaml "configs/gnb.yaml" "cell_cfg.prach" "preamble_rx_target_pw" "-110"
        update_yaml "configs/gnb.yaml" "cell_cfg.pusch" "msg3_delta_preamble" "6"
        update_yaml "configs/gnb.yaml" "cell_cfg.ssb" "ssb_period" "20"
        update_yaml "configs/gnb.yaml" "cell_cfg.ssb" "ssb_block_power_dbm" "-25"
        update_yaml "configs/gnb.yaml" "cell_cfg.tdd_ul_dl_cfg" "dl_ul_tx_period" "10"
        update_yaml "configs/gnb.yaml" "cell_cfg.tdd_ul_dl_cfg" "nof_dl_slots" "7"
        update_yaml "configs/gnb.yaml" "cell_cfg.tdd_ul_dl_cfg" "nof_dl_symbols" "6"
        update_yaml "configs/gnb.yaml" "cell_cfg.tdd_ul_dl_cfg" "nof_ul_slots" "2"
        update_yaml "configs/gnb.yaml" "cell_cfg.tdd_ul_dl_cfg" "nof_ul_symbols" "4"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "formats" "f0_and_f2"
        update_yaml "configs/gnb.yaml" "cell_cfg.pucch" "nof_cell_csi_res" "0"
    fi
fi

yq eval -i 'del(.cells)' "configs/gnb.yaml"
if [ "$USE_ZMQ_BROKER" = "true" ] && [ "${#CELL_NUMBERS[@]}" -gt 1 ]; then
    CELL_COUNT=0
    for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
        RADIO_PROFILE_INDEX=$(((CELL_NUMBER - 1) % ${#GNB_DL_ARFCNS[@]}))
        update_yaml "configs/gnb.yaml" "cells[$CELL_COUNT]" "pci" "$((CELL_NUMBER - 1))"
        update_yaml "configs/gnb.yaml" "cells[$CELL_COUNT]" "dl_arfcn" "${GNB_DL_ARFCNS[$RADIO_PROFILE_INDEX]}"
        CELL_COUNT=$((CELL_COUNT + 1))
    done
fi

# Update configuration values for slicing
# Clear existing slice configuration
yq eval -i 'del(.cell_cfg.slicing)' "configs/gnb.yaml"
yq eval -i 'del(.cu_cp.amf.supported_tracking_areas[0].plmn_list[0].tai_slice_support_list)' "configs/gnb.yaml"

SLICE_IDX=0
declare -A OMIT_SD
declare -A OMIT_SD_ADDED

# Check for omitting SD if null or FFFFFF (case insensitive)
for i in "${!SST[@]}"; do
    CURRENT_DNN="${DNN[$i]}"
    CURRENT_SST="${SST[$i]}"
    CURRENT_SD="${SD[$i]}"
    if [[ "$CURRENT_SD" == "null" || "${CURRENT_SD^^}" == "FFFFFF" ]]; then
        OMIT_SD["$CURRENT_SST"]=1
    fi
done

for i in "${!SST[@]}"; do
    CURRENT_DNN="${DNN[$i]}"
    CURRENT_SST="${SST[$i]}"
    CURRENT_SD="${SD[$i]}"

    # If SST has SD wildcard, only add SST to the list
    if [[ -n "${OMIT_SD[$CURRENT_SST]}" ]]; then
        if [[ -z "${OMIT_SD_ADDED[$CURRENT_SST]}" ]]; then # Uniqueness
            # Add SST to cell config
            update_yaml "configs/gnb.yaml" "cell_cfg.slicing[$SLICE_IDX]" "sst" "$CURRENT_SST"
            update_yaml "configs/gnb.yaml" "cell_cfg.slicing[$SLICE_IDX].sched_cfg" "min_prb_policy_ratio" "0"
            update_yaml "configs/gnb.yaml" "cell_cfg.slicing[$SLICE_IDX].sched_cfg" "max_prb_policy_ratio" "100"

            # Add SST to AMF supported tracking areas
            update_yaml "configs/gnb.yaml" "cu_cp.amf.supported_tracking_areas[0].plmn_list[0].tai_slice_support_list[$SLICE_IDX]" "sst" "$CURRENT_SST"

            OMIT_SD_ADDED["$CURRENT_SST"]=1
            SLICE_IDX=$((SLICE_IDX + 1))
        fi
    else
        # Entry with SST and SD
        SD_DECIMAL=$((16#${CURRENT_SD}))

        # Add SST and SD to cell config
        update_yaml "configs/gnb.yaml" "cell_cfg.slicing[$SLICE_IDX]" "sst" "$CURRENT_SST"
        update_yaml "configs/gnb.yaml" "cell_cfg.slicing[$SLICE_IDX]" "sd" "$SD_DECIMAL"
        update_yaml "configs/gnb.yaml" "cell_cfg.slicing[$SLICE_IDX].sched_cfg" "min_prb_policy_ratio" "0"
        update_yaml "configs/gnb.yaml" "cell_cfg.slicing[$SLICE_IDX].sched_cfg" "max_prb_policy_ratio" "100"

        # Add SST and SD to AMF supported tracking areas
        update_yaml "configs/gnb.yaml" "cu_cp.amf.supported_tracking_areas[0].plmn_list[0].tai_slice_support_list[$SLICE_IDX]" "sst" "$CURRENT_SST"
        update_yaml "configs/gnb.yaml" "cu_cp.amf.supported_tracking_areas[0].plmn_list[0].tai_slice_support_list[$SLICE_IDX]" "sd" "$SD_DECIMAL"

        SLICE_IDX=$((SLICE_IDX + 1))
    fi
done

GNB_ID="411"
RAN_NODE_NAME="ocudugnb01"
GNB_DU_ID="0"
update_yaml "configs/gnb.yaml" "" "gnb_id" "$GNB_ID"
update_yaml "configs/gnb.yaml" "" "gnb_id_bit_length" "22" # Supported: 22-32
update_yaml "configs/gnb.yaml" "" "ran_node_name" "$RAN_NODE_NAME"
update_yaml "configs/gnb.yaml" "" "gnb_du_id" "$GNB_DU_ID"

# Update configuration values to connect RIC by e2 interface
if [ "$ENABLE_E2_TERM" = "true" ]; then
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
    HOST_IP=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

    update_yaml "configs/gnb.yaml" "e2" "enable_du_e2" "true"
    update_yaml "configs/gnb.yaml" "e2" "enable_cu_cp_e2" "false"
    update_yaml "configs/gnb.yaml" "e2" "enable_cu_up_e2" "false"
    update_yaml "configs/gnb.yaml" "e2" "e2sm_kpm_enabled" "true"
    update_yaml "configs/gnb.yaml" "e2" "e2sm_rc_enabled" "true"
    update_yaml "configs/gnb.yaml" "e2" "addr" "$IP_E2TERM"
    sed -i "0,/addr:/{s/addr: .*/addr: $IP_E2TERM  # E2 terminator address/}" "configs/gnb.yaml"

    if [ -n "$IP_E2TERM_BIND" ]; then
        update_yaml "configs/gnb.yaml" "e2" "bind_addr" "$IP_E2TERM_BIND"
    else
        update_yaml "configs/gnb.yaml" "e2" "bind_addr" "$HOST_IP"
    fi

    update_yaml "configs/gnb.yaml" "e2" "port" "$PORT_E2TERM"
else
    update_yaml "configs/gnb.yaml" "e2" "enable_cu_cp_e2" "false"
    update_yaml "configs/gnb.yaml" "e2" "enable_cu_up_e2" "false"
    update_yaml "configs/gnb.yaml" "e2" "enable_du_e2" "false"
    update_yaml "configs/gnb.yaml" "e2" "e2sm_kpm_enabled" "false"
    update_yaml "configs/gnb.yaml" "e2" "e2sm_rc_enabled" "false"
fi

# Update configuration values for CU-CP
update_yaml "configs/gnb.yaml" "cu_cp" "max_nof_dus" ""
update_yaml "configs/gnb.yaml" "cu_cp" "max_nof_cu_ups" ""
update_yaml "configs/gnb.yaml" "cu_cp" "max_nof_ues" ""
update_yaml "configs/gnb.yaml" "cu_cp" "max_nof_drbs_per_ue" ""
update_yaml "configs/gnb.yaml" "cu_cp" "request_pdu_session_timeout" "$PDU_SESSION_TIMEOUT"

# Update configuration values for gNodeB logging
update_yaml "configs/gnb.yaml" "log" "filename" "$SCRIPT_DIR/logs/gnb.log"
update_yaml "configs/gnb.yaml" "log" "all_level" "warning"
update_yaml "configs/gnb.yaml" "log" "mac_level" "warning"
update_yaml "configs/gnb.yaml" "log" "rlc_level" "warning"
update_yaml "configs/gnb.yaml" "log" "rrc_level" "warning"
update_yaml "configs/gnb.yaml" "log" "ngap_level" "warning"
update_yaml "configs/gnb.yaml" "log" "f1ap_level" "warning"
update_yaml "configs/gnb.yaml" "log" "du_level" "warning"
update_yaml "configs/gnb.yaml" "log" "phy_level" "warning"
update_yaml "configs/gnb.yaml" "log" "radio_level" "warning"
update_yaml "configs/gnb.yaml" "log" "hex_max_size" "0"
update_yaml "configs/gnb.yaml" "log" "high_latency_diagnostics_enabled" "false"

# Packet capture for NGAP
update_yaml "configs/gnb.yaml" "pcap" "ngap_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "ngap_filename" "$SCRIPT_DIR/logs/gnb_ngap.pcap"
# Packet capture for N3
update_yaml "configs/gnb.yaml" "pcap" "n3_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "n3_filename" "$SCRIPT_DIR/logs/gnb_n3.pcap"
# Packet capture for E1AP
update_yaml "configs/gnb.yaml" "pcap" "e1ap_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "e1ap_filename" "$SCRIPT_DIR/logs/gnb_e1ap.pcap"
# Packet capture for E2AP
update_yaml "configs/gnb.yaml" "pcap" "e2ap_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "e2ap_cu_cp_filename" "$SCRIPT_DIR/logs/gnb_e2ap_cu_cp.pcap"
update_yaml "configs/gnb.yaml" "pcap" "e2ap_cu_up_filename" "$SCRIPT_DIR/logs/gnb_e2ap_cu_up.pcap"
update_yaml "configs/gnb.yaml" "pcap" "e2ap_du_filename" "$SCRIPT_DIR/logs/gnb_e2ap_du.pcap"
# Packet capture for F1AP
update_yaml "configs/gnb.yaml" "pcap" "f1ap_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "f1ap_filename" "$SCRIPT_DIR/logs/gnb_f1ap.pcap"
# Packet capture for F1U
update_yaml "configs/gnb.yaml" "pcap" "f1u_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "f1u_filename" "$SCRIPT_DIR/logs/gnb_f1u.pcap"
# Packet capture for RLC
update_yaml "configs/gnb.yaml" "pcap" "rlc_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "rlc_rb_type" "all" # Supported: [all, srb, drb]
update_yaml "configs/gnb.yaml" "pcap" "rlc_filename" "$SCRIPT_DIR/logs/gnb_rlc.pcap"
# Packet capture for MAC
update_yaml "configs/gnb.yaml" "pcap" "mac_enable" "false"
update_yaml "configs/gnb.yaml" "pcap" "mac_type" "udp" # Supported: [dlt, udp]
update_yaml "configs/gnb.yaml" "pcap" "mac_filename" "$SCRIPT_DIR/logs/gnb_mac.pcap"

# Update configuration for metrics (for Grafana)
update_yaml "configs/gnb.yaml" "metrics" "autostart_stdout_metrics" "true"
update_yaml "configs/gnb.yaml" "metrics" "enable_json" "true"
update_yaml "configs/gnb.yaml" "metrics" "layers.enable_rlc" "true"   # E2SM-KPM style 3 uses RLC reports to find UEs
update_yaml "configs/gnb.yaml" "remote_control" "bind_addr" "0.0.0.0" # Grafana
update_yaml "configs/gnb.yaml" "remote_control" "enabled" "true"
# update_yaml "configs/gnb.yaml" "metrics" "addr" "127.0.0.1"
# update_yaml "configs/gnb.yaml" "metrics" "port" "55555"
# update_yaml "configs/gnb.yaml" "metrics" "enable_json" "false"
# update_yaml "configs/gnb.yaml" "metrics" "enable_log" "false"
# update_yaml "configs/gnb.yaml" "metrics" "enable_verbose" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_app_usage" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_e1ap" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_pdcp" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_cu_up_executor" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_sched" "true"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_mac" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_executor" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_du_low" "false"
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_ru" "false"
# update_yaml "configs/gnb.yaml" "metrics" "periodicity.app_usage_report_period" "1000"
# update_yaml "configs/gnb.yaml" "metrics" "periodicity.cu_cp_report_period" "1000"
# update_yaml "configs/gnb.yaml" "metrics" "periodicity.cu_up_report_period" "1000"
# update_yaml "configs/gnb.yaml" "metrics" "periodicity.du_report_period" "1000"

# For ZeroMQ, change otw_format to default
update_yaml "configs/gnb.yaml" "ru_sdr" "otw_format" "default"

# if [ $(nproc) -lt 4 ]; then
#    echo "The number of threads is less than 4. Setting nof_threads to $(nproc)."
#    update_yaml "configs/gnb.yaml" "expert_execution.threads.main_pool" "nof_threads" "$(nproc)"
# fi

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    if [ ! -f "install_scripts/generate_zmq_broker.sh" ]; then
        echo "ERROR: Could not find install_scripts/generate_zmq_broker.sh."
        exit 1
    fi

    echo "Generating ZeroMQ Broker Python script..."

    BROKER_SRATE_INT=$(awk "BEGIN { printf \"%d\", $GNB_SRATE_MHZ * 1000000 }")

    ZMQ_BROKER_SLOW_DOWN_RATIO="1"
    # # Optionally, calculate the slow down ratio based on the number of UEs and cells
    # ZMQ_BROKER_SLOW_DOWN_RATIO="$((${#UE_NUMBERS[@]} + ${#CELL_NUMBERS[@]}))"

    BROKER_UE_CONFIGS=()
    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
        UE_IP=$(../User_Equipment/install_scripts/get_ue_namespace_ip.sh ue "$UE_NUMBER")
        BROKER_UE_CONFIGS+=("$UE_NUMBER:$UE_IP")
    done
    BROKER_UE_CONFIGS_STR=$(
        IFS=,
        echo "${BROKER_UE_CONFIGS[*]}"
    )
    BROKER_CELL_NUMBERS_STR=$(
        IFS=,
        echo "${CELL_NUMBERS[*]}"
    )

    mkdir -p zmq_broker
    ./install_scripts/generate_zmq_broker.sh --output "zmq_broker/multi_ue_scenario.py" --sample-rate-hz "$BROKER_SRATE_INT" --slow-down-ratio "$ZMQ_BROKER_SLOW_DOWN_RATIO" --cells "$BROKER_CELL_NUMBERS_STR" --ues "$BROKER_UE_CONFIGS_STR"

    if ! python3 -c "import gnuradio, PyQt5" >/dev/null 2>&1; then
        echo "Installing GNU Radio runtime for the ZeroMQ Broker..."
        sudo env $APTVARS apt-get install -y gnuradio python3-pyqt5
    fi

    # # GNU Radio 3.8 issue with vmcircbuf_default_factory.
    # mkdir -p ~/.gnuradio/prefs
    # if [ ! -f ~/.gnuradio/prefs/vmcircbuf_default_factory ]; then
    #     echo "gr::vmcircbuf_mmap_shm_open_factory" >~/.gnuradio/prefs/vmcircbuf_default_factory
    #     #echo "gr::vmcircbuf_sysv_shm_factory" >~/.gnuradio/prefs/vmcircbuf_default_factory
    # fi
    rm -f ~/.gnuradio/prefs/vmcircbuf_default_factory

    echo "Successfully generated ZeroMQ broker for UEs: [${UE_NUMBERS[*]}], Cells: [${CELL_NUMBERS[*]}]."
else
    echo "Using direct ZeroMQ connection for UE $UE_NUMBER at *:2100 and $UE_IP:2101 (no ZeroMQ broker)."
fi

echo "Successfully configured the gNodeB. The configuration file is located in the configs/ directory."

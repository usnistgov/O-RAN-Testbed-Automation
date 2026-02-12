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
cd "$SCRIPT_DIR"

BASE_EXAMPLE_CONFIG_PATH="$SCRIPT_DIR/srsRAN_Project/configs/gnb_rf_b210_fdd_srsUE.yml"

# Parse command-line arguments
ENABLE_E2_TERM="true"
E2_ADDRESS="null"
while [[ $# -gt 0 ]]; do
    case $1 in
    --disable-e2-term)
        ENABLE_E2_TERM="false"
        shift
        ;;
    --e2-term-address)
        E2_ADDRESS="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

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

# Configure the DNN, SST, and SD values
DNN=$(sed -n 's/^dnn: //p' "$YAML_PATH")
SST=($(yq eval '.slices[].sst' "$YAML_PATH"))
SD=($(yq eval '.slices[].sd' "$YAML_PATH"))
if [[ -z "$DNN" || "$DNN" == "null" ]]; then
    echo "DNN is not set in $YAML_PATH, please ensure that \"dnn\" is set."
    exit 1
fi
if [[ -z "${SST[0]}" || "${SST[0]}" == "null" ]]; then
    echo "SST is not set in $YAML_PATH, please ensure that \"slices[].sst\" is set."
    exit 1
fi

# Ensure the correct YAML editor is installed
"$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

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

if [ ! -d "../RAN_Intelligent_Controllers/Near-Real-Time-RIC" ]; then
    echo "Could not find the Near-Real-Time-RIC directory. Disabling E2 termination support."
    ENABLE_E2_TERM="false"
fi

if [ "$ENABLE_E2_TERM" = "true" ]; then
    PORT_E2TERM=36422

    # If E2_ADDRESS is provided, override logic and force E2 address
    if [ "$E2_ADDRESS" != "null" ]; then
        IP_E2TERM="$E2_ADDRESS"
        IP_E2TERM_BIND="$E2_ADDRESS"
        echo "E2_ADDRESS provided: $E2_ADDRESS"
        echo "IP_E2TERM: $IP_E2TERM"
        echo "PORT_E2TERM: $PORT_E2TERM"
        echo "IP_E2TERM_BIND: $IP_E2TERM_BIND"
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
    # If the PROPERTY is nested (contains dots), handle it properly
    if [[ "$PROPERTY" == *.* ]]; then
        local PARENT_PROPERTY=$(echo "$PROPERTY" | cut -d '.' -f 1)
        local NESTED_PROPERTY=$(echo "$PROPERTY" | cut -d '.' -f 2-)

        yq eval -i "${SECTION}.${PARENT_PROPERTY}.${NESTED_PROPERTY} = \"$VALUE\"" "$FILE_PATH"
    else
        # If the value is numeric or boolean, don't quote it
        # PLMN should always be treated as a string
        if [[ "$PROPERTY" == "plmn" || "$PROPERTY" == "plmn_list" ]]; then
            yq eval -i "${SECTION}.${PROPERTY} = \"$VALUE\"" "$FILE_PATH"
        elif [[ "$VALUE" =~ ^[0-9]+$ || "$VALUE" =~ ^[0-9]+\.[0-9]+$ || "$VALUE" =~ ^(true|false)$ ]]; then
            yq eval -i "${SECTION}.${PROPERTY} = ${VALUE}" "$FILE_PATH"
        else
            yq eval -i "${SECTION}.${PROPERTY} = \"$VALUE\"" "$FILE_PATH"
        fi
    fi
}

mkdir -p "$SCRIPT_DIR/logs"

DEVICE_ARGS="tx_port0=tcp://127.0.0.1:2000,rx_port0=tcp://127.0.0.1:2001,base_srate=23.04e6"
# DEVICE_ARGS="" # Multiple RF devices:
# DEVICE_ARGS+="tx_port0=tcp://127.0.0.1:2100,rx_port0=tcp://127.0.0.1:2101,"
# DEVICE_ARGS+="tx_port1=tcp://127.0.0.1:2200,rx_port1=tcp://127.0.0.1:2201,"
# DEVICE_ARGS+="tx_port2=tcp://127.0.0.1:2300,rx_port2=tcp://127.0.0.1:2301,"
# DEVICE_ARGS+="base_srate=23.04e6"

# Update configuration values for AMF connection
update_yaml "configs/gnb.yaml" "cu_cp.amf" "addr" "$AMF_ADDR"
update_yaml "configs/gnb.yaml" "cu_cp.amf" "bind_addr" "$N2_ADDR_BIND"
update_yaml "configs/gnb.yaml" "cu_cp.amf.supported_tracking_areas[0]" "tac" $TAC
update_yaml "configs/gnb.yaml" "cu_cp.amf.supported_tracking_areas[0].plmn_list[0]" "plmn" $PLMN
update_yaml "configs/gnb.yaml" "cu_cp.inactivity_timer" "7200"
update_yaml "configs/gnb.yaml" "cu_cp.request_pdu_session_timeout" "3"

# Update configuration values for RF front-end device
update_yaml "configs/gnb.yaml" "ru_sdr" "device_driver" "zmq"
update_yaml "configs/gnb.yaml" "ru_sdr" "device_args" "$DEVICE_ARGS"
update_yaml "configs/gnb.yaml" "ru_sdr" "srate" "23.04"
update_yaml "configs/gnb.yaml" "ru_sdr" "clock" "default"
update_yaml "configs/gnb.yaml" "ru_sdr" "sync" "default"

# Update configuration values for 5G cell parameters
update_yaml "configs/gnb.yaml" "cell_cfg" "nof_antennas_dl" "1"
update_yaml "configs/gnb.yaml" "cell_cfg" "nof_antennas_ul" "1"
update_yaml "configs/gnb.yaml" "cell_cfg" "plmn" $PLMN
update_yaml "configs/gnb.yaml" "cell_cfg" "tac" $TAC

# Update configuration values for slicing
# Clear existing slice configuration
yq eval -i 'del(.cell_cfg.slicing)' "configs/gnb.yaml"
yq eval -i 'del(.cu_cp.amf.supported_tracking_areas[0].plmn_list[0].tai_slice_support_list)' "configs/gnb.yaml"

SLICE_IDX=0
declare -A OMIT_SD
declare -A OMIT_SD_ADDED

# Check for omitting SD if null or FFFFFF (case insensitive)
for i in "${!SST[@]}"; do
    CURRENT_SST="${SST[$i]}"
    CURRENT_SD="${SD[$i]}"
    if [[ "$CURRENT_SD" == "null" || "${CURRENT_SD^^}" == "FFFFFF" ]]; then
        OMIT_SD["$CURRENT_SST"]=1
    fi
done

for i in "${!SST[@]}"; do
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
RAN_NODE_NAME="srsgnb01"
GNB_DU_ID="0"
update_yaml "configs/gnb.yaml" "" "gnb_id" "$GNB_ID"
update_yaml "configs/gnb.yaml" "" "gnb_id_bit_length" "22" # Supported: 22-32
update_yaml "configs/gnb.yaml" "" "ran_node_name" "$RAN_NODE_NAME"
update_yaml "configs/gnb.yaml" "" "gnb_du_id" "$GNB_DU_ID"

# Update configuration values to connect RIC by e2 interface
if [ "$ENABLE_E2_TERM" = "true" ]; then
    update_yaml "configs/gnb.yaml" "e2" "enable_du_e2" "true"
    update_yaml "configs/gnb.yaml" "e2" "enable_cu_cp_e2" "false"
    update_yaml "configs/gnb.yaml" "e2" "enable_cu_up_e2" "false"
    update_yaml "configs/gnb.yaml" "e2" "e2sm_kpm_enabled" "true"
    update_yaml "configs/gnb.yaml" "e2" "e2sm_rc_enabled" "true"
    update_yaml "configs/gnb.yaml" "e2" "addr" "$IP_E2TERM"
    update_yaml "configs/gnb.yaml" "e2" "bind_addr" "$IP_E2TERM_BIND"
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
update_yaml "configs/gnb.yaml" "cu_cp" "request_pdu_session_timeout" "3"

# Update configuration values for gNodeB logging
update_yaml "configs/gnb.yaml" "log" "filename" "$SCRIPT_DIR/logs/gnb.log"
update_yaml "configs/gnb.yaml" "log" "all_level" "none"
update_yaml "configs/gnb.yaml" "log" "hex_max_size" "0"

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

# Update configuration for metrics
# update_yaml "configs/gnb.yaml" "metrics" "autostart_stdout_metrics" "false"
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
# update_yaml "configs/gnb.yaml" "metrics" "layers.enable_rlc" "false"
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

if [ $(nproc) -lt 4 ]; then
    echo "The number of threads is less than 4. Setting nof_non_rt_threads to $(nproc)."
    update_yaml "configs/gnb.yaml" "expert_execution.threads.non_rt" "nof_non_rt_threads" "$(nproc)"
fi

echo "Successfully configured the gNodeB. The configuration file is located in the configs/ directory."

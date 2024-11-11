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

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
fi

echo "Restoring gNodeB configuration file..."
rm -rf configs
mkdir configs
rm -rf logs
cp srsRAN_Project/configs/gnb_rf_b200_tdd_n78_20mhz.yml configs/gnb.yaml

# Function to prompt user for IP address
prompt_for_e2term_ip() {
    echo "Please enter the IP address of the service." >&2
    echo "You can find this by running: kubectl get service -n ricplt | grep service-ricplt-e2term-sctp" >&2
    read -p "Enter IP Address: " USER_IP
    echo "$USER_IP"
}

ENABLE_E2_TERM="true"
if [ ! -d "../RAN_Intelligent_Controllers/Near-Real-Time-RIC" ]; then
    echo "Could not find the Near-Real-Time-RIC directory. Disabling E2 termination support."
    ENABLE_E2_TERM="false"
fi

if [ "$ENABLE_E2_TERM" = "true" ]; then
    echo "Fetching E2 termination service IP address..."

    INSIDE_CLUSTER="true"
    # echo "Are you connecting to the e2term from inside the Kubernetes cluster? [yes/no]"
    # read -p "Enter choice (yes/no): " INSIDE_CLUSTER
    if [ "$INSIDE_CLUSTER" = "yes" ]; then
        PORT_E2TERM=36422
    else
        PORT_E2TERM=32222
    fi

    # Check if kubectl is installed
    if ! command -v kubectl &>/dev/null; then
        echo "Could not find kubectl."
        IP_E2TERM=$(prompt_for_e2term_ip)
    else
        SERVICE_INFO=$(kubectl get service -n ricplt | grep service-ricplt-e2term-sctp)

        # Check if SERVICE_INFO is empty
        if [ -z "$SERVICE_INFO" ]; then
            echo "No service found or kubectl command failed."
            IP_E2TERM=$(prompt_for_e2term_ip)
        else
            # Use awk to extract the IP and the correct port based on the connection context
            IP_E2TERM=$(echo "$SERVICE_INFO" | awk '{print $3}')
            if [ "$INSIDE_CLUSTER" = "true" ]; then
                PORT_E2TERM=$(echo "$SERVICE_INFO" | awk '{print $5}' | cut -d ':' -f1)
            else
                PORT_E2TERM=$(echo "$SERVICE_INFO" | awk '{print $5}' | cut -d ':' -f2)
            fi

            if [ -z "$IP_E2TERM" ] || [ "$IP_E2TERM" == "<none>" ]; then
                IP_E2TERM=$(prompt_for_e2term_ip)
            fi
        fi
    fi
    echo "IP_E2TERM: $IP_E2TERM"
    echo "PORT_E2TERM: $PORT_E2TERM"
fi

echo "Fetching AMF addresses..."
FILE_PATH="../5G_Core_Network/configs/get_amf_address.txt"

prompt_for_addresses() {
    echo "Please enter the AMF address and the AMF binding address manually." >&2
    echo "You can find this information in the 5G_Core_Network/configs/get_amf_addresses.txt file in the first two lines, respectively." >&2
    read -p "Enter AMF Address: " AMF_ADDR
    read -p "Enter AMF Binding Address: " AMF_ADDR_BIND
}

# Check if the file exists and has at least two lines
if [[ -f "$FILE_PATH" ]]; then
    # Read the file and check for at least two non-empty lines
    mapfile -t addresses <"$FILE_PATH"
    if [[ ${#addresses[@]} -ge 2 ]] && [[ -n ${addresses[0]} ]] && [[ -n ${addresses[1]} ]]; then
        AMF_ADDR="${addresses[0]}"
        AMF_ADDR_BIND="${addresses[1]}"
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

# Function to update or add YAML configuration properties using yq
update_yaml() {
    echo "update_yaml($1, $2, $3, $4)"
    local FILE_PATH=$1
    local SECTION=$2
    local PROPERTY=$3
    local VALUE=$4
    # Check if the value is specifically intended to be null
    if [[ "$VALUE" == "null" ]]; then
        yq eval -i ".${SECTION}.${PROPERTY} = null" "$FILE_PATH"
        return
    fi
    # If value is empty or undefined, skip the update
    if [[ -z "$VALUE" ]]; then
        echo "Skipping empty value for $SECTION.$PROPERTY"
        return
    fi
    # If the PROPERTY is nested (contains dots), handle it properly
    if [[ "$PROPERTY" == *.* ]]; then
        local parent_property=$(echo "$PROPERTY" | cut -d '.' -f 1)
        local nested_property=$(echo "$PROPERTY" | cut -d '.' -f 2-)

        yq eval -i ".${SECTION}.${parent_property}.${nested_property} = \"$VALUE\"" "$FILE_PATH"
    else
        # If the value is numeric or boolean, don't quote it
        # PLMN should always be treated as a string
        if [[ "$PROPERTY" == "plmn" || "$PROPERTY" == "plmn_list" ]]; then
            yq eval -i ".${SECTION}.${PROPERTY} = \"$VALUE\"" "$FILE_PATH"
        elif [[ "$VALUE" =~ ^[0-9]+$ || "$VALUE" =~ ^[0-9]+\.[0-9]+$ || "$VALUE" =~ ^(true|false)$ ]]; then
            yq eval -i ".${SECTION}.${PROPERTY} = ${VALUE}" "$FILE_PATH"
        else
            yq eval -i ".${SECTION}.${PROPERTY} = \"$VALUE\"" "$FILE_PATH"
        fi
    fi
}

mkdir -p logs

DEVICE_ARGS=""
DEVICE_ARGS+="tx_port0=tcp://127.0.0.1:2000,rx_port0=tcp://127.0.0.1:2001,base_srate=23.04e6"
# DEVICE_ARGS="" # Multiple RF devices:
# DEVICE_ARGS+="tx_port0=tcp://127.0.0.1:2100,rx_port0=tcp://127.0.0.1:2101,"
# DEVICE_ARGS+="tx_port1=tcp://127.0.0.1:2200,rx_port1=tcp://127.0.0.1:2201,"
# DEVICE_ARGS+="tx_port2=tcp://127.0.0.1:2300,rx_port2=tcp://127.0.0.1:2301,"
# DEVICE_ARGS+="base_srate=23.04e6"

# Update configuration values for AMF connection
update_yaml configs/gnb.yaml "cu_cp.amf" "addr" "$AMF_ADDR"
update_yaml configs/gnb.yaml "cu_cp.amf" "bind_addr" "$AMF_ADDR_BIND"

# Update configuration values for RF front-end device
update_yaml configs/gnb.yaml "ru_sdr" "device_driver" "zmq"
update_yaml configs/gnb.yaml "ru_sdr" "device_args" "$DEVICE_ARGS"
update_yaml configs/gnb.yaml "ru_sdr" "srate" "23.04"
update_yaml configs/gnb.yaml "ru_sdr" "tx_gain" "75"
update_yaml configs/gnb.yaml "ru_sdr" "rx_gain" "75"
update_yaml configs/gnb.yaml "ru_sdr" "clock" null
update_yaml configs/gnb.yaml "ru_sdr" "sync" null

# Update configuration values for 5G cell parameters
update_yaml configs/gnb.yaml "cell_cfg" "dl_arfcn" "368500" # NR ARFCN
update_yaml configs/gnb.yaml "cell_cfg" "nof_antennas_dl" "1"
update_yaml configs/gnb.yaml "cell_cfg" "nof_antennas_ul" "1"
update_yaml configs/gnb.yaml "cell_cfg" "band" "3"
update_yaml configs/gnb.yaml "cell_cfg" "channel_bandwidth_MHz" "20"
update_yaml configs/gnb.yaml "cell_cfg" "common_scs" "15"
update_yaml configs/gnb.yaml "cell_cfg" "plmn" $PLMN
update_yaml configs/gnb.yaml "cell_cfg" "tac" $TAC

# Update configuration values to connect RIC by e2 interface
if [ "$ENABLE_E2_TERM" = "true" ]; then
    update_yaml configs/gnb.yaml "e2" "enable_cu_e2" "true"
    update_yaml configs/gnb.yaml "e2" "enable_du_e2" "true"
    update_yaml configs/gnb.yaml "e2" "e2sm_kpm_enabled" "true"
    update_yaml configs/gnb.yaml "e2" "e2sm_rc_enabled" "true"
    update_yaml configs/gnb.yaml "e2" "addr" "$IP_E2TERM"
    update_yaml configs/gnb.yaml "e2" "bind_addr" "$IP_E2TERM"
    update_yaml configs/gnb.yaml "e2" "port" "$PORT_E2TERM"
else
    update_yaml configs/gnb.yaml "e2" "enable_cu_e2" "false"
    update_yaml configs/gnb.yaml "e2" "enable_du_e2" "false"
    update_yaml configs/gnb.yaml "e2" "e2sm_kpm_enabled" "false"
    update_yaml configs/gnb.yaml "e2" "e2sm_rc_enabled" "false"
    update_yaml configs/gnb.yaml "e2" "addr" null
    update_yaml configs/gnb.yaml "e2" "bind_addr" null
    update_yaml configs/gnb.yaml "e2" "port" null
fi

# Update configuration values for CU and other settings
update_yaml configs/gnb.yaml "cu_cp" "inactivity_timer" "7200"
update_yaml configs/gnb.yaml "log" "filename" "logs/gnb.log"
update_yaml configs/gnb.yaml "log" "all_level" "info"
update_yaml configs/gnb.yaml "log" "hex_max_size" "0"

update_yaml configs/gnb.yaml "pcap" "mac_enable" "false"
update_yaml configs/gnb.yaml "pcap" "ngap_enable" "false"
update_yaml configs/gnb.yaml "pcap" "e2ap_enable" "false"
# Uncomment for log files:
# update_yaml configs/gnb.yaml "pcap" "mac_enable" "true"
# update_yaml configs/gnb.yaml "pcap" "ngap_enable" "true"
# update_yaml configs/gnb.yaml "pcap" "e2ap_enable" "true"
update_yaml configs/gnb.yaml "pcap" "mac_filename" "logs/gnb_mac.pcap"
update_yaml configs/gnb.yaml "pcap" "ngap_filename" "logs/gnb_ngap.pcap"
update_yaml configs/gnb.yaml "pcap" "e2ap_filename" "logs/gnb_e2ap.pcap"
# update_yaml configs/gnb.yaml "metrics" "rlc_json_enable" "1"
# update_yaml configs/gnb.yaml "metrics" "rlc_report_period" "1000"

# Update configuration values for PDCCH and PRACH
update_yaml configs/gnb.yaml "cell_cfg.pdcch.common" "ss0_index" "0"
update_yaml configs/gnb.yaml "cell_cfg.pdcch.common" "coreset0_index" "12"
update_yaml configs/gnb.yaml "cell_cfg.pdcch.dedicated" "ss2_type" "common"
update_yaml configs/gnb.yaml "cell_cfg.pdcch.dedicated" "dci_format_0_1_and_1_1" "false"
update_yaml configs/gnb.yaml "cell_cfg.prach" "prach_config_index" "1"

# For ZeroMQ, change otw_format from sc12 --> null
update_yaml configs/gnb.yaml "ru_sdr" "otw_format" null

mkdir -p logs
sudo chown $USER:$USER -R logs

echo "Successfully configured the gNodeB. The configuration file is located in the configs/ directory."

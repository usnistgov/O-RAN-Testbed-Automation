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

EXAMPLE_CONFIG_PATH="$SCRIPT_DIR/srsRAN_4G/srsue/ue.conf.example"
CLEAR_CONFIGS=false
UE_NR_PROFILE="srsue" # Supported: srsue, generic_fr1
ZMQ_DEBUG_ARGS=""     # Example: fail_on_disconnect=true,log_trx_timeout=true,trx_timeout_ms=1000

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
        echo "ERROR: UE number must be a number."
        exit 1
    fi
    if [ "$i" -lt 1 ]; then
        echo "ERROR: UE number must be greater than or equal to 1."
        exit 1
    fi
    echo "UE $i will be configured."
done

# Ensure the correct YAML editor is installed
"$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

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

# Function to update or add configuration properties in .conf files, considering sections and uncommenting if needed
update_conf() {
    echo "update_conf($1, $2, $3, $4)"
    local FILE_PATH="$1"
    local SECTION="$2"
    local PROPERTY="$3"
    local VALUE="$4"

    # Ensure the section exists; if not, add it at the end
    if ! grep -q "^\[$SECTION\]" "$FILE_PATH"; then
        echo -e "\n[$SECTION]" >>"$FILE_PATH"
    fi
    # Remove any existing entries of the property in the section (including commented ones)
    sed -i "/^\[$SECTION\]/,/^\s*\[/{/^[# ]*\s*$PROPERTY\s*=.*/d}" "$FILE_PATH"
    # Append the new property=value after the section header
    sed -i "/^\[$SECTION\]/a $PROPERTY = $VALUE" "$FILE_PATH"
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
CURRENT_DNN=$(yq eval '.slices[0].dnn' "$YAML_PATH")
SST=$(yq eval '.slices[0].sst' "$YAML_PATH")
SD=$(yq eval '.slices[0].sd' "$YAML_PATH")
if [[ -z "$CURRENT_DNN" || "$CURRENT_DNN" == "null" ]]; then
    echo "DNN is not set in "$YAML_PATH", please ensure that \"dnn\" is set."
    exit 1
fi
if [[ -z "$SST" || -z "$SD" || "$SST" == "null" || "$SD" == "null" ]]; then
    echo "SST or SD is not set in "$YAML_PATH", please ensure that \"slices[].sst\" and \"slices[].sd\" are set."
    exit 1
fi

# SST/SD are configured in options.yaml as hex without 0x prefix.
SST_HEX="${SST#0x}"
SST_HEX="${SST_HEX#0X}"
SST_HEX="${SST_HEX^^}"
SD_HEX="${SD#0x}"
SD_HEX="${SD_HEX#0X}"
SD_HEX="${SD_HEX^^}"

if [[ ! "$SST_HEX" =~ ^[0-9A-F]{1,2}$ ]]; then
    echo "Invalid slices[0].sst '$SST'. Use hexadecimal (00-FF), no 0x prefix."
    exit 1
fi
if [[ ! "$SD_HEX" =~ ^[0-9A-F]{1,6}$ ]]; then
    echo "Invalid slices[0].sd '$SD'. Use hexadecimal (up to 6 hex digits), no 0x prefix."
    exit 1
fi

SST_DEC=$((16#$SST_HEX))
SD_HEX=$(printf "%06X" "$((16#$SD_HEX))")

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

if [ ! -f "$EXAMPLE_CONFIG_PATH" ]; then
    echo "Configuration file example not found in $EXAMPLE_CONFIG_PATH, please ensure that the file exists."
    exit 1
fi

# NOTE: Does not validate whether a given operating band supports the selected bandwidth/SCS combination (3GPP 38.104 clause 5.3.5: BS channel bandwidth per operating band)
GNB_CONFIG_PATH="$SCRIPT_DIR/../Next_Generation_Node_B/configs/gnb.yaml"
NR_BAND="3"
NR_DL_ARFCN="368500"
NR_SSB_ARFCN="368410"
NR_NOF_PRB="106"
NR_MAX_NOF_PRB="106"
NR_SCS="15"
GNB_NR_BW_MHZ="20"

if [ -f "$GNB_CONFIG_PATH" ]; then
    GNB_NR_BAND=$(yq eval '.cell_cfg.band // ""' "$GNB_CONFIG_PATH")
    GNB_NR_DL_ARFCN=$(yq eval '.cell_cfg.dl_arfcn // ""' "$GNB_CONFIG_PATH")
    GNB_NR_SSB_ARFCN=$(yq eval '.cell_cfg.dl_ssb_arfcn // ""' "$GNB_CONFIG_PATH")
    GNB_NR_BW_MHZ=$(yq eval '.cell_cfg.channel_bandwidth_MHz // ""' "$GNB_CONFIG_PATH")
    GNB_NR_SCS=$(yq eval '.cell_cfg.common_scs // ""' "$GNB_CONFIG_PATH")

    if [[ "$GNB_NR_BAND" =~ ^[0-9]+$ ]]; then
        NR_BAND="$GNB_NR_BAND"
    fi
    if [[ "$GNB_NR_DL_ARFCN" =~ ^[0-9]+$ ]]; then
        NR_DL_ARFCN="$GNB_NR_DL_ARFCN"
    fi
    if [[ "$GNB_NR_SCS" =~ ^[0-9]+$ ]]; then
        NR_SCS="$GNB_NR_SCS"
    fi

    # 3GPP 38.104, Table 5.3.2-1: Transmission bandwidth configuration NRB for FR1.
    case "${GNB_NR_BW_MHZ}_${NR_SCS}" in
    3_15) NR_NOF_PRB="15" ;;
    5_15) NR_NOF_PRB="25" ;;
    10_15) NR_NOF_PRB="52" ;;
    15_15) NR_NOF_PRB="79" ;;
    20_15) NR_NOF_PRB="106" ;;
    25_15) NR_NOF_PRB="133" ;;
    30_15) NR_NOF_PRB="160" ;;
    35_15) NR_NOF_PRB="188" ;;
    40_15) NR_NOF_PRB="216" ;;
    45_15) NR_NOF_PRB="242" ;;
    50_15) NR_NOF_PRB="270" ;;
    5_30) NR_NOF_PRB="11" ;;
    10_30) NR_NOF_PRB="24" ;;
    15_30) NR_NOF_PRB="38" ;;
    20_30) NR_NOF_PRB="51" ;;
    25_30) NR_NOF_PRB="65" ;;
    30_30) NR_NOF_PRB="78" ;;
    35_30) NR_NOF_PRB="92" ;;
    40_30) NR_NOF_PRB="106" ;;
    45_30) NR_NOF_PRB="119" ;;
    50_30) NR_NOF_PRB="133" ;;
    60_30) NR_NOF_PRB="162" ;;
    70_30) NR_NOF_PRB="189" ;;
    80_30) NR_NOF_PRB="217" ;;
    90_30) NR_NOF_PRB="245" ;;
    100_30) NR_NOF_PRB="273" ;;
    10_60) NR_NOF_PRB="11" ;;
    15_60) NR_NOF_PRB="18" ;;
    20_60) NR_NOF_PRB="24" ;;
    25_60) NR_NOF_PRB="31" ;;
    30_60) NR_NOF_PRB="38" ;;
    35_60) NR_NOF_PRB="44" ;;
    40_60) NR_NOF_PRB="51" ;;
    45_60) NR_NOF_PRB="58" ;;
    50_60) NR_NOF_PRB="65" ;;
    60_60) NR_NOF_PRB="79" ;;
    70_60) NR_NOF_PRB="93" ;;
    80_60) NR_NOF_PRB="107" ;;
    90_60) NR_NOF_PRB="121" ;;
    100_60) NR_NOF_PRB="135" ;;
    *)
        echo "ERROR: Unsupported FR1 NR bandwidth/SCS: ${GNB_NR_BW_MHZ} MHz / ${NR_SCS} kHz (3GPP TS 38.104 Table 5.3.2-1)."
        exit 1
        ;;
    esac
    if [ "$UE_NR_PROFILE" = "srsue" ]; then
        # OCUDU srsUE tutorial limitation: srsUE SA supports 15 kHz SCS with 5, 10, 15, or 20 MHz BW.
        # https://ocudu.gitlab.io/ocudu_docs/tutorials/srsue/#limitations
        case "${GNB_NR_BW_MHZ}_${NR_SCS}" in
        5_15 | 10_15 | 15_15 | 20_15) ;;
        *)
            echo "ERROR: Unsupported srsUE NR bandwidth/SCS: ${GNB_NR_BW_MHZ} MHz / ${NR_SCS} kHz (3GPP TS 38.104 Table 5.3.2-1)."
            echo "Set UE_NR_PROFILE=generic_fr1 only for a UE implementation that supports this numerology."
            exit 1
            ;;
        esac
    elif [ "$UE_NR_PROFILE" != "generic_fr1" ]; then
        echo "ERROR: Unsupported UE_NR_PROFILE '$UE_NR_PROFILE'. Supported: srsue, generic_fr1."
        exit 1
    fi
    NR_MAX_NOF_PRB="$NR_NOF_PRB"

    if [[ "$GNB_NR_SSB_ARFCN" =~ ^[0-9]+$ ]]; then
        NR_SSB_ARFCN="$GNB_NR_SSB_ARFCN"
    elif [[ "$NR_BAND" = "3" && "$NR_DL_ARFCN" = "368500" && "$GNB_NR_BW_MHZ" = "20" && "$NR_SCS" = "15" ]]; then
        NR_SSB_ARFCN="368410"
    else
        echo "ERROR: Could not determine SSB ARFCN for UE config. Set cell_cfg.dl_ssb_arfcn in the gNB config or add a validated derivation for this band/BW/SCS."
        exit 1
    fi
fi

UE_CREDENTIAL_GENERATOR_SCRIPT="$SCRIPT_DIR/ue_credentials_generator.sh"
if [ ! -f "$UE_CREDENTIAL_GENERATOR_SCRIPT" ]; then
    echo "ERROR: Cannot find $UE_CREDENTIAL_GENERATOR_SCRIPT to generate UE subscriber credentials."
    exit 1
fi

for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    cp "$EXAMPLE_CONFIG_PATH" "configs/ue${UE_NUMBER}.conf"

    UE_TX_PORT=$((2001 + UE_NUMBER * 100))
    UE_RX_PORT=$((2000 + UE_NUMBER * 100))

    # Fetch the UE's OPc, IMEI, IMSI, KEY, and NAMESPACE
    read -r UE_OPC UE_IMEI UE_IMSI UE_KEY UE_NAMESPACE < <("$UE_CREDENTIAL_GENERATOR_SCRIPT" "$UE_NUMBER" "$PLMN")

    # Update configuration values for RF front-end device
    update_conf "configs/ue${UE_NUMBER}.conf" "rf" "device_name" "zmq"

    # Calculate IP offsets for this UE using the same subnetting scheme as in setup_ue_namespace.sh
    # Allocate a /30 (4 addresses) subnet per UE (e.g., UE 1 -> 10.201.0.4/30, Gateway .5, UE .6)
    BASE_SUBNET="10.201.0.0/16"
    SUBNET_SIZE=4

    # Calculate IP offsets
    SUBNET_OFFSET=$((UE_NUMBER * SUBNET_SIZE))
    HOST_IP_OFFSET=$((SUBNET_OFFSET))   # .5
    UE_IP_OFFSET=$((SUBNET_OFFSET + 1)) # .6

    UE_HOST_IP=$(python3 install_scripts/fetch_nth_ip.py "$BASE_SUBNET" $HOST_IP_OFFSET)

    DEVICE_ARGS="tx_port=tcp://*:$UE_TX_PORT,rx_port=tcp://$UE_HOST_IP:$UE_RX_PORT,base_srate=23.04e6,id=ue$UE_NUMBER"
    if [ -n "$ZMQ_DEBUG_ARGS" ]; then
        DEVICE_ARGS="$DEVICE_ARGS,$ZMQ_DEBUG_ARGS"
    fi
    update_conf "configs/ue${UE_NUMBER}.conf" "rf" "device_args" "$DEVICE_ARGS"
    update_conf "configs/ue${UE_NUMBER}.conf" "rf" "nof_antennas" "1"
    update_conf "configs/ue${UE_NUMBER}.conf" "rf" "freq_offset" "0"
    update_conf "configs/ue${UE_NUMBER}.conf" "rf" "tx_gain" "35"
    update_conf "configs/ue${UE_NUMBER}.conf" "rf" "rx_gain" "60"
    update_conf "configs/ue${UE_NUMBER}.conf" "rf" "srate" "23.04e6"

    # Update configuration values for RAT (EUTRA)
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.eutra" "nof_carriers" "0" # Disabled EUTRA (LTE) since we are using NR (5G)

    # Update configuration values for RAT (NR)
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "nof_carriers" "1"
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "bands" "$NR_BAND"
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "dl_nr_arfcn" "$NR_DL_ARFCN"
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "ssb_nr_arfcn" "$NR_SSB_ARFCN"
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "max_nof_prb" "$NR_MAX_NOF_PRB"
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "nof_prb" "$NR_NOF_PRB"
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "scs" "$NR_SCS"
    update_conf "configs/ue${UE_NUMBER}.conf" "rat.nr" "ssb_scs" "$NR_SCS"

    # Update configuration values for PCAP
    update_conf "configs/ue${UE_NUMBER}.conf" "pcap" "enable" "none"
    # Uncomment for log files:
    # update_conf "configs/ue${UE_NUMBER}.conf" "pcap" "enable" "mac,mac_nr,nas"
    update_conf "configs/ue${UE_NUMBER}.conf" "pcap" "mac_filename" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_mac.pcap"
    update_conf "configs/ue${UE_NUMBER}.conf" "pcap" "mac_nr_filename" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_mac_nr.pcap"
    update_conf "configs/ue${UE_NUMBER}.conf" "pcap" "nas_filename" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_nas.pcap"

    # Update configuration values for Logging
    update_conf "configs/ue${UE_NUMBER}.conf" "log" "all_level" "warning"
    update_conf "configs/ue${UE_NUMBER}.conf" "log" "phy_lib_level" "warning"
    update_conf "configs/ue${UE_NUMBER}.conf" "log" "all_hex_limit" "32"
    update_conf "configs/ue${UE_NUMBER}.conf" "log" "filename" "$SCRIPT_DIR/logs/ue${UE_NUMBER}.log"
    update_conf "configs/ue${UE_NUMBER}.conf" "log" "file_max_size" "-1"

    # Update configuration values for Metrics
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "metrics_period_secs" "1"
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "metrics_csv_enable" "false"
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "metrics_csv_filename" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_metrics.csv"
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "metrics_json_enable" "false"
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "metrics_json_filename" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_metrics.json"
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "tracing_enable" "true"
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "tracing_filename" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_tracing.log"
    update_conf "configs/ue${UE_NUMBER}.conf" "general" "tracing_buffcapacity" "1000000"

    # Update configuration values for USIM
    update_conf "configs/ue${UE_NUMBER}.conf" "usim" "mode" "soft"
    update_conf "configs/ue${UE_NUMBER}.conf" "usim" "algo" "milenage"
    update_conf "configs/ue${UE_NUMBER}.conf" "usim" "opc" "$UE_OPC"
    update_conf "configs/ue${UE_NUMBER}.conf" "usim" "k" "$UE_KEY"
    update_conf "configs/ue${UE_NUMBER}.conf" "usim" "imsi" "$UE_IMSI"
    update_conf "configs/ue${UE_NUMBER}.conf" "usim" "imei" "$UE_IMEI"

    # Update configuration values for RRC
    update_conf "configs/ue${UE_NUMBER}.conf" "rrc" "release" "15"
    update_conf "configs/ue${UE_NUMBER}.conf" "rrc" "ue_category" "4"

    # Update configuration values for NAS
    update_conf "configs/ue${UE_NUMBER}.conf" "nas" "apn" "$CURRENT_DNN"
    update_conf "configs/ue${UE_NUMBER}.conf" "nas" "apn_protocol" "ipv4"

    # Update configuration values for Slicing
    SD_DEC=$((16#$SD_HEX))
    if [ "$SD_DEC" -eq 16777215 ]; then # 0xFFFFFF
        SD_DEC=0                        # SRS UE expects 0 to indicate "no SD" instead of 16777215 (3GPP TS 23.003 clause 28.4.2)
    fi
    update_conf "configs/ue${UE_NUMBER}.conf" "slicing" "nssai-sd" "$SD_DEC"
    update_conf "configs/ue${UE_NUMBER}.conf" "slicing" "nssai-sst" "$SST_DEC"
    update_conf "configs/ue${UE_NUMBER}.conf" "slicing" "enable" "true"

    # Update configuration values for Gateway
    update_conf "configs/ue${UE_NUMBER}.conf" "gw" "netns" "$UE_NAMESPACE"
    update_conf "configs/ue${UE_NUMBER}.conf" "gw" "ip_devname" "tun_srsue"
    update_conf "configs/ue${UE_NUMBER}.conf" "gw" "ip_netmask" "255.255.255.0"

    # Update configuration values for GUI
    update_conf "configs/ue${UE_NUMBER}.conf" "gui" "enable" "false"

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
            "$REGISTRATION_DIR/./register_subscriber.sh" --imsi "$UE_IMSI" --key "$UE_KEY" --opc "$UE_OPC" --apn "$CURRENT_DNN" --sst "$SST_DEC" --sd "$SD_HEX" $IPV4_LINE || true
        fi
    fi

    echo
    echo "Successfully configured UE ${UE_NUMBER}."
    echo "    OPc:  $UE_OPC"
    echo "    IMEI: $UE_IMEI"
    echo "    IMSI: $UE_IMSI"
    echo "    KEY:  $UE_KEY"
    echo "    PLMN: $PLMN"
    echo "    DNN:  $CURRENT_DNN"
    echo "    SST:  $SST_HEX (hex)"
    echo "    SD:   $SD_HEX (hex)"
    if [ -n "$UE_IPV4" ]; then
        echo "    IPv4: $UE_IPV4"
    fi
    echo

    echo "The configuration file is located in the configs/ directory."
done

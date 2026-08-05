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

RADIO_TYPE="SIMU" # Set to "SIMU", "ZMQ", or "USRP"
MAKE_GNB_E2_NODE=true
MAKE_CU_E2_NODE=true        # MR.NRScSSSINR is collected by RRC and exposed at NRCellCU scope (28.552 clause 5.1.1.32.1(f))
MAKE_DU_E2_NODE=true        # L1M.SS-RSRP and DU/MAC measurements exposed from each DU
ENABLE_NEIGHBOR_CONFIG=true # Allows automatic A2 and A3 event handovers
NEAR_RIC_IP_ADDR="127.0.0.1"

# There are two types of RSRP/SINR measurements: SSB and CSI
# Valid values for CSI_REPORT_TYPE: "ssb_rsrp", "ssb_sinr", "cri_rsrp", or "null" (to omit CSI_report_type and set do_CSIRS=1)
# If using MIMO, then CSI_REPORT_TYPE must not be an SSB-based measurement (https://github.com/duranta-project/openairinterface5g/blob/develop/doc/RUNMODEM.md#5g-gnb-mimo-configuration)
CSI_REPORT_TYPE="ssb_rsrp"

# Radio configuration presets (band 3 and band 78)
GNB_CONFIG_TEMPLATE="openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.sa.band1.u0.52PRB.usrpb210.conf"
NR_BAND="3"
NR_SSB_ARFCNS=("368410")
NR_DL_POINT_A_ARFCNS=("366592")
NR_UL_POINT_A_ARFCN="347592"
NR_CARRIER_BANDWIDTH_RBS="106"
NR_BWP_LOCATION_AND_BANDWIDTH="28875"
NR_CORESET0_INDEX="12"
NR_TIMING_ADVANCE_OFFSET="1"
NR_PREAMBLE_RECEIVED_TARGET_POWER=""
NR_MSG3_DELTA_PREAMBLE=""
NR_PRACH_DTX_THRESHOLD=""
NR_OFDM_OFFSET_DIVISOR=""
NR_PRACH_ROOT_SEQUENCE_INDEX=""
NR_SSB_BITMAP=""
NR_TDD_PERIODICITY=""
NR_TDD_DL_SLOTS=""
NR_TDD_DL_SYMBOLS=""
NR_TDD_UL_SLOTS=""
NR_TDD_UL_SYMBOLS=""
ZMQ_BROKER_SAMPLE_RATE_HZ=23040000
ZMQ_TX_AMP_BACKOFF_DB="12"
#
# GNB_CONFIG_TEMPLATE="openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.sa.band78.fr1.106PRB.usrpb210.conf"
# NR_BAND="78"
# NR_SSB_ARFCNS=("629376" "642624")
# NR_DL_POINT_A_ARFCNS=("628776" "642024")
# NR_UL_POINT_A_ARFCN=""
# NR_CARRIER_BANDWIDTH_RBS="106"
# NR_BWP_LOCATION_AND_BANDWIDTH="28875"
# NR_CORESET0_INDEX="11"
# NR_TIMING_ADVANCE_OFFSET=""
# NR_PREAMBLE_RECEIVED_TARGET_POWER="-110"
# NR_MSG3_DELTA_PREAMBLE="6"
# NR_PRACH_DTX_THRESHOLD="200"
# NR_OFDM_OFFSET_DIVISOR="4294967295"
# NR_PRACH_ROOT_SEQUENCE_INDEX="1"
# NR_SSB_BITMAP="1"
# NR_TDD_PERIODICITY="6"
# NR_TDD_DL_SLOTS="7"
# NR_TDD_DL_SYMBOLS="6"
# NR_TDD_UL_SLOTS="2"
# NR_TDD_UL_SYMBOLS="4"
# ZMQ_BROKER_SAMPLE_RATE_HZ=46080000

NR_SSB_ARFCN="${NR_SSB_ARFCNS[0]}"
NR_DL_POINT_A_ARFCN="${NR_DL_POINT_A_ARFCNS[0]}"

# FLEXRIC_LIBRARY_DIR="/usr/local/lib/flexric/" # Default
FLEXRIC_LIBRARY_DIR="flexric/build/flexric_libraries/lib/flexric/"

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

usage() {
    echo "Usage: $0 [--cells <cell_numbers>] [--ues <ue_numbers>]"
    echo "    For example: $0 --ues 4,5,6 --cells 1,2"
}

UE_NUMBERS=()
CELL_NUMBERS=()
while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
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
        IFS=',' read -r -a PARSED_UE_NUMBERS <<<"$2"
        for UE_NUMBER in "${PARSED_UE_NUMBERS[@]}"; do
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

FLEXRIC_LIBRARY_DIR="../RAN_Intelligent_Controllers/Flexible-RIC/$FLEXRIC_LIBRARY_DIR"
if [[ "$FLEXRIC_LIBRARY_DIR" != /* ]]; then
    FULL_SM_DIR="$(realpath "$SCRIPT_DIR/$FLEXRIC_LIBRARY_DIR" 2>/dev/null || echo "$SCRIPT_DIR/$FLEXRIC_LIBRARY_DIR")"
else
    FULL_SM_DIR="$FLEXRIC_LIBRARY_DIR"
fi
if [[ "$FULL_SM_DIR" != */ ]]; then
    FULL_SM_DIR="${FULL_SM_DIR}/"
fi

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

# Define the path to the 5G Core YAML file
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

# SST/SD are configured in options.yaml as hex without 0x prefix
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

SNSSAI_LIST="("
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

FIRST_ENTRY=1
for i in "${!SST[@]}"; do
    CURRENT_DNN="${DNN[$i]}"
    CURRENT_SST="${SST[$i]}"
    CURRENT_SD="${SD[$i]}"

    # If SST has SD wildcard, only add SST to the list
    if [[ -n "${OMIT_SD[$CURRENT_SST]}" ]]; then
        if [[ -z "${OMIT_SD_ADDED[$CURRENT_SST]}" ]]; then # Uniqueness
            if [ "$FIRST_ENTRY" -eq 0 ]; then SNSSAI_LIST+=", "; fi
            SNSSAI_LIST+="{ sst = $CURRENT_SST; }"
            OMIT_SD_ADDED["$CURRENT_SST"]=1
            FIRST_ENTRY=0
        fi
    else
        # Entry with SST and SD
        if [ "$FIRST_ENTRY" -eq 0 ]; then SNSSAI_LIST+=", "; fi
        SNSSAI_LIST+="{ sst = $CURRENT_SST; sd = 0x$CURRENT_SD; }"
        FIRST_ENTRY=0
    fi
done
SNSSAI_LIST+=")"

# Ensure the correct YAML editor is installed
"$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

echo "Saving configuration file example..."
rm -rf configs || sudo rm -rf configs
mkdir configs
echo "$RADIO_TYPE" >configs/radio_type.txt

# Only remove the logs if not running
RUNNING_STATUS=$(./is_running.sh)
if [[ $RUNNING_STATUS != *": RUNNING"* ]]; then
    rm -rf logs || sudo rm -rf logs
    mkdir logs
fi

cp "$GNB_CONFIG_TEMPLATE" "$SCRIPT_DIR/configs/gnb.conf"

# Fix configuration file syntax errors, e.g., item : { -> item = {
sed -i -E 's/^([[:space:]]*vrtsim)[[:space:]]*:[[:space:]]*\{[[:space:]]*$/\1 = {/g' "$SCRIPT_DIR/configs/gnb.conf"
sed -i -E ':a;N;$!ba;s/^([[:space:]]*vrtsim)[[:space:]]*:[[:space:]]*\n[[:space:]]*\{[[:space:]]*$/\1 = {/m' "$SCRIPT_DIR/configs/gnb.conf"
sed -i "/^[[:space:]]*do_SRS[[:space:]]*=/a\\    force_UL256qam_off = 1;" "configs/gnb.conf"
sed -i "/^[[:space:]]*do_SRS[[:space:]]*=/a\\    force_256qam_off = 1;" "configs/gnb.conf"

update_conf "configs/gnb.conf" "dl_frequencyBand" "$NR_BAND"
update_conf "configs/gnb.conf" "ul_frequencyBand" "$NR_BAND"
if [ -n "$NR_SSB_ARFCN" ]; then
    update_conf "configs/gnb.conf" "absoluteFrequencySSB" "$NR_SSB_ARFCN"
fi
if [ -n "$NR_DL_POINT_A_ARFCN" ]; then
    update_conf "configs/gnb.conf" "dl_absoluteFrequencyPointA" "$NR_DL_POINT_A_ARFCN"
fi
if [ -n "$NR_CARRIER_BANDWIDTH_RBS" ]; then
    update_conf "configs/gnb.conf" "dl_carrierBandwidth" "$NR_CARRIER_BANDWIDTH_RBS"
    update_conf "configs/gnb.conf" "ul_carrierBandwidth" "$NR_CARRIER_BANDWIDTH_RBS"
fi
if [ -n "$NR_CORESET0_INDEX" ]; then
    update_conf "configs/gnb.conf" "initialDLBWPcontrolResourceSetZero" "$NR_CORESET0_INDEX"
fi
if [ -n "$NR_BWP_LOCATION_AND_BANDWIDTH" ]; then
    update_conf "configs/gnb.conf" "initialDLBWPlocationAndBandwidth" "$NR_BWP_LOCATION_AND_BANDWIDTH"
    update_conf "configs/gnb.conf" "initialULBWPlocationAndBandwidth" "$NR_BWP_LOCATION_AND_BANDWIDTH"
fi
if [ -n "$NR_TIMING_ADVANCE_OFFSET" ]; then
    if grep -q "^[[:space:]]*n_TimingAdvanceOffset[[:space:]]*=" "configs/gnb.conf"; then
        update_conf "configs/gnb.conf" "n_TimingAdvanceOffset" "$NR_TIMING_ADVANCE_OFFSET"
    else
        sed -i "/^[[:space:]]*p0_nominal[[:space:]]*=/a\\        n_TimingAdvanceOffset = $NR_TIMING_ADVANCE_OFFSET;" "configs/gnb.conf"
    fi
fi
if [ -n "$NR_UL_POINT_A_ARFCN" ]; then
    update_conf "configs/gnb.conf" "ul_absoluteFrequencyPointA" "$NR_UL_POINT_A_ARFCN"
fi
if [ -n "$NR_PREAMBLE_RECEIVED_TARGET_POWER" ]; then
    update_conf "configs/gnb.conf" "preambleReceivedTargetPower" "$NR_PREAMBLE_RECEIVED_TARGET_POWER"
fi
if [ -n "$NR_MSG3_DELTA_PREAMBLE" ]; then
    update_conf "configs/gnb.conf" "msg3_DeltaPreamble" "$NR_MSG3_DELTA_PREAMBLE"
fi
if [ -n "$NR_PRACH_DTX_THRESHOLD" ]; then
    update_conf "configs/gnb.conf" "prach_dtx_threshold" "$NR_PRACH_DTX_THRESHOLD"
fi
if [ -n "$NR_OFDM_OFFSET_DIVISOR" ]; then
    update_conf "configs/gnb.conf" "ofdm_offset_divisor" "$NR_OFDM_OFFSET_DIVISOR"
fi
if [ -n "$NR_PRACH_ROOT_SEQUENCE_INDEX" ]; then
    update_conf "configs/gnb.conf" "prach_RootSequenceIndex" "$NR_PRACH_ROOT_SEQUENCE_INDEX"
fi
if [ -n "$NR_SSB_BITMAP" ]; then
    update_conf "configs/gnb.conf" "ssb_PositionsInBurst_Bitmap" "$NR_SSB_BITMAP"
fi
if [ -n "$NR_TDD_PERIODICITY" ]; then
    update_conf "configs/gnb.conf" "dl_UL_TransmissionPeriodicity" "$NR_TDD_PERIODICITY"
    update_conf "configs/gnb.conf" "nrofDownlinkSlots" "$NR_TDD_DL_SLOTS"
    update_conf "configs/gnb.conf" "nrofDownlinkSymbols" "$NR_TDD_DL_SYMBOLS"
    update_conf "configs/gnb.conf" "nrofUplinkSlots" "$NR_TDD_UL_SLOTS"
    update_conf "configs/gnb.conf" "nrofUplinkSymbols" "$NR_TDD_UL_SYMBOLS"
fi
if [ "$RADIO_TYPE" = "ZMQ" ] && [ -n "$ZMQ_TX_AMP_BACKOFF_DB" ]; then
    sed -i "/^[[:space:]]*prach_dtx_threshold/a\\  tx_amp_backoff_dB = $ZMQ_TX_AMP_BACKOFF_DB;" "configs/gnb.conf"
fi
cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.sa.f1.conf "$SCRIPT_DIR/configs/split_cu.conf"
for i in "${CELL_NUMBERS[@]}"; do
    cp "$SCRIPT_DIR/configs/gnb.conf" "$SCRIPT_DIR/configs/split_du${i}.conf"
done

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
echo "AMF Binding Address: $N3_ADDR_BIND"
echo "NGAP Binding Address: $N2_ADDR_BIND/24"

SPLIT_DUS=()
for i in "${CELL_NUMBERS[@]}"; do
    SPLIT_DUS+=("split_du${i}.conf")
done

for CONF_FILE in gnb.conf split_cu.conf "${SPLIT_DUS[@]}"; do
    echo "Configuring $CONF_FILE..."
    # Update configuration values for RF front-end device
    update_conf "configs/$CONF_FILE" "amf_ip_address" "({ ipv4 = \"$AMF_ADDR\"; })"
    update_conf "configs/$CONF_FILE" "GNB_IPV4_ADDRESS_FOR_NG_AMF" "\"$N2_ADDR_BIND/24\""
    update_conf "configs/$CONF_FILE" "GNB_IPV4_ADDRESS_FOR_NGU" "\"$N3_ADDR_BIND/24\""
    update_conf "configs/$CONF_FILE" "tracking_area_code" "$TAC"

    ENABLE_E2_NODE=true
    if [[ "$CONF_FILE" == "gnb.conf" ]] && [ "$MAKE_GNB_E2_NODE" = "false" ]; then
        ENABLE_E2_NODE=false
    elif [[ "$CONF_FILE" == "split_cu.conf" ]] && [ "$MAKE_CU_E2_NODE" = "false" ]; then
        ENABLE_E2_NODE=false
    elif [[ "$CONF_FILE" == *"du"* ]] && [ "$MAKE_DU_E2_NODE" = "false" ]; then
        ENABLE_E2_NODE=false
    fi

    if [ "$ENABLE_E2_NODE" = "true" ]; then
        if grep -q "^[[:space:]]*e2_agent[[:space:]]*=[[:space:]]*{" "configs/$CONF_FILE"; then
            update_conf "configs/$CONF_FILE" "near_ric_ip_addr" "\"$NEAR_RIC_IP_ADDR\""
            update_conf "configs/$CONF_FILE" "sm_dir" "\"$FULL_SM_DIR\""
        else
            printf '\ne2_agent = {\n  near_ric_ip_addr = "%s";\n  sm_dir = "%s";\n};\n' "$NEAR_RIC_IP_ADDR" "$FULL_SM_DIR" >>"configs/$CONF_FILE"
        fi
    elif grep -q "^[[:space:]]*e2_agent[[:space:]]*=[[:space:]]*{" "configs/$CONF_FILE"; then
        sed -i '/^[[:space:]]*e2_agent[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/ s/^/#/' "configs/$CONF_FILE"
    fi

    # Configure the Single Network Slice Selection Assistance Information (S-NSSAI)
    update_conf "configs/$CONF_FILE" "plmn_list" "({ mcc = $MCC; mnc = $MNC; mnc_length = $MNC_LENGTH; snssaiList = $SNSSAI_LIST })"

    if [ "$CSI_REPORT_TYPE" = "ssb_rsrp" ] || [ "$CSI_REPORT_TYPE" = "ssb_sinr" ] || [ "$CSI_REPORT_TYPE" = "cri_rsrp" ]; then
        if [ "$CSI_REPORT_TYPE" = "cri_rsrp" ]; then
            update_conf "configs/$CONF_FILE" "do_CSIRS" "1"
        else
            update_conf "configs/$CONF_FILE" "do_CSIRS" "0"
        fi

        # 38.331's reportQuantity and reportQuantity-r16 CHOICE enforces only either ssb-Index-RSRP or ssb-Index-SINR-r16, not both
        if grep -q "^\s*CSI_report_type\s*=" "configs/$CONF_FILE"; then
            sed -i "s|^\(\s*CSI_report_type\s*=\).*|\1 \"$CSI_REPORT_TYPE\"; # ssb_rsrp, ssb_sinr, or cri_rsrp|" "configs/$CONF_FILE"
        else
            sed -i "/do_CSIRS\s*=/a \    CSI_report_type                                           = \"$CSI_REPORT_TYPE\"; # ssb_rsrp, ssb_sinr, or cri_rsrp" "configs/$CONF_FILE"
        fi
    else
        update_conf "configs/$CONF_FILE" "do_CSIRS" "1"
        sed -i '/^\s*CSI_report_type\s*=/d' "configs/$CONF_FILE"
    fi

    if [ "$RADIO_TYPE" = "SIMU" ] || [ "$RADIO_TYPE" = "ZMQ" ]; then
        if ! grep -q "@include \"channelmod_rfsimu.conf\"" "configs/$CONF_FILE"; then
            echo "" >>"configs/$CONF_FILE"
            echo "@include \"channelmod_rfsimu.conf\"" >>"configs/$CONF_FILE"
        fi
        if [ ! -e "configs/channelmod_rfsimu.conf" ]; then
            cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/channelmod_rfsimu.conf configs/channelmod_rfsimu.conf
        fi
    fi

done

echo
echo "Generating configuration for CU..."
# Set the local_n_address in the CU configuration file
sed -i 's|^\([[:space:]]*\)local_n_address\s*=.*|\1local_n_address     = "127.0.0.100";|' "configs/split_cu.conf"
echo "    Configured CU."

for DU_CONF in "${SPLIT_DUS[@]}"; do
    DU_NUMBER=$(echo "$DU_CONF" | grep -oP 'split_du\K[0-9]+')
    ./install_scripts/generate_du_configuration.sh "$DU_NUMBER"

    RADIO_PROFILE_INDEX=$(((DU_NUMBER - 1) % ${#NR_SSB_ARFCNS[@]}))
    update_conf "configs/$DU_CONF" "absoluteFrequencySSB" "${NR_SSB_ARFCNS[$RADIO_PROFILE_INDEX]}"
    update_conf "configs/$DU_CONF" "dl_absoluteFrequencyPointA" "${NR_DL_POINT_A_ARFCNS[$RADIO_PROFILE_INDEX]}"
    if [ -n "$NR_PRACH_ROOT_SEQUENCE_INDEX" ]; then
        update_conf "configs/$DU_CONF" "prach_RootSequenceIndex" "$NR_PRACH_ROOT_SEQUENCE_INDEX"
    fi
    if [ -n "$NR_SSB_BITMAP" ]; then
        update_conf "configs/$DU_CONF" "ssb_PositionsInBurst_Bitmap" "$NR_SSB_BITMAP"
    fi
done

if [ "$ENABLE_NEIGHBOR_CONFIG" = "true" ]; then
    NEIGHBOR_CONFIG_TEMPLATE="../User_Equipment/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/neighbour-config-rfsim.conf"
    if [ ! -f "$NEIGHBOR_CONFIG_TEMPLATE" ]; then
        echo "ERROR: Neighbor configuration template not found: $NEIGHBOR_CONFIG_TEMPLATE"
        exit 1
    fi
    python3 install_scripts/generate_neighbor_configuration.py \
        "$NEIGHBOR_CONFIG_TEMPLATE" \
        "configs/neighbor-config.conf" \
        "${SPLIT_DUS[@]/#/configs/}"
    for RRC_CONF in "configs/gnb.conf" "configs/split_cu.conf"; do
        sed -i '/^[[:space:]]*nr_cellid[[:space:]]*=/a\    @include "neighbor-config.conf" // Configure neighbor cells and periodic UE measurement reports' "$RRC_CONF"
    done
    echo "Configured neighbor DUs and periodic UE measurement reports for gNB/CU."
fi

if [ "$RADIO_TYPE" = "ZMQ" ]; then
    echo "Generating ZeroMQ Broker Python script..."
    BROKER_CELL_NUMBERS_STR=$(
        IFS=,
        echo "${CELL_NUMBERS[*]}"
    )
    BROKER_UE_CONFIGS=()
    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
        UE_IP=$(../User_Equipment/install_scripts/get_ue_namespace_ip.sh ue "$UE_NUMBER")
        BROKER_UE_CONFIGS+=("$UE_NUMBER:$UE_IP")
    done
    BROKER_UE_CONFIGS_STR=$(
        IFS=,
        echo "${BROKER_UE_CONFIGS[*]}"
    )
    ./install_scripts/generate_zmq_broker.sh \
        --output "zmq_broker/multi_ue_scenario.py" \
        --sample-rate-hz "$ZMQ_BROKER_SAMPLE_RATE_HZ" \
        --slow-down-ratio 1 \
        --cells "$BROKER_CELL_NUMBERS_STR" \
        --ues "$BROKER_UE_CONFIGS_STR"
    echo "Successfully generated ZeroMQ broker for UEs: [${UE_NUMBERS[*]}], Cells: [${CELL_NUMBERS[*]}]."
fi

cd configs
# Link the get_rfsim_server_address.txt from the UE configuration to here
if [ -L "get_rfsim_server_address.txt" ]; then
    sudo rm -rf "get_rfsim_server_address.txt"
fi
ln -sf "../../User_Equipment/configs/get_rfsim_server_address.txt" get_rfsim_server_address.txt
cd ..

echo
echo "Successfully configured the gNodeB and split CU/DUs. The configuration files are located in the configs/ directory."

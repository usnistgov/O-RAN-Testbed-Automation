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

SPLIT_DU_IDS=$(seq 1 3)
USE_RFSIM_CHANNELMOD=true

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# There are two types of RSRP measurements: SSB and CSI
# If using MIMO, then USE_SSB_RSRP must be set to false (https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/develop/doc/RUNMODEM.md#5g-gnb-mimo-configuration)
USE_SSB_RSRP="true"

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

SNSSAI_LIST="("
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

FIRST_ENTRY=1
for i in "${!SST[@]}"; do
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
rm -rf configs
mkdir configs

# Only remove the logs if not running
RUNNING_STATUS=$(./is_running.sh)
if [[ $RUNNING_STATUS != *": RUNNING"* ]]; then
    rm -rf logs || sudo rm -rf logs
    mkdir logs
fi

cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.sa.band78.fr1.106PRB.usrpb210.conf "$SCRIPT_DIR/configs/gnb.conf"
cp openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.sa.f1.conf "$SCRIPT_DIR/configs/split_cu.conf"
cp "$SCRIPT_DIR/configs/gnb.conf" "$SCRIPT_DIR/configs/split_du1.conf"
cp "$SCRIPT_DIR/configs/gnb.conf" "$SCRIPT_DIR/configs/split_du2.conf"
cp "$SCRIPT_DIR/configs/gnb.conf" "$SCRIPT_DIR/configs/split_du3.conf"

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
for i in $SPLIT_DU_IDS; do
    SPLIT_DUS+=("split_du${i}.conf")
done

for CONF_FILE in gnb.conf split_cu.conf "${SPLIT_DUS[@]}"; do
    echo "Configuring $CONF_FILE..."
    # Update configuration values for RF front-end device
    update_conf "configs/$CONF_FILE" "amf_ip_address" "({ ipv4 = \"$AMF_ADDR\"; })"
    update_conf "configs/$CONF_FILE" "GNB_IPV4_ADDRESS_FOR_NG_AMF" "\"$N2_ADDR_BIND/24\""
    update_conf "configs/$CONF_FILE" "GNB_IPV4_ADDRESS_FOR_NGU" "\"$N3_ADDR_BIND/24\""
    update_conf "configs/$CONF_FILE" "tracking_area_code" "$TAC"

    # Configure the Single Network Slice Selection Assistance Information (S-NSSAI)
    update_conf "configs/$CONF_FILE" "plmn_list" "({ mcc = $MCC; mnc = $MNC; mnc_length = $MNC_LENGTH; snssaiList = $SNSSAI_LIST })"

    if [ "$USE_SSB_RSRP" = "true" ]; then
        update_conf "configs/$CONF_FILE" "do_CSIRS" "0"
    else
        update_conf "configs/$CONF_FILE" "do_CSIRS" "1"
    fi

    if [ "$USE_RFSIM_CHANNELMOD" = true ]; then
        # Finally, ensure that it is referencing the channelmod_rfsimu.conf file
        if ! grep -q "@include \"channelmod_rfsimu.conf\"" "configs/$CONF_FILE"; then
            echo "" >>"configs/$CONF_FILE"
            echo "@include \"channelmod_rfsimu.conf\"" >>"configs/$CONF_FILE"
        fi
        if [ ! -e "configs/channelmod_rfsimu.conf" ]; then
            cd configs
            #ln -s ../../User_Equipment/configs/channelmod_rfsimu.conf channelmod_rfsimu.conf
            ln -sf ../install_patch_files/channelmod_rfsimu.conf channelmod_rfsimu.conf
            cd ..
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
done

cd configs
# Link the get_rfsim_server_address.txt from the UE configuration to here
if [ -L "get_rfsim_server_address.txt" ]; then
    sudo rm -rf "get_rfsim_server_address.txt"
fi
ln -sf "../../User_Equipment/configs/get_rfsim_server_address.txt" get_rfsim_server_address.txt
cd ..

echo
echo "Successfully configured the gNodeB and split CU/DUs. The configuration files are located in the configs/ directory."

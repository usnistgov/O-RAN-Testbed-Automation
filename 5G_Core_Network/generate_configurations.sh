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

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
fi

echo "Parsing options.yaml..."
# Check if the YAML file exists, if not, set and save default values
if [ ! -f "options.yaml" ]; then
    echo "plmn: 00101" >"options.yaml"
    echo "tac: 7" >>"options.yaml"
fi
# Read PLMN and TAC values from the YAML file using yq
PLMN=$(yq eval '.plmn' options.yaml)
TAC=$(yq eval '.tac' options.yaml)
# Parse Mobile Country Code (MCC) and Mobile Network Code (MNC) from PLMN
PLMN_MCC=${PLMN:0:3}
PLMN_MNC=${PLMN:3}
echo "PLMN value: $PLMN"
echo "MCC (Mobile Country Code): $PLMN_MCC"
echo "MNC (Mobile Network Code): $PLMN_MNC"
echo "TAC value: $TAC"

echo "Creating configs directory..."
rm -rf "$SCRIPT_DIR/configs"
mkdir "$SCRIPT_DIR/configs"
rm -rf "$SCRIPT_DIR/logs"

APPS=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

echo "Fetching 5G Core configuration files..."
for APP in "${APPS[@]}"; do
    if [[ "${APP: -1}" != "d" ]]; then
        APP_NAME="$APP"
    else # Remove the last character
        APP_NAME="${APP%?}"
    fi
    if [ "$APP_NAME" == "webui" ]; then
        continue
    elif [ "$APP_NAME" == "sepp" ]; then
        if [ -f "open5gs/install/etc/open5gs/${APP_NAME}1.yaml" ] && [ -f "open5gs/install/etc/open5gs/${APP_NAME}2.yaml" ]; then
            cp "open5gs/install/etc/open5gs/${APP_NAME}1.yaml" "configs/${APP_NAME}1.yaml"
            cp "open5gs/install/etc/open5gs/${APP_NAME}2.yaml" "configs/${APP_NAME}2.yaml"
        else
            echo "Configuration files not found for $APP."
            echo "Please ensure that the $APP_NAME configuration files are present in the open5gs/install/etc/open5gs directory."
            exit 1
        fi
    else
        if [ -f "open5gs/install/etc/open5gs/${APP_NAME}.yaml" ]; then
            cp "open5gs/install/etc/open5gs/${APP_NAME}.yaml" "configs/${APP_NAME}.yaml"
        else
            echo "Configuration file not found for $APP."
            echo "Please ensure that the $APP_NAME configuration file is present in the open5gs/install/etc/open5gs directory."
            exit 1
        fi
    fi
done

# Construct all app names, not including trailing "d" and distinguishing between SEPP instances
APP_NAMES=()
for APP in "${APPS[@]}"; do
    if [[ $APP == "seppd" ]]; then
        continue
    fi
    APP_NAME="${APP%?}"
    if [[ $APP == *d ]]; then
        APP_NAMES+=("$APP_NAME")
    else
        APP_NAMES+=("$APP")
    fi
done
APP_NAMES+=("sepp1" "sepp2")

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

# Function to configure PLMN and TAC in the MME and AMF configurations
configure_plmn_tac() {
    local PLMN_MCC=$1
    local PLMN_MNC=$2
    local TAC=$3
    local MME_CONFIG="configs/mme.yaml"
    local AMF_CONFIG="configs/amf.yaml"
    local NRF_CONFIG="configs/nrf.yaml"

    # Update MME and AMF configuration files
    sed -i "s/^\(\s*mcc:\s*\).*/\1$PLMN_MCC/" $MME_CONFIG
    sed -i "s/^\(\s*mnc:\s*\).*/\1$PLMN_MNC/" $MME_CONFIG
    sed -i "s/^\(\s*tac:\s*\).*/\1$TAC/" $MME_CONFIG

    sed -i "s/^\(\s*mcc:\s*\).*/\1$PLMN_MCC/" $AMF_CONFIG
    sed -i "s/^\(\s*mnc:\s*\).*/\1$PLMN_MNC/" $AMF_CONFIG
    sed -i "s/^\(\s*tac:\s*\).*/\1$TAC/" $AMF_CONFIG

    sed -i "s/^\(\s*mcc:\s*\).*/\1$PLMN_MCC/" $NRF_CONFIG
    sed -i "s/^\(\s*mnc:\s*\).*/\1$PLMN_MNC/" $NRF_CONFIG
    sed -i "s/^\(\s*tac:\s*\).*/\1$TAC/" $NRF_CONFIG
}

# Function to set the logging path, disable timestamp for stderr to avoid duplicate timestamps in journalctl
configure_logging() {
    local LOG_PATH="$1"
    local CONFIG_PATH="$2"

    # Update the logger default and file timestamp settings
    update_yaml "$CONFIG_PATH" "logger.default" "timestamp" "false"
    update_yaml "$CONFIG_PATH" "logger.file" "timestamp" "true"

    # Replace the logger file path to output to the local logs/ directory
    update_yaml "$CONFIG_PATH" "logger.file" "path" "$SCRIPT_DIR/$LOG_PATH"
}

# Function to get the primary IP for the network segment by resetting the last octet to 1
get_primary_ip_for_network() {
    local IP_ADDRESS=$1
    # Extract the first three octets and append .1 to get the primary IP for the network
    local PRIMARY_IP=$(echo "$IP_ADDRESS" | awk -F '.' '{print $1"."$2"."$3".1"}')
    echo $PRIMARY_IP
}

# Function to get the ngap_server configuration IP
get_configuration_ngap_server_ip() {
    local FILE_PATH="configs/amf.yaml"
    # Use yq to parse the YAML file and extract the IP address
    local IP_ADDRESS=$(yq e '.amf.ngap.server[0].address' "$FILE_PATH")
    if [[ -n $IP_ADDRESS ]]; then
        echo $IP_ADDRESS
    else
        echo "IP address not found."
    fi
}

# Function to set the ngap_server configuration IP
set_configuration_ngap_and_gptu_server_ip() {
    local AMF_FILE_PATH="configs/amf.yaml"
    local UPF_FILE_PATH="configs/upf.yaml"
    local IP_ADDRESS=$1
    # Use yq to parse the YAML file and update the IP address
    yq e -i ".amf.ngap.server[0].address = \"$IP_ADDRESS\"" "$AMF_FILE_PATH"
    yq e -i ".upf.gtpu.server[0].address = \"$IP_ADDRESS\"" "$UPF_FILE_PATH"
}

# To expose the core network to the external network, set EXPOSE_CORE_EXTERNALLY to true
EXPOSE_CORE_EXTERNALLY=false

if [ "$EXPOSE_CORE_EXTERNALLY" = true ]; then
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    set_configuration_ngap_and_gptu_server_ip $IP_ADDRESS
fi

# Get the following AMF IP, and it will be updated in the configuration file
AMF_IP=$(get_configuration_ngap_server_ip)
AMF_IP_BIND=$(get_primary_ip_for_network $AMF_IP)
AMF_ADDRESSES_OUTPUT="configs/get_amf_address.txt"
echo "$AMF_IP" >$AMF_ADDRESSES_OUTPUT
echo "$AMF_IP_BIND" >>$AMF_ADDRESSES_OUTPUT

# Configure logging for all components
for APP_NAME in "${APP_NAMES[@]}"; do
    if [ -f "configs/${APP_NAME}.yaml" ]; then
        configure_logging "logs/${APP_NAME}.txt" "configs/${APP_NAME}.yaml"
    fi
done

# Configure the PLMN and TAC to match regulatory requirements
configure_plmn_tac $PLMN_MCC $PLMN_MNC $TAC

# Add route for the UE to have WAN connectivity
### Enable IPv4/IPv6 Forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
### Add NAT Rule
sudo iptables --wait -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
sudo ip6tables --wait -t nat -A POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE
echo "By default, Ubuntu enables a firewall that blocks the UE from accessing the internet. Disabling the firewall..."
sudo ufw status || true
sudo ./install_scripts/disable_firewall.sh
sudo ufw status || true

mkdir -p "$SCRIPT_DIR/logs"
sudo chown $USER:$USER -R "$SCRIPT_DIR/logs"

echo "Registering UE 1..."
./install_scripts/register_subscriber.sh --imsi 001010123456780 --key 00112233445566778899AABBCCDDEEFF --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn

echo "Registering UE 2..."
./install_scripts/register_subscriber.sh --imsi 001010123456790 --key 00112233445566778899AABBCCDDEF00 --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn

echo "Registering UE 3..."
./install_scripts/register_subscriber.sh --imsi 001010123456791 --key 00112233445566778899AABBCCDDEF01 --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn

# Restart Open5GS services to apply changes
echo "To apply changed, stop and start the following:"
echo "    open5gs-mmed"
echo "    open5gs-sgwud"
echo "    open5gs-amfd"
echo "    open5gs-upfd"

echo "Successfully configured the 5G Core components. The configuration files are located in the configs/ directory."

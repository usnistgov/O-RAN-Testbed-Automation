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
        CONFIG_FILE="$APP"
    else # Remove the last character
        CONFIG_FILE="${APP%?}"
    fi
    if [ "$CONFIG_FILE" == "webui" ]; then
        continue
    elif [ "$CONFIG_FILE" == "sepp" ]; then
        if [ -f "open5gs/install/etc/open5gs/${CONFIG_FILE}1.yaml" ] && [ -f "open5gs/install/etc/open5gs/${CONFIG_FILE}2.yaml" ]; then
            cp "open5gs/install/etc/open5gs/${CONFIG_FILE}1.yaml" "configs/${CONFIG_FILE}1.yaml"
            cp "open5gs/install/etc/open5gs/${CONFIG_FILE}2.yaml" "configs/${CONFIG_FILE}2.yaml"
        else
            echo "Configuration files not found for $APP."
            echo "Please ensure that the $CONFIG_FILE configuration files are present in the open5gs/install/etc/open5gs directory."
            exit 1
        fi
    else
        if [ -f "open5gs/install/etc/open5gs/${CONFIG_FILE}.yaml" ]; then
            cp "open5gs/install/etc/open5gs/${CONFIG_FILE}.yaml" "configs/${CONFIG_FILE}.yaml"
        else
            echo "Configuration file not found for $APP."
            echo "Please ensure that the $CONFIG_FILE configuration file is present in the open5gs/install/etc/open5gs directory."
            exit 1
        fi
    fi
done

# Function to update YAML configuration files
update_yaml() {
    local IP=$1
    local FILE_PATH=$2
    local PROPERTY=$3
    echo "Updating $FILE_PATH for $PROPERTY to $IP"

    sed -i "s/\($PROPERTY: \).*/\1$IP/" $FILE_PATH
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
    local FILE_PATH="$1"
    echo "Configuring logging in \"$FILE_PATH\""

    sed -i "/logger:/a \ \ default:\n    timestamp: false" "$FILE_PATH"
    sed -i "/file:/a \ \ \ \ timestamp: true" "$FILE_PATH"

    # Replace the logger file path to output to the logs/ directory
    sed -i "s|path: $SCRIPT_DIR/open5gs/install/var/log/open5gs/|path: $SCRIPT_DIR/logs/|g" "$FILE_PATH"

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

# Function to configure NGAP server addresses in the AMF config and store them in a file for gNodeB
configure_ngap_server() {
    local NGAP_IP=$1
    local NGAP_PORT=$2
    local FILE_PATH="configs/amf.yaml"

    echo "Configuring NGAP server addresses in $FILE_PATH"
    # Use awk to process multi-line patterns, replacing address and adding port
    awk -v ip="$NGAP_IP" -v port="$NGAP_PORT" '
    /ngap:/ { print; in_ngap = 1; next } # Enter NGAP block
    in_ngap && /server:/ { print; in_server = 1; next } # Enter server block within NGAP
    in_server && /- address:/ { # Find the address line within server block
        print "      - address: " ip;
        print "        port: " port; # Insert port on new line
        next;
    }
    /metrics:/ { in_ngap = 0; in_server = 0 } # Exit NGAP block upon reaching metrics
    { print } # Print all other lines as they are
    ' $FILE_PATH >tmp.yaml && mv tmp.yaml $FILE_PATH
}

# Set the following AMF IP, and it will be updated in the configuration file
AMF_IP=$(get_configuration_ngap_server_ip)
AMF_IP_BIND=$(get_primary_ip_for_network $AMF_IP)
AMF_ADDRESSES_OUTPUT="configs/get_amf_address.txt"
echo "$AMF_IP" >$AMF_ADDRESSES_OUTPUT
echo "$AMF_IP_BIND" >>$AMF_ADDRESSES_OUTPUT

# Define Open5GS config paths and properties
declare -A CONFIG_PATHS
CONFIG_PATHS=()
CONFIG_PATHS["configs/mme.yaml"]="s1ap.server.address gtpc.server.address"
CONFIG_PATHS["configs/sgwu.yaml"]="gtpu.server.address"
CONFIG_PATHS["configs/amf.yaml"]="ngap.server.address"
CONFIG_PATHS["configs/upf.yaml"]="gtpu.server.address"

for FILE in "${!CONFIG_PATHS[@]}"; do
    for PROPERTY in ${CONFIG_PATHS[$FILE]}; do
        update_yaml $AMF_IP $FILE $PROPERTY
    done
done

# Configure logging for all components
for APP in "${APPS[@]}"; do
    if [[ "${APP: -1}" != "d" ]]; then
        CONFIG_FILE="$APP"
    else # Remove the last character
        CONFIG_FILE="${APP%?}"
    fi
    if [ -f "configs/${CONFIG_FILE}.yaml" ]; then
        configure_logging "configs/${CONFIG_FILE}.yaml"
    fi
done

# Configure the PLMN and TAC to match regulatory requirements
configure_plmn_tac $PLMN_MCC $PLMN_MNC $TAC

# If necessary, configure AMF specific address in amf.yaml
if [ "$AMF_IP" != "$(get_configuration_ngap_server_ip)" ]; then
    configure_ngap_server $AMF_IP "38412"
fi

# Add route for the UE to have WAN connectivity
### Enable IPv4/IPv6 Forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
### Add NAT Rule
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
sudo ip6tables -t nat -A POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE
echo "By default, Ubuntu enables a firewall that blocks the UE from accessing the internet. Disabling the firewall..."
sudo ufw status
sudo ufw disable
sudo ufw status

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

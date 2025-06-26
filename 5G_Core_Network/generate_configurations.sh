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

DNN="nist-dnn"

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
fi

echo "Parsing options.yaml..."
# Check if the YAML file exists, if not, set and save default values
if [ ! -f "options.yaml" ]; then
    echo "# Upon modification, apply changes with ./generate_configurations.sh." >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# If false, AMF will use the default 127.0.0.5, otherwise, it will use the hostname IP" >>"options.yaml"
    echo "expose_amf_over_hostname: false" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Include the Security Edge Protection Proxies (SEPP1 and SEPP2)" >>"options.yaml"
    echo "include_sepp: false" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Configure the MCC/MNC and TAC" >>"options.yaml"
    echo "plmn: 00101" >>"options.yaml"
    echo "tac: 7" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Configure the ogstun gateway address for UE traffic" >>"options.yaml"
    echo "ogstun_ipv4: 10.45.0.0/16" >>"options.yaml"
    echo "ogstun_ipv6: 2001:db8:cafe::/48" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "ogstun2_ipv4: 10.46.0.0/16" >>"options.yaml"
    echo "ogstun2_ipv6: 2001:db8:babe::/48" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "ogstun3_ipv4: 10.47.0.0/16" >>"options.yaml"
    echo "ogstun3_ipv6: 2001:db8:face::/48" >>"options.yaml"
fi

# If expose_amf_over_hostname is false, AMF will use the default 127.0.0.5, otherwise, it will use the hostname IP
EXPOSE_AMF_OVER_HOSTNAME=$(yq eval '.expose_amf_over_hostname' options.yaml)
if [[ "$EXPOSE_AMF_OVER_HOSTNAME" == "null" || -z "$EXPOSE_AMF_OVER_HOSTNAME" ]]; then
    echo "Missing parameter in options.yaml: expose_amf_over_hostname"
    exit 1
elif [[ "$EXPOSE_AMF_OVER_HOSTNAME" != "true" && "$EXPOSE_AMF_OVER_HOSTNAME" != "false" ]]; then
    echo "Invalid value for expose_amf_over_hostname in options.yaml. Expected 'true' or 'false'."
    exit 1
fi

# Set IS_OPEN5GS_ON_HOST if Open5GS will run on the host machine, otherwise, set it to false
if [ "$EXPOSE_AMF_OVER_HOSTNAME" = true ]; then
    IS_OPEN5GS_ON_HOST=true
fi

# Read PLMN and TAC values from the YAML file using yq
PLMN=$(yq eval '.plmn' options.yaml)
TAC=$(yq eval '.tac' options.yaml)

# Parse Mobile Country Code (MCC) and Mobile Network Code (MNC) from PLMN
MCC="${PLMN:0:3}"
if [ ${#PLMN} -eq 5 ]; then
    MNC="${PLMN:3:2}"
elif [ ${#PLMN} -eq 6 ]; then
    MNC="${PLMN:3:3}"
fi
MNC_LENGTH=${#MNC}
echo "PLMN value: $PLMN"
echo "MCC (Mobile Country Code): $MCC"
echo "MNC (Mobile Network Code): $MNC"
echo "TAC value: $TAC"

echo "Creating configs directory..."
rm -rf configs
mkdir configs

# Only remove the logs if no component is running
RUNNING_STATUS=$(./is_running.sh)
if [[ $RUNNING_STATUS != *": RUNNING"* ]]; then
    rm -rf logs
    mkdir logs
fi

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
    local MCC=$1
    local MNC=$2
    local TAC=$3
    local AMF_CONFIG="configs/amf.yaml"
    local NRF_CONFIG="configs/nrf.yaml"
    local MME_CONFIG="configs/mme.yaml" # LTE

    # Update AMF, NRF, and MME configuration files
    sed -i "s/^\(\s*mcc:\s*\).*/\1$MCC/" $AMF_CONFIG
    sed -i "s/^\(\s*mnc:\s*\).*/\1$MNC/" $AMF_CONFIG
    sed -i "s/^\(\s*tac:\s*\).*/\1$TAC/" $AMF_CONFIG

    sed -i "s/^\(\s*mcc:\s*\).*/\1$MCC/" $NRF_CONFIG
    sed -i "s/^\(\s*mnc:\s*\).*/\1$MNC/" $NRF_CONFIG
    sed -i "s/^\(\s*tac:\s*\).*/\1$TAC/" $NRF_CONFIG

    sed -i "s/^\(\s*mcc:\s*\).*/\1$MCC/" $MME_CONFIG
    sed -i "s/^\(\s*mnc:\s*\).*/\1$MNC/" $MME_CONFIG
    sed -i "s/^\(\s*tac:\s*\).*/\1$TAC/" $MME_CONFIG
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

# In standalone mode, use AMF instead of MME
STANDALONE_MODE="true"

# Function to set the ngap_server configuration IP
set_configuration_server_ips() {
    local IP_ADDRESS=$1
    # Use yq to parse the YAML file and update the IP address
    if [ "$STANDALONE_MODE" = true ]; then
        # From (https://open5gs.org/open5gs/docs/guide/01-quickstart/#setup-a-5g-core):
        local AMF_FILE_PATH="configs/amf.yaml"
        local UPF_FILE_PATH="configs/upf.yaml"
        yq e -i ".amf.ngap.server[0].address = \"$IP_ADDRESS\"" "$AMF_FILE_PATH"
        yq e -i ".upf.gtpu.server[0].address = \"$IP_ADDRESS\"" "$UPF_FILE_PATH"
    else
        # From (https://open5gs.org/open5gs/docs/guide/01-quickstart/#setup-a-4g-5g-nsa-core):
        local MME_FILE_PATH="configs/mme.yaml" # LTE
        local SGWU_FILE_PATH="configs/sgwu.yaml"
        yq e -i ".mme.s1ap.server[0].address = \"$IP_ADDRESS\"" "$MME_FILE_PATH"
        yq e -i ".sgwu.gtpu.server[0].address = \"$IP_ADDRESS\"" "$SGWU_FILE_PATH"
    fi
}

set_configuration_session_gateways() {
    local SUBNET_IPV4=$1
    local GATEWAY_IPV4=$2
    local SUBNET_IPV6=$3
    local GATEWAY_IPV6=$4

    local SMF_FILE_PATH="configs/smf.yaml"
    local UPF_FILE_PATH="configs/upf.yaml"

    yq e -i ".upf.session[0].subnet = \"$SUBNET_IPV4\"" "$UPF_FILE_PATH"
    yq e -i ".upf.session[0].gateway = \"$GATEWAY_IPV4\"" "$UPF_FILE_PATH"
    yq e -i ".upf.session[1].subnet = \"$SUBNET_IPV6\"" "$UPF_FILE_PATH"
    yq e -i ".upf.session[1].gateway = \"$GATEWAY_IPV6\"" "$UPF_FILE_PATH"

    yq e -i ".smf.session[0].subnet = \"$SUBNET_IPV4\"" "$SMF_FILE_PATH"
    yq e -i ".smf.session[0].gateway = \"$GATEWAY_IPV4\"" "$SMF_FILE_PATH"
    yq e -i ".smf.session[1].subnet = \"$SUBNET_IPV6\"" "$SMF_FILE_PATH"
    yq e -i ".smf.session[1].gateway = \"$GATEWAY_IPV6\"" "$SMF_FILE_PATH"
}

OGSTUN_IPV4=$(yq eval '.ogstun_ipv4' options.yaml)
OGSTUN_IPV6=$(yq eval '.ogstun_ipv6' options.yaml)
if [[ "$OGSTUN_IPV4" == "null" || -z "$OGSTUN_IPV4" ]]; then
    echo "Missing parameter in options.yaml: ogstun_ipv4"
    exit 1
fi
if [[ "$OGSTUN_IPV6" == "null" || -z "$OGSTUN_IPV6" ]]; then
    echo "Missing parameter in options.yaml: ogstun_ipv6"
    exit 1
fi

# Extract the first IPv4 address from a CIDR block by replacing the last octet with '.1'
# For example, 10.45.0.0/16 --> 10.45.0.1/16
grab_first_ipv4_address() {
    local IP=$1
    echo ${IP%.*}.1/${IP#*/}
}

# Extract the first IPv6 address from a CIDR block by replacing the suffix with '::1'.
# For example, 2001:db8:cafe::/48 --> 2001:db8:cafe::1/48
grab_first_ipv6_address() {
    local IP=$1
    echo ${IP%::*}::1/${IP#*/}
}

# Remove the CIDR suffix from an IP address
# For example, 10.45.0.1/16 --> 10.45.0.1
remove_cidr_suffix() {
    local IP=$1
    echo ${IP%/*}
}

# Extract the first IPv4 and IPv6 addresses from the CIDR blocks
OGSTUN_IPV4_1=$(grab_first_ipv4_address "$OGSTUN_IPV4")
OGSTUN_IPV6_1=$(grab_first_ipv6_address "$OGSTUN_IPV6")
OGSTUN_IPV4_1_NO_CIDR=$(remove_cidr_suffix "$OGSTUN_IPV4_1")
OGSTUN_IPV6_1_NO_CIDR=$(remove_cidr_suffix "$OGSTUN_IPV6_1")

if [ "$EXPOSE_AMF_OVER_HOSTNAME" = true ]; then
    AMF_IP=$(hostname -I | awk '{print $1}')
    set_configuration_server_ips $AMF_IP
    # Need an address for the gNodeB to bind to that is not the host IP.
    if [ "$IS_OPEN5GS_ON_HOST" = true ]; then
        AMF_IP_BIND=$OGSTUN_IPV4_1_NO_CIDR
    else
        AMF_IP_BIND=$AMF_IP
    fi
else
    AMF_IP="127.0.0.5"
    AMF_IP_BIND="127.0.0.1"
fi

set_configuration_session_gateways $OGSTUN_IPV4 $OGSTUN_IPV4_1_NO_CIDR $OGSTUN_IPV6 $OGSTUN_IPV6_1_NO_CIDR

# Get the following AMF IP, and it will be updated in the configuration file
AMF_ADDRESSES_OUTPUT="configs/get_amf_address.txt"
echo "$AMF_IP" >$AMF_ADDRESSES_OUTPUT
echo "$AMF_IP_BIND" >>$AMF_ADDRESSES_OUTPUT

# Configure logging for all components
for APP_NAME in "${APP_NAMES[@]}"; do
    if [ -f "configs/${APP_NAME}.yaml" ]; then
        configure_logging "logs/${APP_NAME}.log" "configs/${APP_NAME}.yaml"
    fi
done

# Configure the PLMN and TAC to match regulatory requirements
configure_plmn_tac $MCC $MNC $TAC

sudo ./install_scripts/network_config.sh

# Enable IPv4/IPv6 Forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

echo "By default, Ubuntu enables a firewall that blocks the UE from accessing the internet. Disabling the firewall..."
sudo ufw status || true
sudo ./install_scripts/disable_firewall.sh
sudo ufw status || true

echo "Unregistering all subscribers in Open5GS database..."
./install_scripts/unregister_all_subscribers.sh

PLMN_LENGTH=${#PLMN}

echo
echo "Registering UE 1..."
IMSI="001010123456780"
IMSI="${PLMN}${IMSI:$PLMN_LENGTH}" # Ensure that the beginning of the IMSI is the correct PLMN
./install_scripts/register_subscriber.sh --imsi $IMSI --key 00112233445566778899AABBCCDDEEFF --opc 63BFA50EE6523365FF14C1F45F88737D --apn "$DNN"

echo
echo "Registering UE 2..."
IMSI="001010123456790"
IMSI="${PLMN}${IMSI:$PLMN_LENGTH}" # Ensure that the beginning of the IMSI is the correct PLMN
./install_scripts/register_subscriber.sh --imsi $IMSI --key 00112233445566778899AABBCCDDEF00 --opc 63BFA50EE6523365FF14C1F45F88737D --apn "$DNN"

echo
echo "Registering UE 3..."
IMSI="001010123456791"
IMSI="${PLMN}${IMSI:$PLMN_LENGTH}" # Ensure that the beginning of the IMSI is the correct PLMN
./install_scripts/register_subscriber.sh --imsi $IMSI --key 00112233445566778899AABBCCDDEF01 --opc 63BFA50EE6523365FF14C1F45F88737D --apn "$DNN"

# Restart Open5GS services to apply changes
echo "To apply changed, stop and start the following:"
echo "    open5gs-mmed"
echo "    open5gs-sgwud"
echo "    open5gs-amfd"
echo "    open5gs-upfd"

echo "Successfully configured the 5G Core components. The configuration files are located in the configs/ directory."

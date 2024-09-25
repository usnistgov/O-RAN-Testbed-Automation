#!/bin/bash

set -e

if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    YQ_PATH="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    sudo wget $YQ_PATH -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
    # Uninstall with: sudo rm -rf /usr/bin/yq
fi

echo "Parsing options.yaml..."
# Check if the YAML file exists, if not, set and save default values
if [ ! -f "options.yaml" ]; then
    echo "plmn: 00101" > "options.yaml"
    echo "tac: 7" >> "options.yaml"
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
mkdir -p configs

if [ ! -f configs/nrf_original.yaml ]; then
    echo "Backing up 5G Core configuration files..."
    cp open5gs/install/etc/open5gs/nrf.yaml configs/nrf_original.yaml
    cp open5gs/install/etc/open5gs/amf.yaml configs/amf_original.yaml
    cp open5gs/install/etc/open5gs/upf.yaml configs/upf_original.yaml
    cp open5gs/install/etc/open5gs/mme.yaml configs/mme_original.yaml
    cp open5gs/install/etc/open5gs/sgwu.yaml configs/sgwu_original.yaml
fi

cp configs/nrf_original.yaml configs/nrf.yaml
cp configs/amf_original.yaml configs/amf.yaml
cp configs/upf_original.yaml configs/upf.yaml
cp configs/mme_original.yaml configs/mme.yaml
cp configs/sgwu_original.yaml configs/sgwu.yaml


# Function to extract the first interface with a global scope that is UP
get_active_interface() {
    local interface=$(ip -4 addr show scope global up | awk '$1 == "inet" {print $NF}' | head -n 1)
    if [[ -z "$interface" ]]; then
        echo "No active network interface found. Please check your network configuration."
        exit 1
    fi
    echo $interface
}

# Function to get the subnet mask for a given network interface
get_subnet_mask() {
    local interface=$1
    local subnet_mask=$(ip -4 addr show $interface | grep -oP 'inet \d+(\.\d+){3}/\K\d+' | head -n 1)
    if [[ -z "$subnet_mask" ]]; then
        echo "Could not retrieve subnet mask for interface $interface."
        exit 1
    fi
    echo $subnet_mask
}

# Function to get the primary IP address or ask the user for manual input
get_primary_ip() {
    local ip=$(ip -4 addr show scope global up | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    echo $ip
}

# Function to derive a secondary IP from the primary IP
derive_secondary_ip() {
    local primary_ip=$1
    local base_ip=$(echo $primary_ip | awk -F '.' '{print $1"."$2"."$3"."}')
    local last_octet=$(echo $primary_ip | awk -F '.' '{print $4}')
    local secondary_ip_octet=$(($last_octet + 1))

    # Check if the new last octet is within a valid range
    if ((secondary_ip_octet > 254)); then
        echo "Derived IP is out of valid range, reverting to default or prompting for manual input."
        read -p "Enter a valid secondary IP: " secondary_ip
    else
        secondary_ip=${base_ip}${secondary_ip_octet}  # Increment last octet
    fi
    echo $secondary_ip
}

# Function to update YAML configuration files
update_yaml() {
    local ip=$1
    local file_path=$2
    local property=$3
    echo "Updating $file_path for $property to $ip"
    
    sed -i "s/\($property: \).*/\1$ip/" $file_path
}

# Function to configure PLMN and TAC in the MME and AMF configurations
configure_plmn_tac() {
    local plmn_mcc=$1
    local plmn_mnc=$2
    local tac=$3
    local mme_config="configs/mme.yaml"
    local amf_config="configs/amf.yaml"

    # Update MME and AMF configuration files
    sed -i "s/^\(\s*mcc:\s*\).*/\1$plmn_mcc/" $mme_config
    sed -i "s/^\(\s*mnc:\s*\).*/\1$plmn_mnc/" $mme_config
    sed -i "s/^\(\s*tac:\s*\).*/\1$tac/" $mme_config

    sed -i "s/^\(\s*mcc:\s*\).*/\1$plmn_mcc/" $amf_config
    sed -i "s/^\(\s*mnc:\s*\).*/\1$plmn_mnc/" $amf_config
    sed -i "s/^\(\s*tac:\s*\).*/\1$tac/" $amf_config
}

# Function to configure NGAP server addresses in the AMF config and store them in a file for gNodeB
configure_ngap_server() {
    local ngap_ip=$1
    local ngap_port=$2
    local file_path="configs/amf.yaml"
    
    echo "Configuring NGAP server addresses in $file_path"
    # Displaying the part of the file to be updated for debugging
    # echo "Current NGAP server configuration:"
    # grep "ngap:" -A 5 $file_path

    # Use awk to process multi-line patterns, replacing address and adding port
    awk -v ip="$ngap_ip" -v port="$ngap_port" '
    /ngap:/ { print; in_ngap = 1; next }  # Enter NGAP block
    in_ngap && /server:/ { print; in_server = 1; next }  # Enter server block within NGAP
    in_server && /- address:/ {  # Find the address line within server block
        print "      - address: " ip;
        print "        port: " port;  # Insert port on new line
        next;
    }
    /metrics:/ { in_ngap = 0; in_server = 0 }  # Exit NGAP block upon reaching metrics
    { print }  # Print all other lines as they are
    ' $file_path > tmp.yaml && mv tmp.yaml $file_path

    # Confirmation of update
    # echo "Updated NGAP server configuration:"
    # grep "ngap:" -A 10 $file_path
}

# Function to disable timestamp for stderr to avoid duplicate timestamps in journalctl
configure_logging() {
    local file_path=$1
    echo "Configuring logging in $file_path"
    
    sed -i "/logger:/a \ \ default:\n    timestamp: false" $file_path
    sed -i "/file:/a \ \ \ \ timestamp: true" $file_path
}

# Main logic
interface=$(get_active_interface)
subnet_mask=$(get_subnet_mask $interface)
primary_ip=$(get_primary_ip)
secondary_ip=$(derive_secondary_ip $primary_ip)

# Assign the secondary IP address
if ! ip addr show $interface | grep -q "$secondary_ip/$subnet_mask"; then
    sudo ip addr add $secondary_ip/$subnet_mask dev $interface
fi

amf_addresses_output="configs/get_amf_addresses.txt"
echo "$primary_ip" > $amf_addresses_output
echo "$secondary_ip" >> $amf_addresses_output

# Define Open5GS config paths and properties
declare -A config_paths
config_paths["configs/mme.yaml"]="s1ap.server.address gtpc.server.address"
config_paths["configs/sgwu.yaml"]="gtpu.server.address"
config_paths["configs/amf.yaml"]="ngap.server.address"
config_paths["configs/upf.yaml"]="gtpu.server.address"

for file in "${!config_paths[@]}"; do
    for property in ${config_paths[$file]}; do
        update_yaml $primary_ip $file $property
    done
    configure_logging $file
done

# Configure the PLMN and TAC to match regulatory requirements
configure_plmn_tac $PLMN_MCC $PLMN_MNC $TAC

# Configure AMF specific addresses
configure_ngap_server $primary_ip "38412"


echo "Applying configuration files..."
cp configs/nrf.yaml open5gs/install/etc/open5gs/nrf.yaml
cp configs/amf.yaml open5gs/install/etc/open5gs/amf.yaml
cp configs/upf.yaml open5gs/install/etc/open5gs/upf.yaml
cp configs/mme.yaml open5gs/install/etc/open5gs/mme.yaml
cp configs/sgwu.yaml open5gs/install/etc/open5gs/sgwu.yaml


# Add route for the UE to have WAN connectivity
### Enable IPv4/IPv6 Forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
### Add NAT Rule
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
sudo ip6tables -t nat -A POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE
sudo ufw status
sudo ufw disable
sudo ufw status

# Restart Open5GS services to apply changes
echo "To apply changed, stop and start the following:"
echo "    open5gs-mmed"
echo "    open5gs-sgwud"
echo "    open5gs-amfd"
echo "    open5gs-upfd"

echo "Successfully configured the 5G Core components. The configuration files are located in the configs/ directory."

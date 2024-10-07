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

apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

# Backup original files
if [ ! -f configs/amf_original.yaml ]; then
    echo "Backing up 5G Core configuration files..."
    for app in "${apps[@]}"; do
        config_file="${app%?}"
        if [[ "${app: -1}" != "d" ]]; then
            config_file="$app"
        fi
        if [ -f "open5gs/install/etc/open5gs/${config_file}.yaml" ]; then
            cp "open5gs/install/etc/open5gs/${config_file}.yaml" "configs/${config_file}_original.yaml"
        elif [ -f "open5gs/install/etc/open5gs/${config_file}1.yaml" ]; then
            cp "open5gs/install/etc/open5gs/${config_file}1.yaml" "configs/${config_file}_original.yaml"
        fi
    done
fi

# Restore original files
for app in "${apps[@]}"; do
    config_file="${app%?}"
    if [[ "${app: -1}" != "d" ]]; then
        config_file="$app"
    fi
    if [ -f "configs/${config_file}_original.yaml" ]; then
        cp "configs/${config_file}_original.yaml" "configs/${config_file}.yaml"
    fi
done

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

# Function to set the logging path, disable timestamp for stderr to avoid duplicate timestamps in journalctl
configure_logging() {
    local file_path=$1
    echo "Configuring logging in $file_path"
    
    sed -i "/logger:/a \ \ default:\n    timestamp: false" $file_path
    sed -i "/file:/a \ \ \ \ timestamp: true" $file_path

    # Replace the logger file path to output to the logs/ directory
    sed -i "s|path: $(pwd)/open5gs/install/var/log/open5gs/|path: $(pwd)/logs/|g" $file_path
}

# Function to get the primary IP for the network segment by resetting the last octet to 1
get_primary_ip_for_network() {
    local ip_address=$1
    # Extract the first three octets and append .1 to get the primary IP for the network
    local primary_ip=$(echo "$ip_address" | awk -F '.' '{print $1"."$2"."$3".1"}')
    echo $primary_ip
}

# Function to get the ngap_server configuration IP
get_configuration_ngap_server_ip() {
    local file_path="configs/amf.yaml"
    # Use yq to parse the YAML file and extract the IP address
    local ip_address=$(yq e '.amf.ngap.server[0].address' "$file_path")
    if [[ -n $ip_address ]]; then
        echo $ip_address
    else
        echo "IP address not found."
    fi
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
    /ngap:/ { print; in_ngap = 1; next } # Enter NGAP block
    in_ngap && /server:/ { print; in_server = 1; next } # Enter server block within NGAP
    in_server && /- address:/ { # Find the address line within server block
        print "      - address: " ip;
        print "        port: " port; # Insert port on new line
        next;
    }
    /metrics:/ { in_ngap = 0; in_server = 0 } # Exit NGAP block upon reaching metrics
    { print } # Print all other lines as they are
    ' $file_path > tmp.yaml && mv tmp.yaml $file_path

    # Confirmation of update
    # echo "Updated NGAP server configuration:"
    # grep "ngap:" -A 10 $file_path
}

# Main logic
# interface=$(get_active_interface)
# subnet_mask=$(get_subnet_mask $interface)
# amf_ip=$(get_primary_ip)
# secondary_ip=$(derive_secondary_ip $amf_ip)

# echo $subnet_mask
# echo $amf_ip
# echo $secondary_ip

# # Assign the secondary IP address
# if ! ip addr show $interface | grep -q "$secondary_ip/$subnet_mask"; then
#     sudo ip addr add $secondary_ip/$subnet_mask dev $interface
# fi

# Set the following AMF IP, and it will be updated in the configuration file
amf_ip=$(get_configuration_ngap_server_ip)
amf_ip_bind=$(get_primary_ip_for_network $amf_ip)


amf_addresses_output="configs/get_amf_address.txt"
echo "$amf_ip" > $amf_addresses_output
echo "$amf_ip_bind" >> $amf_addresses_output

# Define Open5GS config paths and properties
declare -A config_paths
config_paths["configs/mme.yaml"]="s1ap.server.address gtpc.server.address"
config_paths["configs/sgwu.yaml"]="gtpu.server.address"
config_paths["configs/amf.yaml"]="ngap.server.address"
config_paths["configs/upf.yaml"]="gtpu.server.address"

mkdir -p logs

for file in "${!config_paths[@]}"; do 
    for property in ${config_paths[$file]}; do
        update_yaml $amf_ip $file $property
    done
    configure_logging $file
done

# Configure the PLMN and TAC to match regulatory requirements
configure_plmn_tac $PLMN_MCC $PLMN_MNC $TAC

# If necessary, configure AMF specific address in amf.yaml
if [ "$amf_ip" != "$(get_configuration_ngap_server_ip)" ]; then
    configure_ngap_server $amf_ip "38412"
fi



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

mkdir -p logs
sudo chown $USER:$USER -R logs

./install_scripts/register_subscriber.sh --imsi 001010123456780 --key 00112233445566778899aabbccddeeff --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn

# Restart Open5GS services to apply changes
echo "To apply changed, stop and start the following:"
echo "    open5gs-mmed"
echo "    open5gs-sgwud"
echo "    open5gs-amfd"
echo "    open5gs-upfd"

echo "Successfully configured the 5G Core components. The configuration files are located in the configs/ directory."

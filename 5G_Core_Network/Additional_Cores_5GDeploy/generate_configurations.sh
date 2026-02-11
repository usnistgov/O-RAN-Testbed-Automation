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

AMF_IP=192.168.62.11 # N2 interface
N2_IP_BIND=192.168.62.1
N3_IP_BIND=$(ip route get 1 | awk '{print $(NF-2); exit}') # Get the IP of the primary network interface
UPF1_IP=192.168.63.21
UPF4_IP=192.168.63.24
SUBNET_INTERNAL="172.25.160.0/20" # Sets the subnet for internal core network

UE_NUMBERS=($(seq 1 100)) # Subscribers from UE 1 to UE 100

# Exit immediately if a command fails
set -e

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$SCRIPT_DIR"

if [ ! -d "5gdeploy" ]; then
    echo "ERROR: Cannot find 5gdeploy directory. Please run the full_install.sh script first."
    exit 1
fi
if [ ! -d "5gdeploy/scenario" ]; then
    echo "ERROR: Cannot find 5gdeploy/scenario directory. Please run the full_install.sh script first."
    exit 1
fi

# Check if docker is accessible from the current user, and if not, repair its permissions
if [ -z "$FIXED_DOCKER_PERMS" ]; then
    if ! OUTPUT=$(docker info 2>&1); then
        if echo "$OUTPUT" | grep -qiE 'permission denied|cannot connect to the docker daemon'; then
            echo "Docker permissions will repair on reboot."
            sudo groupadd -f docker
            if [ -n "$SUDO_USER" ]; then
                sudo usermod -aG docker "${SUDO_USER:-root}"
            else
                sudo usermod -aG docker "${USER:-root}"
            fi
            # Rather than requiring a reboot to apply docker permissions, set the docker group and re-run the parent script
            export FIXED_DOCKER_PERMS=1
            if ! command -v sg &>/dev/null; then
                echo
                echo "WARNING: Could not find set group (sg) command, docker may fail without sudo until the system reboots."
                echo
            else
                exec sg docker -c "$(printf '%q ' "$CURRENT_DIR/$0" "$@")"
            fi
        fi
    fi
fi

cd "$PARENT_DIR"

# Ensure the correct YAML editor is installed
"$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

echo "Parsing options.yaml..."
# Check if the YAML file exists, if not, set and save default values
if [ ! -f "options.yaml" ]; then
    echo "# Upon modification, apply changes with ./generate_configurations.sh." >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Choose which core to use by default. Options for core_to_use are:" >>"options.yaml"
    echo "# - open5gs: Open5GS core in current directory (default, see https://github.com/open5gs/open5gs)" >>"options.yaml"
    echo "# - 5gdeploy-oai: OpenAirInterface core in Additional_Cores_5GDeploy directory see https://gitlab.eurecom.fr/oai/cn5g)" >>"options.yaml"
    echo "# - 5gdeploy-free5gc: Free5GC core in Additional_Cores_5GDeploy directory (see https://github.com/free5gc/free5gc)" >>"options.yaml"
    echo "# - 5gdeploy-open5gs: Open5GS core in Additional_Cores_5GDeploy directory (see https://github.com/open5gs/open5gs)" >>"options.yaml"
    echo "# - 5gdeploy-phoenix: Phoenix core in Additional_Cores_5GDeploy directory (requires license to operate, see: https://www.open5gcore.org)" >>"options.yaml"
    echo "core_to_use: open5gs" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Optionally, if using 5gdeploy, you may specify a different User Plane Function (UPF) to use. " >>"options.yaml"
    echo "# Please see https://github.com/usnistgov/5gdeploy/blob/main/docs/interop.md#cp-up for details about which combinations are supported." >>"options.yaml"
    echo "# Options for upf_to_use are:" >>"options.yaml"
    echo "# - null: Use the same value as core_to_use" >>"options.yaml"
    echo "# - 5gdeploy-eupf: eUPF (see https://github.com/edgecomllc/eupf)" >>"options.yaml"
    echo "# - 5gdeploy-oai: OAI UPF (see https://gitlab.eurecom.fr/oai/cn5g)" >>"options.yaml"
    echo "# - 5gdeploy-oai-vpp: OAI UPF based on VPP (see https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp)" >>"options.yaml"
    echo "# - 5gdeploy-free5gc: Free5GC UPF (see https://github.com/free5gc/free5gc)" >>"options.yaml"
    echo "# - 5gdeploy-open5gs: Open5GS UPF (see https://github.com/open5gs/open5gs)" >>"options.yaml"
    echo "# - 5gdeploy-bess: Aether SD-Core's BESS UPF (see https://github.com/omec-project/bess)" >>"options.yaml"
    echo "# - 5gdeploy-ndndpdk: Use NIST NDN-DPDK (see https://doi.org/10.1145/3405656.3418715)" >>"options.yaml"
    echo "# - 5gdeploy-phoenix: Phoenix UPF (see https://doi.org/10.1007/s00502-022-01064-7 and https://www.open5gcore.org)" >>"options.yaml"
    echo "upf_to_use: null" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Configure the MCC/MNC and TAC" >>"options.yaml"
    echo "plmn: 00101" >>"options.yaml"
    echo "tac: 7" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Configure the DNN/APN" >>"options.yaml"
    echo "dnn: nist-dnn" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Configure the Single Network Slice Selection Assistance Information (S-NSSAI)" >>"options.yaml"
    echo "sst: 1" >>"options.yaml"
    echo "sd: 000001" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# If core_to_use=open5gs, false means AMF will use the default 127.0.0.5, true means it will use the hostname IP" >>"options.yaml"
    echo "expose_amf_over_hostname: false" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# If core_to_use=open5gs, toggle whether or not to include the Security Edge Protection Proxies (SEPP1 and SEPP2)" >>"options.yaml"
    echo "include_sepp: false" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# If core_to_use=open5gs, configure the ogstun gateway address for UE traffic" >>"options.yaml"
    echo "ogstun_ipv4: 10.45.0.0/16" >>"options.yaml"
    echo "ogstun_ipv6: 2001:db8:cafe::/48" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "ogstun2_ipv4: 10.46.0.0/16" >>"options.yaml"
    echo "ogstun2_ipv6: 2001:db8:babe::/48" >>"options.yaml"
    echo "" >>"options.yaml"
    echo "ogstun3_ipv4: 10.47.0.0/16" >>"options.yaml"
    echo "ogstun3_ipv6: 2001:db8:face::/48" >>"options.yaml"
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

# Ensure that the correct script is used
if [ -f "options.yaml" ]; then
    CORE_TO_USE=$(yq eval '.core_to_use' options.yaml)
    UPF_TO_USE=$(yq eval '.upf_to_use' options.yaml)
fi
if [[ "$CORE_TO_USE" == "null" || -z "$CORE_TO_USE" ]]; then
    echo "No core specified in options.yaml, please ensure that \"core_to_use\" is set."
    exit 1
fi
if [[ "$UPF_TO_USE" == "null" || -z "$UPF_TO_USE" ]]; then
    UPF_TO_USE="$CORE_TO_USE" # Default to the same core if not specified
fi
if [ "$CORE_TO_USE" == "open5gs" ]; then
    echo "ERROR: The core Open5GS is in the parent directory. Please run the script from the parent directory."
    exit 1
fi

# Configure the DNN, SST, and SD values
DNN=$(sed -n 's/^dnn: //p' options.yaml)
SST=$(yq eval '.slices[0].sst' options.yaml)
SD=$(yq eval '.slices[0].sd' options.yaml)
if [[ -z "$DNN" || "$DNN" == "null" ]]; then
    echo "DNN is not set in options.yaml, please ensure that \"dnn\" is set."
    exit 1
fi
if [[ -z "$SST" || -z "$SD" || "$SST" == "null" || "$SD" == "null" ]]; then
    echo "SST or SD is not set in options.yaml, please ensure that \"slices[].sst\" and \"slices[].sd\" are set."
    exit 1
fi

cd "$SCRIPT_DIR"

UE_CREDENTIAL_GENERATOR_SCRIPT="$(dirname "$PARENT_DIR")/User_Equipment/ue_credentials_generator.sh"
if [ ! -f "$UE_CREDENTIAL_GENERATOR_SCRIPT" ]; then
    echo "ERROR: Cannot find $UE_CREDENTIAL_GENERATOR_SCRIPT to generate UE subscriber credentials."
    exit 1
fi

echo "Unregistering all subscribers in 5gdeploy database..."
./install_scripts/unregister_all_subscribers.sh

# Register the subscribers
for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    echo "Registering UE $UE_NUMBER..."
    # Fetch the UE's OPc, IMEI, IMSI, KEY, and NAMESPACE
    read -r UE_OPC UE_IMEI UE_IMSI UE_KEY UE_NAMESPACE < <("$UE_CREDENTIAL_GENERATOR_SCRIPT" "$UE_NUMBER" "$PLMN")
    ./install_scripts/register_subscriber.sh --imsi "$UE_IMSI" --key "$UE_KEY" --opc "$UE_OPC" --apn "$DNN"
done

# Ensure that the core is set correctly
if [ "$CORE_TO_USE" == "5gdeploy-oai" ]; then
    CORE="oai"
elif [ "$CORE_TO_USE" == "5gdeploy-free5gc" ]; then
    CORE="free5gc"
elif [ "$CORE_TO_USE" == "5gdeploy-phoenix" ]; then
    CORE="phoenix"
elif [ "$CORE_TO_USE" == "5gdeploy-open5gs" ]; then
    CORE="open5gs"
else
    # Remove the prefix if it exists
    CORE="${CORE_TO_USE#5gdeploy-}"
    echo
    echo "WARNING: Unknown core: \"$CORE\", 5gdeploy may not support this core."
    echo "Do you want to proceed? (Y/n)"
    read -r CONFIRM
    CONFIRM=$(echo "${CONFIRM:-y}" | tr '[:upper:]' '[:lower:]')
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "yes" ]]; then
        echo "Exiting."
        exit 1
    fi
fi

# Ensure that the UPF is set correctly
if [ "$UPF_TO_USE" == "5gdeploy-eupf" ]; then
    UPF="eupf"
elif [ "$UPF_TO_USE" == "5gdeploy-oai" ]; then
    UPF="oai"
elif [ "$UPF_TO_USE" == "5gdeploy-oai-vpp" ]; then
    UPF="oai-vpp"
elif [ "$UPF_TO_USE" == "5gdeploy-free5gc" ]; then
    UPF="free5gc"
elif [ "$UPF_TO_USE" == "5gdeploy-phoenix" ]; then
    UPF="phoenix"
elif [ "$UPF_TO_USE" == "5gdeploy-open5gs" ]; then
    UPF="open5gs"
elif [ "$UPF_TO_USE" == "5gdeploy-bess" ]; then
    UPF="bess"
elif [ "$UPF_TO_USE" == "5gdeploy-ndndpdk" ]; then
    UPF="ndndpdk"
else
    # Remove the prefix if it exists
    UPF="${UPF_TO_USE#5gdeploy-}"
    echo
    echo "WARNING: Unknown UPF: \"$UPF\", 5gdeploy may not support this UPF."
    echo "Do you want to proceed? (Y/n)"
    read -r CONFIRM
    CONFIRM=$(echo "${CONFIRM:-y}" | tr '[:upper:]' '[:lower:]')
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "yes" ]]; then
        echo "Exiting."
        exit 1
    fi
fi

cd "$SCRIPT_DIR"

# Clean up the compose directory scenario if it exists
if [ -d "compose/orantestbed" ]; then
    sudo rm -rf "compose/orantestbed"
fi
if [ -d "compose" ] && [ -z "$(ls -A compose)" ]; then
    sudo rmdir "compose"
fi

cd "$SCRIPT_DIR"

# Ensure that 5gdeploy is installed before proceeding
if ! command -v docker &>/dev/null; then
    echo "5gdeploy is not installed, please run the full_install.sh script first."
    exit 1
fi
# Check for the last image installed by 5gdeploy
if ! docker image inspect 5gdeploy.localhost/srsran5g &>/dev/null; then
    echo "5gdeploy is not installed, please run the full_install.sh script first."
    exit 1
fi

# Network configuration
sudo sysctl net.ipv4.conf.all.forwarding=1

# Ensure FORWARD policy is ACCEPT
if ! sudo iptables -L FORWARD | grep -q "Chain FORWARD (policy ACCEPT)"; then
    echo "Setting iptables FORWARD policy to ACCEPT..."
    sudo iptables -P FORWARD ACCEPT
fi

# Give the core components internet access
if ! sudo iptables -t nat -C POSTROUTING -s "$SUBNET_INTERNAL" ! -d "$SUBNET_INTERNAL" -j MASQUERADE 2>/dev/null; then
    sudo iptables -t nat -A POSTROUTING -s "$SUBNET_INTERNAL" ! -d "$SUBNET_INTERNAL" -j MASQUERADE
fi
# Remove with sudo iptables -t nat -D POSTROUTING -s "$SUBNET_INTERNAL" ! -d "$SUBNET_INTERNAL" -j MASQUERADE

# Enable SCTP kernel module
sudo ./install_scripts/enable_sctp.sh

# Update the configuration file so that the gNodeB can find the AMF
mkdir -p "$SCRIPT_DIR/configs"
AMF_ADDRESSES_OUTPUT="configs/get_amf_address.txt"
echo "$AMF_IP" >$AMF_ADDRESSES_OUTPUT
echo "$N3_IP_BIND" >>$AMF_ADDRESSES_OUTPUT
echo "$N2_IP_BIND" >>$AMF_ADDRESSES_OUTPUT

### Start of pre-generation patching ###
cd "$SCRIPT_DIR/5gdeploy/scenario"

if [ -d "orantestbed" ]; then
    echo "Removing existing orantestbed directory..."
    sudo rm -rf "orantestbed"
fi
cp -r 20230817 orantestbed

SST_PADDED=$(printf "%02x" "$SST") # For example, 1 -> 01

echo "Revising scenario files..."
sed -i "s/01000000/$SST_PADDED$SD/g" orantestbed/scenario.ts
sed -i "s/20230817/orantestbed/g" orantestbed/sonic-dl.ts
sed -i "s/20230817/orantestbed/g" orantestbed/sonic-ul.ts

TAC_PADDED=$(printf "%06x" "$TAC") # For example, 7 -> 000007
# Edit the common scenario template
sed -i "s/plmn: \"[^\"]*\"/plmn: \"$MCC-$MNC\"/g" common/phones-vehicles.ts
sed -i "s/tac: \"[^\"]*\"/tac: \"$TAC_PADDED\"/g" common/phones-vehicles.ts

cd "$SCRIPT_DIR/5gdeploy"

# Set the subnet in compose/ipalloc.ts
if [ -f "compose/ipalloc.ts" ]; then
    echo "Setting core subnet in compose/ipalloc.ts..."
    sed -E -i 's|(dfltSpace[[:space:]]*=[[:space:]]*")[^"]*(")|\1'"$SUBNET_INTERNAL"'\2|' compose/ipalloc.ts
fi

# Set the subnet in virt/main.ts
if [ -f "virt/main.ts" ]; then
    echo "Setting core subnet in virt/main.ts..."
    sed -E -i 's|(ipAllocOptions[[:space:]]*\(")[^"]*("\))|\1'"$SUBNET_INTERNAL"'\2|' virt/main.ts
fi

### End of pre-generation patching ###

cd "$SCRIPT_DIR/5gdeploy/scenario"

echo "Using CP: $CORE"
echo "Using UP: $UPF"

# For a multi-host deployment, see the 5gdeploy documentation: https://github.com/usnistgov/5gdeploy/blob/main/docs/multi-host.md
./generate.sh orantestbed \
    +gnbs=1 +phones=0 +vehicles=0 \
    --cp=$CORE --up=$UPF --ran=none \
    --ip-fixed=amf,n2,$AMF_IP \
    --ip-fixed=upf1,n3,$UPF1_IP \
    --ip-fixed=upf4,n3,$UPF4_IP
# --bridge="n2 | vx | $IP_ADDRESS,$AMF_IP" \
# --bridge="n3 | vx | $IP_ADDRESS,$UPF1_IP" \

cd "$SCRIPT_DIR/configs"

# Create symbolic links to the configuration files
ln -sf ../5gdeploy/sims.tsv sims.tsv
ln -sf ../compose/orantestbed/netdef.json netdef.json
ln -sf ../compose/orantestbed/cp-cfg/config.yaml cp-cfg-config.yaml
ln -sf ../compose/orantestbed/up-cfg/upf1.yaml up-cfg-upf1.yaml
ln -sf ../compose/orantestbed/up-cfg/upf1.yaml up-cfg-upf1.yaml
ln -sf ../compose/orantestbed/up-cfg/upf140.yaml up-cfg-upf140.yaml
ln -sf ../compose/orantestbed/up-cfg/upf141.yaml up-cfg-upf141.yaml

### Start of post-generation patching ###

cd "$SCRIPT_DIR/compose/orantestbed"

# Save the core and UPF used to a text file for reference
echo "$CORE_TO_USE" >core_upf_used.txt
echo "$UPF_TO_USE" >>core_upf_used.txt

# Revise configuration file netdef.json
if [ -f "netdef.json" ]; then
    echo "Setting subscribers field in netdef.json..."
    sed -i "s/\"internet\"/\"$DNN\"/g" netdef.json
    sed -i "s/'internet'/'$DNN'/g" netdef.json
fi

# Revise configuration files in the cp-cfg directory
for CPFILE in cp-cfg/*; do
    if [ -f "$CPFILE" ]; then
        sed -i "s/\"internet\"/\"$DNN\"/g" "$CPFILE"
        sed -i "s/'internet'/'$DNN'/g" "$CPFILE"
    fi
done

# Revise configuration files up-cfg/upf1.yaml, up-cfg/upf140.yaml, and up-cfg/upf141.yaml
for FILE in up-cfg/upf1.yaml up-cfg/upf140.yaml up-cfg/upf141.yaml; do
    if [ -f "$FILE" ]; then
        # Patch all "sd" fields to the correct SD value, but only for top-level or first element arrays
        SD="$SD" yq '
            with(select(has("sd")); .sd = env(SD)) |
            (
                (.. | select(kind == "seq" and length > 0) | .[0]
                    | select(kind == "map" and has("sd")) | .sd
                ) |= env(SD)
            )
        ' "$FILE" >tmp.yaml && mv tmp.yaml "$FILE"

        sed -i "s/\"internet\"/\"$DNN\"/g" "$FILE"
        sed -i "s/'internet'/'$DNN'/g" "$FILE"
    fi
done

# Revise compose.yml
if [ -f "compose.yml" ]; then
    # Replace "dnn":["internet"] with dnn:["$DNN"]
    sed -i -E 's/"dnn"[[:space:]]*:[[:space:]]*\[[[:space:]]*"internet"[[:space:]]*\]/"dnn":["'"$DNN"'"]/g' compose.yml
    # Replace "dnn":"internet" with "dnn":"$DNN"
    sed -i -E 's/"dnn"[[:space:]]*:[[:space:]]*"internet"/"dnn":"'"$DNN"'"/g' compose.yml
    # Replace ${SST_PADDED}${SD}_internet with ${SST_PADDED}${SD}_${DNN}
    sed -i -E "s/${SST_PADDED}${SD}_internet/${SST_PADDED}${SD}_${DNN}/g" compose.yml
    # Replace ${SST_PADDED}${SD}:internet with ${SST_PADDED}${SD}:${DNN}
    sed -i -E "s/${SST_PADDED}${SD}:internet/${SST_PADDED}${SD}:${DNN}/g" compose.yml
fi

# Revise cp-sql/oai_db.sql
if [ -f "cp-sql/oai_db.sql" ]; then
    # Ensure that the database is dropped before creating it
    sed -i '1i DROP DATABASE IF EXISTS oai_db;' cp-sql/oai_db.sql
fi

# Revise cp-sql/smf.sql
if [ -f "cp-sql/smf.sql" ]; then
    # Replace "'internet'" with "'$DNN'"
    sed -i "s/'internet'/'$DNN'/g" cp-sql/smf.sql
fi

# Revise cp-sql/udm.sql
if [ -f "cp-sql/udm.sql" ]; then
    # Replace "'internet'" with "'$DNN'"
    sed -i "s/'internet'/'$DNN'/g" cp-sql/udm.sql
fi

if [ -f "cp-db/open5gs.sh" ]; then
    # Replace " internet " with " $DNN "
    sed -i "s/ internet / $DNN /g" cp-db/open5gs.sh
fi

### End of post-generation patching ###

echo "Successfully configured the 5G Core Deployment Helper (5gdeploy). The configuration files are located in the configs/ directory."

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
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$SCRIPT_DIR"

if [ ! -d "5gdeploy" ]; then
    echo "Error: Cannot find 5gdeploy directory. Please run the full_install.sh script first."
    exit 1
fi
if [ ! -d "5gdeploy/scenario" ]; then
    echo "Error: Cannot find 5gdeploy/scenario directory. Please run the full_install.sh script first."
    exit 1
fi

cd "$PARENT_DIR"

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
fi

echo "Parsing options.yaml..."
# Check if the YAML file exists, if not, set and save default values
if [ ! -f "options.yaml" ]; then
    echo "# Upon modification, apply changes with ./generate_configurations.sh." >>"options.yaml"
    echo "" >>"options.yaml"
    echo "# Choose which core to use by default. Options for core_to_use are:" >>"options.yaml"
    echo "# - open5gs: Open5GS core in current directory (default, see https://github.com/open5gs/open5gs)" >>"options.yaml"
    echo "# - 5gdeploy-oai: OpenAirInterface core in Additional_Cores_5GDeploy directory see https://gitlab.eurecom.fr/oai/cn5g)" >>"options.yaml"
    echo "# - 5gdeploy-free5gc: Free5GC core in Additional_Cores_5GDeploy directory (see https://github.com/free5gc/free5gc)" >>"options.yaml"
    echo "# - 5gdeploy-pheonix: Phoenix core in Additional_Cores_5GDeploy directory (requires license to operate, see: https://www.open5gcore.org)" >>"options.yaml"
    echo "# - 5gdeploy-open5gs: Open5GS core in Additional_Cores_5GDeploy directory (see https://github.com/open5gs/open5gs)" >>"options.yaml"
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
    echo "# - 5gdeploy-pheonix: Phoenix UPF (see https://www.open5gcore.org)" >>"options.yaml"
    echo "# - 5gdeploy-open5gs: Open5GS UPF (see https://github.com/open5gs/open5gs)" >>"options.yaml"
    echo "# - 5gdeploy-bess: Aether SD-Core's BESS UPF (see https://github.com/omec-project/bess)" >>"options.yaml"
    echo "# - 5gdeploy-ndndpdk: Use NIST NDN-DPDK (see https://doi.org/10.1145/3405656.3418715)" >>"options.yaml"
    echo "upf_to_use: null" >>"options.yaml"
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

# # If expose_amf_over_hostname is false, AMF will use the default 127.0.0.5, otherwise, it will use the hostname IP
# EXPOSE_AMF_OVER_HOSTNAME=$(yq eval '.expose_amf_over_hostname' options.yaml)
# if [[ "$EXPOSE_AMF_OVER_HOSTNAME" == "null" || -z "$EXPOSE_AMF_OVER_HOSTNAME" ]]; then
#     echo "Missing parameter in options.yaml: expose_amf_over_hostname"
#     exit 1
# elif [[ "$EXPOSE_AMF_OVER_HOSTNAME" != "true" && "$EXPOSE_AMF_OVER_HOSTNAME" != "false" ]]; then
#     echo "Invalid value for expose_amf_over_hostname in options.yaml. Expected 'true' or 'false'."
#     exit 1
# fi

# # Set IS_OPEN5GS_ON_HOST if Open5GS will run on the host machine, otherwise, set it to false
# if [ "$EXPOSE_AMF_OVER_HOSTNAME" = true ]; then
#     IS_OPEN5GS_ON_HOST=true
# fi

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

cd "$SCRIPT_DIR"

# echo "Creating configs directory..."
# rm -rf configs
# mkdir configs

# echo "Unregistering all subscribers in Open5GS database..."
# ./install_scripts/unregister_all_subscribers.sh

PLMN_LENGTH=${#PLMN}

echo
echo "Registering UE 1..."
IMSI="001010123456780"
IMSI="${PLMN}${IMSI:$PLMN_LENGTH}" # Ensure that the beginning of the IMSI is the correct PLMN
./install_scripts/register_subscriber.sh --imsi $IMSI --key 00112233445566778899AABBCCDDEEFF --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn

echo
echo "Registering UE 2..."
IMSI="001010123456790"
IMSI="${PLMN}${IMSI:$PLMN_LENGTH}" # Ensure that the beginning of the IMSI is the correct PLMN
./install_scripts/register_subscriber.sh --imsi $IMSI --key 00112233445566778899AABBCCDDEF00 --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn

echo
echo "Registering UE 3..."
IMSI="001010123456791"
IMSI="${PLMN}${IMSI:$PLMN_LENGTH}" # Ensure that the beginning of the IMSI is the correct PLMN
./install_scripts/register_subscriber.sh --imsi $IMSI --key 00112233445566778899AABBCCDDEF01 --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn

# Ensure that the core is set correctly
if [ "$CORE_TO_USE" == "5gdeploy-oai" ]; then
    CORE="oai"
elif [ "$CORE_TO_USE" == "5gdeploy-free5gc" ]; then
    CORE="free5gc"
elif [ "$CORE_TO_USE" == "5gdeploy-pheonix" ]; then
    CORE="pheonix"
elif [ "$CORE_TO_USE" == "5gdeploy-open5gs" ]; then
    CORE="open5gs"
else
    # Remove the prefix if it exists
    CORE="${CORE_TO_USE#5gdeploy-}"
    echo "Unknown core: $CORE"
    echo
    read -p "Warning: 5gdeploy may not support this core. Do you want to proceed? (y/n): " yn
    case $yn in
    [Yy]*) ;;
    *)
        echo "Exiting."
        exit 1
        ;;
    esac
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
elif [ "$UPF_TO_USE" == "5gdeploy-pheonix" ]; then
    UPF="pheonix"
elif [ "$UPF_TO_USE" == "5gdeploy-open5gs" ]; then
    UPF="open5gs"
elif [ "$UPF_TO_USE" == "5gdeploy-bess" ]; then
    UPF="bess"
elif [ "$UPF_TO_USE" == "5gdeploy-ndndpdk" ]; then
    UPF="ndndpdk"
else
    # Remove the prefix if it exists
    UPF="${UPF_TO_USE#5gdeploy-}"
    echo "Unknown UPF: $UPF"
    echo
    read -p "Warning: 5gdeploy may not support this UPF. Do you want to proceed? (y/n): " yn
    case $yn in
    [Yy]*) ;;
    *)
        echo "Exiting."
        exit 1
        ;;
    esac
fi

# Network configuration
sudo sysctl net.ipv4.conf.all.forwarding=1
sudo iptables -P FORWARD ACCEPT

cd "$SCRIPT_DIR"

# Clean up the compose directory scenario if it exists
if [ -d "compose/20230817" ]; then
    sudo rm -rf "compose/20230817"
fi
if [ -d "compose" ] && [ -z "$(ls -A compose)" ]; then
    sudo rmdir "compose"
fi

cd "$SCRIPT_DIR/5gdeploy/scenario"

echo "Using CP: $CORE"
echo "Using UP: $UPF"

./generate.sh 20230817 \
    +gnbs=1 +phones=0 +vehicles=0 \
    --cp=$CORE --up=$UPF --ran=none \
    --ip-fixed=amf,n2,192.168.62.11 \
    --ip-fixed=upf1,n3,192.168.63.21 \
    --ip-fixed=upf4,n3,192.168.63.24

# ./generate.sh 20230817 \
#     +gnbs=1 +phones=1 +vehicles=0 \
#     --cp=$CORE --up=$UPF --ran=none \
#     --bridge='n2 | eth | amf*@AC:1F:6B:F5:4C:C6 gnb*@AC:1F:6B:F5:4C:C6' \
#     --bridge='n3 | eth | upf*@AC:1F:6B:F5:4C:C6 gnb*@AC:1F:6B:F5:4C:C6' \
#     --ip-fixed=amf,n2,192.168.62.11 \
#     --ip-fixed=upf1,n3,192.168.63.21 \
#     --ip-fixed=upf4,n3,192.168.63.24

cd "$SCRIPT_DIR/configs"
ln -sf ../5gdeploy/sims.tsv sims.tsv
ln -sf ../compose/20230817/netdef.json netdef.json
ln -sf ../compose/20230817/cp-cfg/config.yaml cp-cfg-config.yaml

cd "$SCRIPT_DIR/compose/20230817"

echo "Previous TAC value was $(jq -r '.tac' netdef.json) (netdef.json)"
jq '.tac = "000007"' netdef.json >tmp.json && mv tmp.json netdef.json
echo "The TAC was changed to $(jq -r '.tac' netdef.json) (netdef.json)"

echo "Previous TAC value was $(yq '.amf.plmn_support_list[0].tac' cp-cfg/config.yaml) (cp-cfg/config.yaml)"
yq -i '.amf.plmn_support_list[0].tac = "0x0007"' cp-cfg/config.yaml
echo "The TAC was changed to $(yq '.amf.plmn_support_list[0].tac' cp-cfg/config.yaml) (cp-cfg/config.yaml)"

echo "Successfully configured the 5G Core Deployment Helper (5gdeploy). The configuration files are located in the configs/ directory."

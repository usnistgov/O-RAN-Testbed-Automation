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

# Ensure the correct YAML editor is installed
sudo "$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

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
    echo "" >>"options.yaml"
    echo "# If core_to_use=open5gs, the use of systemctl can be disabled to support installations within Docker. Before changing this value, it is recommended to uninstall the testbed." >>"options.yaml"
    echo "use_systemctl: true" >>"options.yaml"
fi

# Ensure that the correct script is used
if [ -f "options.yaml" ]; then
    CORE_TO_USE=$(yq eval '.core_to_use' options.yaml)
fi
if [[ "$CORE_TO_USE" == "null" || -z "$CORE_TO_USE" ]]; then
    CORE_TO_USE="open5gs" # Default
fi
if [ "$CORE_TO_USE" != "open5gs" ]; then
    echo "Switching to core: $CORE_TO_USE"
    cd Additional_Cores_5GDeploy || {
        echo "Directory 'Additional_Cores_5GDeploy' not found. Please ensure that it exists in the script's directory."
        exit 1
    }
    ./full_install.sh
    exit $?
fi

USE_SYSTEMCTL=$(yq eval '.use_systemctl' options.yaml)
if [[ "$USE_SYSTEMCTL" == "null" || -z "$USE_SYSTEMCTL" ]]; then
    USE_SYSTEMCTL="true" # Default
fi

# Check for open5gs-amfd and open5gs-upfd binaries to determine if Open5GS is already installed
if [ -f "open5gs/install/bin/open5gs-amfd" ] && [ -f "open5gs/install/bin/open5gs-upfd" ] && command -v mongod &>/dev/null; then
    echo "Open5GS is already installed, skipping."
    exit 0
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

sudo rm -rf logs/

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if [[ "$USE_SYSTEMCTL" == "true" ]]; then
    if systemctl is-active --quiet unattended-upgrades; then
        sudo systemctl stop unattended-upgrades &>/dev/null && echo "Successfully stopped unattended-upgrades service."
        sudo systemctl disable unattended-upgrades &>/dev/null && echo "Successfully disabled unattended-upgrades service."
    fi
    if systemctl is-active --quiet apt-daily.timer; then
        sudo systemctl stop apt-daily.timer &>/dev/null && echo "Successfully stopped apt-daily.timer service."
        sudo systemctl disable apt-daily.timer &>/dev/null && echo "Successfully disabled apt-daily.timer service."
    fi
    if systemctl is-active --quiet apt-daily-upgrade.timer; then
        sudo systemctl stop apt-daily-upgrade.timer &>/dev/null && echo "Successfully stopped apt-daily-upgrade.timer service."
        sudo systemctl disable apt-daily-upgrade.timer &>/dev/null && echo "Successfully disabled apt-daily-upgrade.timer service."
    fi
fi

if [ ! -d "open5gs" ]; then
    echo "Cloning Open5GS..."
    ./install_scripts/git_clone.sh https://github.com/open5gs/open5gs.git
fi

cd $SCRIPT_DIR/open5gs

echo
echo
echo "Installing Open5GS..."
# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

sudo "$SCRIPT_DIR/./install_scripts/install_mongodb.sh"
sudo "$SCRIPT_DIR/./install_scripts/start_mongodb.sh"

# Check and create the open5gs user and group if they don't exist
if ! getent passwd open5gs >/dev/null; then
    sudo useradd -r -M -s /bin/false open5gs
    echo "User 'open5gs' created."
fi
if ! getent group open5gs >/dev/null; then
    sudo groupadd open5gs
    echo "Group 'open5gs' created."
fi
sudo usermod -a -G open5gs open5gs

echo "Installing dependencies for building Open5GS..."

# Code from (https://open5gs.org/open5gs/docs/guide/02-building-open5gs-from-sources#building-open5gs):
sudo env $APTVARS apt-get install -y python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libmongoc-dev libbson-dev libyaml-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson
if apt-cache show libidn-dev >/dev/null 2>&1; then
    sudo env $APTVARS apt-get install -y --no-install-recommends libidn-dev
else
    sudo env $APTVARS apt-get install -y --no-install-recommends libidn11-dev
fi

rm -rf build

# Check if Open5GS has already been built and installed
if [ ! -d "build" ]; then
    echo "Compiling Open5GS with Meson..."
    meson build --prefix="$(pwd)/install" # -Dc_args="-fPIC" -Dc_link_args=""
else
    echo "Open5GS build directory already exists."
fi

echo "Building Open5GS..."
ninja -C build

cd build
# echo "Running test programs..."
# meson test -v
echo "Installing Open5GS..."
ninja install

echo "Installation complete. Open5GS has been installed."

cd "$SCRIPT_DIR"

echo "Installing WebUI for Subscriber Registration..."
sudo ./install_scripts/install_webui.sh

# Define library paths
LIB_SBI_PATH="${SCRIPT_DIR}/open5gs/build/lib/sbi"
LIB_PROTO_PATH="${SCRIPT_DIR}/open5gs/build/lib/proto"
LIB_CORE_PATH="${SCRIPT_DIR}/open5gs/install/lib/x86_64-linux-gnu"

# Create a new script in /etc/profile.d/ to update LD_LIBRARY_PATH for all users
create_ld_script() {
    local LIB_DIR=$1
    local LD_SCRIPT_DIR="/etc/profile.d/open5gs_ld_library_path.sh"

    # Check if script exists and create if not
    if [[ ! -f "$LD_SCRIPT_DIR" ]]; then
        sudo sh -c "echo '#!/bin/bash' > \"$LD_SCRIPT_DIR\""
        sudo sh -c "echo 'export LD_LIBRARY_PATH=' >> \"$LD_SCRIPT_DIR\""
        sudo chmod +x "$LD_SCRIPT_DIR"
    fi

    # Check if path is already added to avoid duplicates
    if ! sudo grep -q "$LIB_DIR" "$LD_SCRIPT_DIR"; then
        sudo sed -i "/^export LD_LIBRARY_PATH=/ s|$|:\"$LIB_DIR\"|" "$LD_SCRIPT_DIR"
    fi
}

# Update LD_LIBRARY_PATH with all necessary library paths
create_ld_script "$LIB_SBI_PATH"
create_ld_script "$LIB_PROTO_PATH"
create_ld_script "$LIB_CORE_PATH"

# Also update LD_LIBRARY_PATH for the current shell session
export LD_LIBRARY_PATH="${LIB_SBI_PATH}:${LIB_PROTO_PATH}:${LIB_CORE_PATH}:${LD_LIBRARY_PATH}"

# Inform the user about changes
echo "Updated LD_LIBRARY_PATH = $LD_LIBRARY_PATH"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
    DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
    echo "The Open5GS installation process took $DURATION_MINUTES minutes to complete."
    mkdir -p logs
    echo "$DURATION_MINUTES minutes" >>install_time.txt
fi

echo "The Open5GS installation completed successfully."

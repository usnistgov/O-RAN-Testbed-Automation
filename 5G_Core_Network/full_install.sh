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

# Check for open5gs-amfd and open5gs-upfd binaries to determine if Open5GS is already installed
if [ -f "open5gs/install/bin/open5gs-amfd" ] && [ -f "open5gs/install/bin/open5gs-upfd" ]; then
    echo "Open5GS is already installed, skipping."
    exit 0
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

sudo rm -rf logs/

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
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

echo "Cloning Open5GS..."
if [ ! -d "open5gs" ]; then
    ./install_scripts/git_clone.sh https://github.com/open5gs/open5gs.git
fi
cd $SCRIPT_DIR/open5gs

echo "Starting installation of Open5GS..."
export DEBIAN_FRONTEND=noninteractive
# Modifies the needrestart configuration to suppress interactive prompts
if [ -f "/etc/needrestart/needrestart.conf" ]; then
    if ! grep -q "^\$nrconf{restart} = 'a';$" "/etc/needrestart/needrestart.conf"; then
        sudo sed -i "/\$nrconf{restart} = /c\$nrconf{restart} = 'a';" "/etc/needrestart/needrestart.conf"
        echo "Modified needrestart configuration to auto-restart services."
    fi
fi
export NEEDRESTART_SUSPEND=1

sudo "$SCRIPT_DIR/./install_scripts/install_mongodb.sh"

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

# Step 3: Setting up TUN device
echo "Checking if TUN device ogstun exists..."
if ! ip link show ogstun >/dev/null 2>&1; then
    echo "Creating TUN device..."
    sudo ip tuntap add name ogstun mode tun
else
    echo "TUN device ogstun already exists."
fi

echo "Checking and assigning IP addresses to TUN device..."
if ! ip addr show ogstun | grep -q "10.45.0.1/16"; then
    sudo ip addr add 10.45.0.1/16 dev ogstun
else
    echo "IP address 10.45.0.1/16 already assigned to ogstun."
fi

if ! ip addr show ogstun | grep -q "2001:db8:cafe::1/48"; then
    sudo ip addr add 2001:db8:cafe::1/48 dev ogstun
else
    echo "IPv6 address 2001:db8:cafe::1/48 already assigned to ogstun."
fi

echo "Setting TUN device up..."
sudo ip link set ogstun up

# Step 4: Building Open5GS
echo "Installing dependencies for building Open5GS..."

# Code from (https://open5gs.org/open5gs/docs/guide/02-building-open5gs-from-sources#building-open5gs):
sudo apt-get install -y python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson
if apt-cache show libidn-dev >/dev/null 2>&1; then
    sudo apt-get install -y --no-install-recommends libidn-dev
else
    sudo apt-get install -y --no-install-recommends libidn11-dev
fi

rm -rf build

# Check if Open5GS has already been built and installed
if [ ! -d "build" ]; then
    echo "Compiling Open5GS with Meson..."
    meson build --prefix="$(pwd)/install"
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

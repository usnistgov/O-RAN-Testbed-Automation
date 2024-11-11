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

UBUNTU_CODENAME=$(./install_scripts/get_ubuntu_codename.sh)

echo "Cloning Open5GS..."
if [ ! -d "open5gs" ]; then
    git clone https://github.com/open5gs/open5gs.git open5gs
fi
cd $SCRIPT_DIR/open5gs

echo "Starting installation of Open5GS..."

INSTALLED_VERSION=$(mongod --version 2>/dev/null | grep -oP "(?<=v)\d+\.\d+\.\d+") || true
if [[ $INSTALLED_VERSION == 4.4.* ]]; then
    echo "MongoDB version 4.4.x is already installed, skipping."
else
    # Get the latest Ubuntu version supported by MongoDB 4.4
    case "$UBUNTU_CODENAME" in
    "focal" | "bionic" | "xenial")
        UBUNTU_CODENAME_MONGODB="$UBUNTU_CODENAME"
        ;;
    *)
        UBUNTU_CODENAME_MONGODB="focal" # Default to the last supported version if the current one is too new
        ;;
    esac

    # Check if libssl1.1 is installed
    if ! dpkg -s libssl1.1 >/dev/null 2>&1; then
        echo "libssl1.1 not found. Installing..."
        # Create a temporary directory and navigate to it
        TEMP_DIR=$(mktemp -d -t libssl-XXXXXXXX)
        pushd "$TEMP_DIR"

        wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
        sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb

        # Return to the original directory and remove the temporary directory
        popd
        rm -rf "$TEMP_DIR"
    else
        echo "libssl1.1 is already installed."
    fi

    # Step 1: Uninstall any conflicting MongoDB version
    echo "Checking for existing MongoDB installations..."
    if dpkg -l | grep -qE "(mongodb-org|mongodb-server|mongodb-server-core)"; then
        echo "Removing conflicting MongoDB packages..."

        # Remove all installed MongoDB-related packages safely
        sudo apt-get purge -y mongodb-org mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools \
            mongodb-server mongodb-server-core mongodb-clients || {
            echo "Failed to remove conflicting MongoDB packages"
            exit 1
        }

        # Clean up MongoDB directories (data and logs)
        sudo rm -rf /var/lib/mongodb
        sudo rm -rf /var/log/mongodb
    else
        echo "No conflicting MongoDB installations found."
    fi

    # Step 2: Installing MongoDB 4.4
    echo "Updating package lists..."
    if ! sudo apt-get update; then
        sudo "$SCRIPT_DIR/install_scripts/./remove_any_expired_apt_keys.sh"
        echo "Trying to update package lists again..."
        if ! sudo apt-get update; then
            echo "Failed to update package lists"
            exit 1
        fi
    fi

    echo "Installing gnupg and curl if not already installed..."
    sudo apt-get install -y gnupg curl || {
        echo "Failed to install GnuPG or curl"
        exit 1
    }

    # Import the MongoDB 4.4 public key using signed-by method
    echo "Attempting to import MongoDB 4.4 server public key using signed-by method..."
    if ! curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/mongodb-archive-keyring.gpg; then
        rm -f /usr/share/keyrings/mongodb-archive-keyring.gpg
        echo "Failed to import MongoDB public key. Please check your internet connection and try again. Exiting."
        exit 1
    else
        echo "Successfully imported MongoDB public key using the signed-by method. Adding repository..."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME_MONGODB/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    fi

    # Update package lists after adding MongoDB repository
    while sudo fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo "Waiting for the apt lock to be released..."
        sleep 5
    done

    echo "Updating package lists after adding MongoDB repository..."
    if ! sudo apt-get update; then
        echo "Failed to update package lists after adding MongoDB repository."
        exit 1
    fi

    echo "Attempting to install MongoDB 4.4..."
    if ! sudo apt-get install -y --allow-change-held-packages mongodb-org=4.4.* mongodb-org-server=4.4.* mongodb-org-shell=4.4.* mongodb-org-mongos=4.4.* mongodb-org-tools=4.4.*; then
        echo "Initial MongoDB installation failed. Attempting to fix broken installations..."
        sudo apt-get --fix-broken install
        sudo apt-get autoremove -y
        sudo apt-get clean
        echo "Trying to install MongoDB 4.4 again..."
        if ! sudo apt-get install -y --allow-change-held-packages mongodb-org=4.4.* mongodb-org-server=4.4.* mongodb-org-shell=4.4.* mongodb-org-mongos=4.4.* mongodb-org-tools=4.4.*; then
            echo "Failed to install MongoDB 4.4 after attempting repairs. Exiting script."
            exit 1
        fi
    fi
fi

echo "Attempting to install mongosh..."
if ! sudo apt-get install -y mongosh; then
    echo "Failed to install mongosh. Attempting to fix broken installations..."
    sudo apt-get --fix-broken install
    sudo apt-get autoremove -y
    sudo apt-get clean
    echo "Trying to install mongosh again..."
    if ! sudo apt-get install -y mongosh; then
        echo "Failed to install mongosh after attempting repairs. Exiting script."
        exit 1
    fi
fi

echo "Pinning MongoDB 4.4 packages to prevent automatic updates..."
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections
echo "mongodb-org-shell hold" | sudo dpkg --set-selections
echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
echo "mongodb-org-tools hold" | sudo dpkg --set-selections

echo "Checking MongoDB service..."
if ! sudo systemctl is-active --quiet mongod; then
    echo "Starting MongoDB service..."
    sudo systemctl start mongod
else
    echo "MongoDB service is already running."
fi

if ! sudo systemctl is-enabled --quiet mongod; then
    echo "Enabling MongoDB service to start on boot..."
    sudo systemctl enable mongod
else
    echo "MongoDB service is already enabled to start on boot."
fi

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
sudo apt-get install -y python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libidn11-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson

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

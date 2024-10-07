#!/bin/bash

# Exit immediately if a command fails
set -e

# Check for open5gs-amfd and open5gs-upfd binaries to determine if Open5GS is already installed
if [ -f "open5gs/install/bin/open5gs-amfd" ] && [ -f "open5gs/install/bin/open5gs-upfd" ]; then
    echo "Open5GS is already installed. Skipping."
    exit 0
fi

# Starts a script in background that calls `sudo -v` every minute to ensure that sudo stays active, ensuring the script runs without requiring user interaction
sudo ls
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
open5gs_start_time=$(date +%s)


sudo rm -rf logs/

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if sudo systemctl stop unattended-upgrades &>/dev/null; then
  echo "Successfully stopped unattended-upgrades service."
fi
if sudo systemctl disable unattended-upgrades &>/dev/null; then
  echo "Successfully disabled unattended-upgrades service."
fi

ubuntu_codename=$(./install_scripts/get_ubuntu_codename.sh)

echo "Cloning Open5GS..."
if [ ! -d "open5gs" ]; then
    git clone https://github.com/open5gs/open5gs.git
fi
cd open5gs

echo "Starting installation of Open5GS..."

installed_version=$(mongod --version 2>/dev/null | grep -oP "(?<=v)\d+\.\d+\.\d+") || true
if [[ $installed_version == 4.4.* ]]; then
    echo "MongoDB version 4.4.x is already installed. Skipping MongoDB installation."
else
    # Get the latest Ubuntu version supported by MongoDB 4.4
    case "$ubuntu_codename" in
        "focal"|"bionic"|"xenial")
            ubuntu_codename_mongodb="$ubuntu_codename"
            ;;
        *)
            ubuntu_codename_mongodb="focal" # Default to the last supported version if the current one is too new
            ;;
    esac

    # Step 0: Ensure libssl is installed
    current_dir=$(pwd)
    # Check if libssl1.1 is installed
    if ! dpkg -s libssl1.1 >/dev/null 2>&1; then
        echo "libssl1.1 not found. Installing..."
        # Create a temporary directory and navigate to it
        temp_dir=$(mktemp -d -t libssl-XXXXXXXX)
        pushd "$temp_dir"
        
        wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
        sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb

        # Return to the original directory and remove the temporary directory
        popd
        rm -rf "$temp_dir"
    else
        echo "libssl1.1 is already installed."
    fi

    # Step 1: Uninstall any conflicting MongoDB version
    echo "Checking for existing MongoDB installations..."
    if dpkg -l | grep -qE "(mongodb-org|mongodb-server|mongodb-server-core)"; then
        echo "Removing conflicting MongoDB packages..."
        
        # Remove all installed MongoDB-related packages safely
        sudo apt-get purge -y mongodb-org mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools \
                             mongodb-server mongodb-server-core mongodb-clients || { echo "Failed to remove conflicting MongoDB packages"; exit 1; }

        # Clean up MongoDB directories (data and logs)
        sudo rm -rf /var/lib/mongodb
        sudo rm -rf /var/log/mongodb
    else
        echo "No conflicting MongoDB installations found."
    fi

    # If GPG step fails, try clearing MongoDB GPG key before proceeding:
    # sudo apt-key del 656408E390CFB1F5
    # sudo rm /etc/apt/sources.list.d/mongodb-org-4.4.list

    # Step 2: Installing MongoDB 4.4
    echo "Updating package lists..."
    sudo apt update || { echo "Failed to update package lists"; exit 1; }

    echo "Installing gnupg and curl if not already installed..."
    sudo apt install -y gnupg curl || { echo "Failed to install GnuPG or curl"; exit 1; }

    # Preferred method: Try importing the MongoDB 4.4 public key using signed-by method
    echo "Attempting to import MongoDB 4.4 server public key using signed-by method..."
    if ! curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg; then
        echo "Failed to import MongoDB public key using the modern method. Trying apt-key as fallback..."
        
        # Fallback 1: Use apt-key if modern method fails (deprecated method)
        if ! wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -; then
            echo "Failed to import MongoDB public key using apt-key."
            exit 1
        fi
        echo "Adding MongoDB 4.4 repository using apt-key method..."
        echo "deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu $ubuntu_codename_mongodb/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    else
        echo "Successfully imported MongoDB public key using the signed-by method. Adding repository..."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu $ubuntu_codename_mongodb/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    fi

    # Update package lists after adding MongoDB repository
    while sudo fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo "Waiting for the apt lock to be released..."
        sleep 5
    done

    echo "Updating package lists after adding MongoDB repository..."
    if ! sudo apt update; then
        echo "Failed to update package lists after adding MongoDB repository."
        exit 1
    fi

    echo "Attempting to install MongoDB 4.4..."
    if ! sudo apt-get install -y --allow-change-held-packages mongodb-org=4.4.* mongodb-org-server=4.4.* mongodb-org-shell=4.4.* mongodb-org-mongos=4.4.* mongodb-org-tools=4.4.*; then
        echo "Initial MongoDB installation failed. Attempting to fix broken installations..."
        sudo apt --fix-broken install
        sudo apt autoremove -y
        sudo apt clean
        echo "Trying to install MongoDB 4.4 again..."
        if ! sudo apt-get install -y --allow-change-held-packages mongodb-org=4.4.* mongodb-org-server=4.4.* mongodb-org-shell=4.4.* mongodb-org-mongos=4.4.* mongodb-org-tools=4.4.*; then
            echo "Failed to install MongoDB 4.4 after attempting repairs. Exiting script."
            exit 1
        fi
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
if ! ip link show ogstun > /dev/null 2>&1; then
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
sudo apt install -y python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libidn11-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson

rm -rf build

# Check if Open5GS has already been built and installed
if [ ! -d "build" ]; then
    echo "Compiling Open5GS with Meson..."
    meson build --prefix=$(pwd)/install
else
    echo "Open5GS build directory already exists."
fi

echo "Building Open5GS..."
ninja -C build

cd build
#echo "Running test programs..."
#meson test -v
echo "Installing Open5GS..."
ninja install

echo "Installation complete! Open5GS has been installed and configured."

cd ../.. # Main directory with open5gs
current_dir=$(pwd)

# Define library paths
lib_sbi_path="$current_dir/open5gs/build/lib/sbi"
lib_proto_path="$current_dir/open5gs/build/lib/proto"
lib_core_path="$current_dir/open5gs/install/lib/x86_64-linux-gnu"

# Create a new script in /etc/profile.d/ to update LD_LIBRARY_PATH for all users
create_ld_script() {
    local lib_path=$1
    local script_path="/etc/profile.d/open5gs_ld_library_path.sh"
    
    # Check if script exists and create if not
    if [[ ! -f $script_path ]]; then
        sudo sh -c "echo '#!/bin/bash' > $script_path"
        sudo sh -c "echo 'export LD_LIBRARY_PATH=' >> $script_path"
        sudo chmod +x $script_path
    fi

    # Check if path is already added to avoid duplicates
    if ! sudo grep -q "$lib_path" $script_path; then
        sudo sed -i "/^export LD_LIBRARY_PATH=/ s|$|:$lib_path|" $script_path
    fi
}

# Update LD_LIBRARY_PATH with all necessary library paths
create_ld_script $lib_sbi_path
create_ld_script $lib_proto_path
create_ld_script $lib_core_path

# Also update LD_LIBRARY_PATH for the current shell session
export LD_LIBRARY_PATH=$lib_sbi_path:$lib_proto_path:$lib_core_path:$LD_LIBRARY_PATH

# Inform the user about changes
echo "LD_LIBRARY_PATH updated globally for all users."

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh 

# Calculate how long the script took to run
open5gs_end_time=$(date +%s)
if [ -n "$open5gs_start_time" ]; then
  duration=$((open5gs_end_time - open5gs_start_time))
  duration_minutes=$(echo "scale=5; $duration / 60" | bc)
  echo "The Open5GS installation process took $duration_minutes minutes to complete."
  echo "$duration_minutes minutes" > install_time.txt
fi

echo "The Open5GS installation completed successfully."

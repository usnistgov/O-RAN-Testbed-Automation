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

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"

UBUNTU_CODENAME=$(./install_scripts/get_ubuntu_codename.sh)
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

        # Remove all installed MongoDB-related packages
        sudo apt-get remove --purge -y mongodb-org mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools \
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
        sudo "$SCRIPT_DIR/install_scripts/./remove_expired_apt_keys.sh"
        echo "Trying to update package lists again..."
        if ! sudo apt-get update; then
            echo "Failed to update package lists"
            exit 1
        fi
    fi

    echo "Installing gnupg and curl if not already installed..."
    sudo env $APTVARS apt-get install -y gnupg curl || {
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
    if ! sudo env $APTVARS apt-get install -y --allow-change-held-packages mongodb-org=4.4.* mongodb-org-server=4.4.* mongodb-org-shell=4.4.* mongodb-org-mongos=4.4.* mongodb-org-tools=4.4.*; then
        echo "Initial MongoDB installation failed. Attempting to fix broken installations..."
        sudo apt-get --fix-broken install
        sudo apt-get autoremove -y
        sudo apt-get clean
        echo "Trying to install MongoDB 4.4 again..."
        if ! sudo env $APTVARS apt-get install -y --allow-change-held-packages mongodb-org=4.4.* mongodb-org-server=4.4.* mongodb-org-shell=4.4.* mongodb-org-mongos=4.4.* mongodb-org-tools=4.4.*; then
            echo "Failed to install MongoDB 4.4 after attempting repairs. Exiting script."
            exit 1
        fi
    fi
fi

echo "Attempting to install mongosh..."
if ! sudo env $APTVARS apt-get install -y --allow-change-held-packages mongosh; then
    echo "Failed initial attempt to install mongosh. Adding MongoDB 5.0 repository for mongosh..."
    # Import the MongoDB 5.0 public key
    if ! curl -fsSL https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -; then
        echo "Failed to import MongoDB 5.0 public key. Exiting."
        exit 1
    fi
    # Add the MongoDB 5.0 repository
    echo "deb [ arch=$(dpkg --print-architecture) ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list

    # Update package lists after adding MongoDB repository
    while sudo fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo "Waiting for the apt lock to be released..."
        sleep 5
    done

    sudo apt-get update
    if ! sudo env $APTVARS apt-get install -y --allow-change-held-packages mongodb-mongosh; then
        echo "Failed to install mongosh even from MongoDB 5.0 repository. Attempting to fix broken installations..."
        sudo apt-get --fix-broken install
        sudo apt-get autoremove -y
        sudo apt-get clean
        echo "Trying to install mongosh again..."
        if ! sudo env $APTVARS apt-get install -y --allow-change-held-packages mongodb-mongosh; then
            echo "An error occured. Running dpkg --configure -a to ensure all packages are properly configured..."
            sudo dpkg --configure -a || true
            echo "Failed to install mongosh after attempting repairs. Exiting script."
            exit 1
        fi
    fi
else
    echo "mongosh installed successfully from current repositories."
fi

echo "Pinning MongoDB 4.4 packages to prevent automatic updates..."
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-database hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections
echo "mongodb-mongosh hold" | sudo dpkg --set-selections
echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
echo "mongodb-org-tools hold" | sudo dpkg --set-selections

echo "Ensuring MongoDB service is properly configured..."

# Check if the mongodb user exists
if ! getent passwd mongodb >/dev/null 2>&1; then
    echo "mongodb user does not exist. Creating..."
    sudo useradd -r -M -d /var/lib/mongodb -s /bin/false mongodb
else
    echo "mongodb user already exists."
fi

# Check if the mongodb group exists
if ! getent group mongodb >/dev/null 2>&1; then
    echo "mongodb group does not exist. Creating..."
    sudo groupadd mongodb
    # Add the mongodb user to the mongodb group, if not already added
    sudo usermod -a -G mongodb mongodb
else
    echo "mongodb group already exists."
fi
# Ensure the MongoDB configuration directory and file are correctly set up
CONFIG_DIR="/etc/mongod"
CONFIG_FILE="$CONFIG_DIR/mongod.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating MongoDB configuration directory and file..."
    sudo mkdir -p "$CONFIG_DIR"
    echo "storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  bindIp: 0.0.0.0
  port: 27017
security:
  authorization: disabled" | sudo tee "$CONFIG_FILE"
fi

sudo mkdir -p /var/lib/mongodb /var/log/mongodb
sudo chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb

echo "Enabling MongoDB service..."
sudo ./install_scripts/start_mongodb.sh

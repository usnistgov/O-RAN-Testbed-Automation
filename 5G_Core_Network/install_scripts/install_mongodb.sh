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
MONGODB_MAJOR="7.0"
INSTALLED_VERSION=$(mongod --version 2>/dev/null | grep -oP "(?<=v)\d+\.\d+\.\d+") || true

case "$UBUNTU_CODENAME" in
"jammy" | "focal")
    UBUNTU_CODENAME_MONGODB="$UBUNTU_CODENAME"
    ;;
*)
    UBUNTU_CODENAME_MONGODB="jammy"
    echo "Ubuntu codename '$UBUNTU_CODENAME' is not yet a MongoDB-supported codename. Falling back to '$UBUNTU_CODENAME_MONGODB' repository for MongoDB $MONGODB_MAJOR."
    ;;
esac

apt_update() {
    while sudo fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo "Waiting for the apt lock to be released..."
        sleep 5
    done
    if ! sudo apt-get update; then
        sudo "$PARENT_DIR/install_scripts/./remove_expired_apt_keys.sh"
        echo "Trying to update package lists again..."
        if ! sudo apt-get update; then
            echo "Failed to update package lists."
            exit 1
        fi
    fi
}

if [[ "$INSTALLED_VERSION" == "$MONGODB_MAJOR".* ]]; then
    echo "MongoDB version $MONGODB_MAJOR.x is already installed."
else
    echo "Checking for existing MongoDB installations..."
    for package in mongosh mongodb-mongosh mongodb-mongosh-shared-openssl11 mongodb-mongosh-shared-openssl3; do
        echo "$package install" | sudo dpkg --set-selections 2>/dev/null || true
        if dpkg-query -W -f='${Status}\n' "$package" 2>/dev/null | grep -qv 'not-installed'; then
            echo "Purging package: $package"
            sudo env $APTVARS apt-get remove --purge -y "$package" >/dev/null 2>&1 || true
            sudo dpkg --purge --force-all "$package" >/dev/null 2>&1 || true
        fi
    done
    sudo env $APTVARS apt-get --fix-broken install -y >/dev/null 2>&1 || true
    if dpkg -l | grep -qE "(mongodb-org|mongodb-server|mongodb-server-core|mongo-tools|mongosh|mongodb-mongosh)"; then
        echo "Removing conflicting MongoDB packages..."
        sudo env $APTVARS apt-get remove --purge -y mongodb-org mongodb-org-database mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools mongodb-server mongodb-server-core mongodb-clients mongo-tools mongosh mongodb-mongosh >/dev/null 2>&1 || true
    else
        echo "No conflicting MongoDB installations found."
    fi

    sudo rm -f /etc/apt/sources.list.d/mongodb-org-*.list
    sudo rm -f /usr/share/keyrings/mongodb-server-*.gpg /usr/share/keyrings/mongodb-archive-keyring.gpg

    echo "Updating package lists..."
    apt_update

    echo "Installing prerequisites..."
    sudo env $APTVARS apt-get install -y gnupg curl ca-certificates || {
        echo "Failed to install prerequisites for MongoDB repository setup."
        exit 1
    }

    echo "Importing MongoDB $MONGODB_MAJOR signing key..."
    if ! curl -fsSL "https://pgp.mongodb.com/server-$MONGODB_MAJOR.asc" | sudo gpg --dearmor --yes -o "/usr/share/keyrings/mongodb-server-$MONGODB_MAJOR.gpg"; then
        echo "Failed to import MongoDB signing key."
        exit 1
    fi
    sudo chmod a+r "/usr/share/keyrings/mongodb-server-$MONGODB_MAJOR.gpg"

    echo "Adding MongoDB $MONGODB_MAJOR repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-server-$MONGODB_MAJOR.gpg] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME_MONGODB/mongodb-org/$MONGODB_MAJOR multiverse" | sudo tee "/etc/apt/sources.list.d/mongodb-org-$MONGODB_MAJOR.list" >/dev/null

    apt_update

    echo "Installing MongoDB $MONGODB_MAJOR packages..."
    if ! sudo env $APTVARS apt-get install -y --allow-change-held-packages --allow-downgrades \
        mongodb-org=$MONGODB_MAJOR.* mongodb-org-server=$MONGODB_MAJOR.* mongodb-org-shell=$MONGODB_MAJOR.* mongodb-org-mongos=$MONGODB_MAJOR.* mongodb-org-tools=$MONGODB_MAJOR.* mongodb-mongosh; then
        echo "Initial MongoDB installation failed. Attempting automatic repair..."
        sudo apt-get --fix-broken install -y || true
        sudo apt-get autoremove -y || true
        sudo apt-get clean || true
        echo "Retrying MongoDB $MONGODB_MAJOR installation..."
        if ! sudo env $APTVARS apt-get install -y --allow-change-held-packages --allow-downgrades \
            mongodb-org=$MONGODB_MAJOR.* mongodb-org-server=$MONGODB_MAJOR.* mongodb-org-shell=$MONGODB_MAJOR.* mongodb-org-mongos=$MONGODB_MAJOR.* mongodb-org-tools=$MONGODB_MAJOR.* mongodb-mongosh; then
            echo "Failed to install MongoDB $MONGODB_MAJOR after retry."
            exit 1
        fi
    fi
fi

echo "Pinning MongoDB $MONGODB_MAJOR packages to prevent automatic updates..."
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-database hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections
echo "mongodb-org-shell hold" | sudo dpkg --set-selections
echo "mongodb-mongosh hold" | sudo dpkg --set-selections
echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
echo "mongodb-org-tools hold" | sudo dpkg --set-selections

echo "Ensuring MongoDB service is properly configured..."

# Check if the mongodb group exists
if ! getent group mongodb >/dev/null 2>&1; then
    echo "mongodb group does not exist. Creating..."
    sudo groupadd mongodb
else
    echo "mongodb group already exists."
fi

# Check if the mongodb user exists
if ! getent passwd mongodb >/dev/null 2>&1; then
    echo "mongodb user does not exist. Creating..."
    sudo useradd -r -M -d /var/lib/mongodb -s /bin/false -g mongodb mongodb
else
    echo "mongodb user already exists."
    # Add the mongodb user to the mongodb group, if not already added
    sudo usermod -a -G mongodb mongodb
fi
# Ensure the MongoDB configuration directory and file are correctly set up
CONFIG_DIR="/etc/mongod"
CONFIG_FILE="$CONFIG_DIR/mongod.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating MongoDB configuration directory and file..."
    sudo mkdir -p "$CONFIG_DIR"
    echo "storage:
  dbPath: /var/lib/mongodb
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
sudo chown --recursive mongodb:mongodb /var/lib/mongodb /var/log/mongodb

echo "Enabling MongoDB service..."
sudo ./install_scripts/start_mongodb.sh

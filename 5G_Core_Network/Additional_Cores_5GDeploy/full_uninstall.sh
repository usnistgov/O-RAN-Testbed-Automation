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

# Do not exit immediately if a command fails
set +e

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$SCRIPT_DIR"

./install_scripts/uninstall_lazydocker.sh

cd $SCRIPT_DIR/5gdeploy

echo "Removing system packages (httpie, jq, python3-libconf, wireshark-common, nodejs)..."
sudo apt remove --purge -y httpie jq python3-libconf wireshark-common nodejs
sudo apt autoremove --purge -y

echo "Removing wireshark group membership for $(id -un)..."
sudo deluser $(id -un) wireshark

echo "Removing NodeSource repo and key..."
sudo rm -f /etc/apt/sources.list.d/nodesource.list
sudo rm -f /etc/apt/keyrings/nodesource.gpg

echo "Removing yq snap..."
sudo snap remove yq

echo "Removing Docker and cleaning config..."
sudo apt remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras docker-scan-plugin
sudo apt autoremove --purge -y
sudo systemctl stop docker
sudo systemctl disable docker
sudo rm -rf /etc/docker
sudo rm -rf /home/docker
sudo groupdel docker
sudo deluser $(id -un) docker

# Reset the shell's command hash table to recognize changes in available executables
hash -r

cd $SCRIPT_DIR

echo "Removing 5G Core Deployment Helper (5gdeploy) directory..."
sudo rm -rf 5gdeploy/
sudo rm -rf compose/
sudo rm -rf logs

echo "Successfully uninstalled the 5G Core Deployment Helper (5gdeploy)."

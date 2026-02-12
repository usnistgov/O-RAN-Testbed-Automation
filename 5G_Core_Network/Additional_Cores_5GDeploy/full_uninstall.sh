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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$SCRIPT_DIR"

echo "Stopping all 5G Core Deployment Helper (5gdeploy) containers..."
./stop.sh

./install_scripts/uninstall_lazydocker.sh

cd $SCRIPT_DIR/5gdeploy

echo "Removing system packages (httpie, jq, python3-libconf, wireshark-common, nodejs, npm)..."
sudo apt-get remove --purge -y httpie jq python3-libconf wireshark-common nodejs npm
sudo apt-get autoremove --purge -y

echo "Cleaning npm cache directories..."
# Code from (https://stackoverflow.com/a/41057802/8687026):
sudo rm -rf /usr/local/bin/npm
sudo rm -rf /usr/local/share/man/man1/node*
sudo rm -rf /usr/local/lib/dtrace/node.d
sudo rm -rf ~/.npm
sudo rm -rf ~/.node-gyp
sudo rm -rf /opt/local/bin/node
sudo rm -rf /opt/local/include/node
sudo rm -rf /opt/local/lib/node_modules
sudo rm -rf /usr/local/lib/node*
sudo rm -rf /usr/local/include/node*
sudo rm -rf /usr/local/bin/node*

echo "Removing wireshark group membership for $(id -un)..."
sudo deluser $(id -un) wireshark

echo "Removing NodeSource repo and key..."
sudo rm -f /etc/apt/sources.list.d/nodesource.list
sudo rm -f /etc/apt/keyrings/nodesource.gpg

echo "Removing yq snap..."
sudo snap remove yq

cd $SCRIPT_DIR

echo "Removing Docker and cleaning config..."
./install_scripts/uninstall_docker.sh

echo "Removing 5G Core Deployment Helper (5gdeploy) directory..."
sudo rm -rf 5gdeploy/
# sudo rm -rf phoenix-repo/
sudo rm -rf compose/
sudo rm -rf logs/
sudo rm -rf configs/

if [ -d phoenix-repo ]; then
    echo
    echo "The directory $SCRIPT_DIR/phoenix-repo/ still exists. Please remove it manually if it is no longer needed."
fi

echo
echo
echo "################################################################################"
echo "# Successfully uninstalled the 5G Core Deployment Helper (5gdeploy).           #"
echo "################################################################################"

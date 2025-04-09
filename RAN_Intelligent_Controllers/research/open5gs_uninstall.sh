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

UNINSTALL_MONGODB=1

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "Ensuring all Open5GS processes are stopped..."
./stop.sh

sudo "$SCRIPT_DIR/./install_scripts/uninstall_mongodb.sh"

# Remove open5gs user and group
sudo userdel open5gs
sudo groupdel open5gs

# Define library paths
LIB_SBI_PATH="${SCRIPT_DIR}/open5gs/build/lib/sbi"
LIB_PROTO_PATH="${SCRIPT_DIR}/open5gs/build/lib/proto"
LIB_CORE_PATH="${SCRIPT_DIR}/open5gs/install/lib/x86_64-linux-gnu"

# Remove the TUN Device
sudo ip link delete ogstun

# Uninstall Dependencies
sudo apt-get remove --purge -y python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libmongoc-dev libbson-dev libyaml-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson
sudo apt-get remove --purge -y libidn-dev libidn11-dev

sudo apt-get autoremove -y
sudo apt-get clean

sudo rm -rf open5gs/
sudo rm -rf /var/log/open5gs
sudo rm -rf logs/
sudo rm -rf configs/
sudo rm -rf install_time.txt

#############!!!!!!!!!!!! TODO: continue uninstalling:

# cd "$SCRIPT_DIR"

# echo "Installing WebUI for Subscriber Registration..."
# sudo ./install_scripts/install_webui.sh

# Unset the LD_LIBRARY_PATH environment variable and script that sets it
sudo rm /etc/profile.d/open5gs_ld_library_path.sh
unset LD_LIBRARY_PATH

echo "The Open5GS uninstallation completed successfully."

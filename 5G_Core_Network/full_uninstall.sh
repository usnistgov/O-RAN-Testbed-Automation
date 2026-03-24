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

echo "# Script: $(realpath "$0")..."

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "Stopping all Open5GS processes..."
./stop.sh

echo "Reverting network configurations..."
./install_scripts/revert_network_config.sh

if dpkg -l | grep -q "^ii  open5gs"; then
    sudo env $APTVARS apt-get remove --purge -y open5gs >/dev/null 2>&1 || true
fi

sudo ./install_scripts/uninstall_mongodb.sh

echo "Removing Open5GS user and group..."
if getent passwd open5gs >/dev/null; then sudo userdel open5gs; fi
if getent group open5gs >/dev/null; then sudo groupdel open5gs; fi

echo "Removing Open5GS installation directory..."
sudo rm -rf open5gs/
sudo rm -rf /var/log/open5gs

if ls open5gs-* 1>/dev/null 2>&1; then
    echo "Removing intermediate open5gs directories from older versions..."
    for INTERMEDIATE_DIR in open5gs-*; do
        if [[ -d "$INTERMEDIATE_DIR" && "$INTERMEDIATE_DIR" != "open5gs-*" ]]; then
            echo "Removing intermediate open5gs directory: $INTERMEDIATE_DIR"
            sudo rm -rf "$INTERMEDIATE_DIR"
        fi
    done
fi

mkdir -p logs
cd logs
echo "Uninstalling WebUI..."
if ! (
    set -o pipefail
    curl -fsSL https://open5gs.org/open5gs/assets/webui/uninstall | sudo -E bash -
); then
    echo "Failed to uninstall WebUI"
    return 1 2>/dev/null || exit 1
fi
cd ..

echo "Unsetting LD_LIBRARY_PATH..."
sudo rm -f /etc/profile.d/open5gs_ld_library_path.sh
unset LD_LIBRARY_PATH

sudo rm -rf logs/
sudo rm -rf configs/
sudo rm -rf install_time.txt

if command -v docker &>/dev/null && [ -n "$(sudo docker images -q 5gdeploy.localhost/bridge 2>/dev/null)" ]; then
    cd Additional_Cores_5GDeploy
    ./full_uninstall.sh
    cd ..
fi

echo
echo
echo "################################################################################"
echo "# Successfully uninstalled Open5GS                                             #"
echo "################################################################################"

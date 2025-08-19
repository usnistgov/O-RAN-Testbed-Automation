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
    sudo $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "Stopping Next Generation Node B..."
./stop.sh

# First uninstall the User Equipment
cd ../User_Equipment

if [ -d openairinterface5g ]; then
    cd "openairinterface5g/cmake_targets"
    ./build_oai -C --clean-kernel
    cd ../..
fi
sudo rm -rf openairinterface5g

sudo rm -rf logs/
sudo rm -rf configs/
sudo rm -rf install_time.txt

# Second uninstall the gNodeB
cd "$SCRIPT_DIR"

if [ -d openairinterface5g ]; then
    cd "openairinterface5g/cmake_targets"
    ./build_oai -C --clean-kernel
    cd ../..
fi
sudo rm -rf openairinterface5g

if [ -d o1-adapter ] || sudo docker images | grep -q "adapter-gnb"; then
    echo "Uninstalling O1 Adapter..."
    ./additional_scripts/uninstall_o1_adapter.sh bypass_confirmation
fi

sudo rm -rf logs/
sudo rm -rf configs/
sudo rm -rf install_time.txt

echo
echo
echo "################################################################################"
echo "# Successfully uninstalled OpenAirInterface UE and gNodeB                      #"
echo "################################################################################"

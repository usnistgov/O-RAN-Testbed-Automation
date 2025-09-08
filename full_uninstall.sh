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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ "$1" != "bypass_confirmation" ]; then
    clear
    echo "This script will remove Open5GS, srsRAN_Project, srsRAN_4G, and the Near-RT RIC by removing Docker and Kubernetes."
    echo "This is a destructive operation and may result in data loss."
    echo "Please ensure you have backed up any necessary data before proceeding."
    echo
    echo "Do you want to proceed? (yes/no)"
    read -r PROCEED
    if [ "$PROCEED" != "yes" ]; then
        echo "Exiting script."
        exit 0
    fi
fi

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

echo "Stopping 5G Core Network, srsRAN_Project, and srsRAN_4G..."
./stop.sh

echo
echo
echo "################################################################################"
echo "# Uninstalling 5G Core...                                                      #"
echo "################################################################################"
echo
echo

cd 5G_Core_Network
./full_uninstall.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Uninstalling User Equipment...                                               #"
echo "################################################################################"
echo
echo

cd User_Equipment
./full_uninstall.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Uninstalling Next Generation Node B...                                       #"
echo "################################################################################"
echo
echo

cd Next_Generation_Node_B
./full_uninstall.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Uninstalling Near-Real-Time RAN Intelligent Controller...                    #"
echo "################################################################################"
echo
echo

cd RAN_Intelligent_Controllers/Near-Real-Time-RIC
./full_uninstall.sh bypass_confirmation

echo
echo "To ensure components within the OpenAirInterface testbed are also uninstalled, run \"./OpenAirInterface_Testbed/full_uninstall.sh\"."

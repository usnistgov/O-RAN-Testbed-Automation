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

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd $(dirname "$SCRIPT_DIR")

# -----------------------------------------------------------------------------
# Migration from commit 310ca91b9f5f83a0d0b94affebfdc940005daf1a
# -----------------------------------------------------------------------------

if [ -d 5G_Core/open5gs ]; then
    echo "Updating 5G Core directory structure..."
    sudo mv 5G_Core/logs 5G_Core_Network || true
    sudo mv 5G_Core/open5gs 5G_Core_Network || true
    sudo mv 5G_Core/install_time.txt 5G_Core_Network || true
    sudo rm -rf 5G_Core/configs
    sudo rm -rf 5G_Core_Network/configs
    sudo rm -rf 5G_Core_Network/open5gs/build
    sudo rm -rf 5G_Core_Network/open5gs/install
    if [ -z "$(ls -A 5G_Core)" ]; then
        sudo rm -rf 5G_Core
    fi
    echo "The 5G Core needs to be reinstalled with 5G_Core_Network/full_install.sh."
fi
if [ -d gNodeB/srsRAN_Project ]; then
    echo "Updating gNodeB directory structure..."
    sudo mv gNodeB/configs Next_Generation_Node_B || true
    if [ -d gNodeB/czmq ]; then
        sudo mv gNodeB/czmq Next_Generation_Node_B
        echo "Updating gNodeB czmq link in UE..."
        sudo rm -rf User_Equipment/czmq
        ln -s ../Next_Generation_Node_B/czmq User_Equipment/czmq
    fi
    if [ -d gNodeB/libzmq ]; then
        sudo mv gNodeB/libzmq Next_Generation_Node_B
        echo "Updating gNodeB libzmq link in UE..."
        sudo rm -rf User_Equipment/libzmq
        ln -s ../Next_Generation_Node_B/libzmq User_Equipment/libzmq
    fi
    sudo mv gNodeB/logs Next_Generation_Node_B || true
    sudo mv gNodeB/srsRAN_Project Next_Generation_Node_B || true
    sudo mv gNodeB/install_time.txt Next_Generation_Node_B || true
    if [ -z "$(ls -A gNodeB)" ]; then
        sudo rm -rf gNodeB
    fi
fi
if [ -d RAN_Intelligent_Controller/ric-dep ]; then
    echo "Updating RIC directory structure..."
    sudo mv RAN_Intelligent_Controller/ric-dep RAN_Intelligent_Controller/Near-Real-Time-RIC
    sudo mv RAN_Intelligent_Controller/appmgr RAN_Intelligent_Controller/Near-Real-Time-RIC || true
    sudo mv RAN_Intelligent_Controller/e2-interface RAN_Intelligent_Controller/Near-Real-Time-RIC || true
    sudo mv RAN_Intelligent_Controller/charts RAN_Intelligent_Controller/Near-Real-Time-RIC || true
    sudo mv RAN_Intelligent_Controller/xApps RAN_Intelligent_Controller/Near-Real-Time-RIC || true
    sudo mv RAN_Intelligent_Controller/logs RAN_Intelligent_Controller/Near-Real-Time-RIC || true
    sudo mv RAN_Intelligent_Controller/install_time.txt RAN_Intelligent_Controller/Near-Real-Time-RIC || true
fi

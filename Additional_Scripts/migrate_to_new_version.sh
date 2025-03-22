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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"

if [ -d 5G_Core/open5gs ] || [ -d gNodeB/srsRAN_Project ] || [ -d RAN_Intelligent_Controller/ric-dep ]; then
    echo
    echo
    echo "################################################################################"
    echo "# Migrating from commit 310ca91b9f5f83a0d0b94affebfdc940005daf1a               #"
    echo "################################################################################"
    echo
    echo

    if [ -d 5G_Core/open5gs ]; then
        echo "Updating 5G Core directory structure..."
        sudo rm -rf 5G_Core/configs
        sudo mv 5G_Core/* 5G_Core_Network
        sudo rm -rf 5G_Core_Network/configs
        sudo rm -rf 5G_Core_Network/open5gs/build
        sudo rm -rf 5G_Core_Network/open5gs/install
        sudo rm -rf 5G_Core
    fi
    if [ -d gNodeB/srsRAN_Project ]; then
        echo "Updating gNodeB directory structure..."
        sudo mv gNodeB/* Next_Generation_Node_B
        # Move czmq and libzmq directories to User_Equipment
        if [ -d Next_Generation_Node_B/czmq ]; then
            sudo rm -rf User_Equipment/czmq
            mv Next_Generation_Node_B/czmq User_Equipment
        fi
        if [ -d Next_Generation_Node_B/libzmq ]; then
            sudo rm -rf User_Equipment/libzmq
            mv Next_Generation_Node_B/libzmq User_Equipment
        fi
        # Link czmq and libzmq directories from User_Equipment to Next_Generation_Node_B
        if [ -d User_Equipment/czmq ]; then
            echo "Updating gNodeB czmq link in UE..."
            sudo rm -rf Next_Generation_Node_B/czmq
            ln -s ../User_Equipment/czmq Next_Generation_Node_B/czmq
        fi
        if [ -d User_Equipment/libzmq ]; then
            echo "Updating gNodeB libzmq link in UE..."
            sudo rm -rf Next_Generation_Node_B/libzmq
            ln -s ../User_Equipment/libzmq Next_Generation_Node_B/libzmq
        fi
        sudo rm -rf gNodeB
    fi
    if [ -d RAN_Intelligent_Controller/ric-dep ]; then
        echo "Updating RIC directory structure..."
        sudo mv RAN_Intelligent_Controller/* RAN_Intelligent_Controllers/Near-Real-Time-RIC
        sudo rm -rf RAN_Intelligent_Controller
    fi

    echo "Ensuring the apt keys are not expired..."
    sudo ./Additional_Scripts/remove_expired_apt_keys.sh

    echo
    echo "The 5G Core needs to be reinstalled with ./5G_Core_Network/full_install.sh."
    echo "Successfully migrated from commit 310ca91b9f5f83a0d0b94affebfdc940005daf1a to the new version."
    echo
fi

if [ -d OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Near-Real-Time-RIC ]; then
    echo
    echo
    echo "################################################################################"
    echo "# Migrating from commit 630c2f212bb7ddd748fdf94013bec163b4b8d647               #"
    echo "################################################################################"
    echo
    echo
    sudo mv OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Near-Real-Time-RIC/* OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC
    sudo rm -rf OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Near-Real-Time-RIC
    echo "Successfully migrated from commit 630c2f212bb7ddd748fdf94013bec163b4b8d647 to the new version."
    echo
fi

echo "Updating package lists..."
cd $SCRIPT_DIR
if ! sudo apt-get update; then
    sudo ./remove_expired_apt_keys.sh
    echo "Trying to update package lists again..."
    if ! sudo apt-get update; then
        echo "Failed to update package lists"
        exit 1
    fi
fi

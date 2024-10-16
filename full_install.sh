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

Open5GS_Installed=false
if [ -f "5G_Core/open5gs/install/bin/open5gs-amfd" ] && [ -f "5G_Core/open5gs/install/bin/open5gs-upfd" ]; then
    Open5GS_Installed=true
fi
gNodeB_Installed=false
if [ -f "gNodeB/srsRAN_Project/build/apps/gnb/gnb" ]; then
    gNodeB_Installed=true
fi
UE_Installed=false
if [ -f "User_Equipment/srsRAN_4G/build/srsue/src/srsue" ]; then
    UE_Installed=true
fi
# If any of them are installed then ask the user if they should be reset
if [ "$Open5GS_Installed" = true ] || [ "$gNodeB_Installed" = true ] || [ "$UE_Installed" = true ]; then
    echo "Previous installations were found, do you want to keep the old installations? (y/n)"
    read -r keep
    # Only allow case insensitive y, yes, n, and no
    if [ "$keep" != "y" ] && [ "$keep" != "yes" ] && [ "$keep" != "n" ] && [ "$keep" != "no" ]; then
        echo "Invalid input. Exiting."
        exit 1
    fi
    if [ "$keep" = "n" ] || [ "$keep" = "no" ]; then
        sudo rm -rf 5G_Core/open5gs
        sudo rm -rf 5G_Core/logs
        sudo rm -rf 5G_Core/configs
        sudo rm -rf gNodeB/srsRAN_Project
        sudo rm -rf gNodeB/czmq
        sudo rm -rf gNodeB/libzmq
        sudo rm -rf gNodeB/logs
        sudo rm -rf gNodeB/configs
        sudo rm -rf User_Equipment/srsRAN_4G
        sudo rm -rf User_Equipment/czmq
        sudo rm -rf User_Equipment/libzmq
        sudo rm -rf User_Equipment/logs
        sudo rm -rf User_Equipment/configs
        sudo rm -rf RAN_Intelligent_Controller/ric-dep
        sudo rm -rf RAN_Intelligent_Controller/appmgr
        sudo rm -rf RAN_Intelligent_Controller/e2-interface
        sudo rm -rf RAN_Intelligent_Controller/charts
        sudo rm -rf RAN_Intelligent_Controller/xApps
        sudo rm -rf RAN_Intelligent_Controller/logs
        echo "Successfully removed previous installations."
    fi
fi

echo
echo
echo "################################################################################"
echo "# Installing 5G Core...                                                        #"
echo "################################################################################"
echo
echo

cd 5G_Core
./full_install.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Installing gNodeB...                                                         #"
echo "################################################################################"
echo
echo

cd gNodeB
./full_install.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Installing User Equipment...                                                 #"
echo "################################################################################"
echo
echo

cd User_Equipment
./full_install.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Installing RAN Intelligent Controller...                                     #"
echo "################################################################################"
echo
echo

cd RAN_Intelligent_Controller
./full_install.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Configuring the applications...                                              #"
echo "################################################################################"
echo
echo

cd 5G_Core
./generate_configurations.sh
cd ../gNodeB
./generate_configurations.sh
cd ../User_Equipment
./generate_configurations.sh
cd ..

echo
echo
echo "################################################################################"
echo "# Successfully installed the RIC, 5G Core, gNodeB, and UE.                     #"
echo "################################################################################"

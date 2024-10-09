#!/bin/bash

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

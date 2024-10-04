#!/bin/bash

# Exit immediately if a command fails
set -e

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
echo "# Installing User Equipment...                                                  #"
echo "################################################################################"
echo
echo

cd User_Equipment
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

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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Loop over all arguments to set KEEP_OLD_DIRS based on -y or -n
KEEP_OLD_DIRS=""
for arg in "$@"; do
    case $arg in
    -y | --yes)
        KEEP_OLD_DIRS="y"
        break
        ;;
    -n | --no)
        if [ "$KEEP_OLD_DIRS" != "y" ]; then
            KEEP_OLD_DIRS="n"
        fi
        ;;
    esac
done

# Check if the applications are already installed and ask the user if they should be reset
OPEN5GS_INSTALLED=false
if [ -f "5G_Core_Network/open5gs/install/bin/open5gs-amfd" ] && [ -f "5G_Core_Network/open5gs/install/bin/open5gs-upfd" ]; then
    OPEN5GS_INSTALLED=true
fi
GNODEB_INSTALLED=false
if [ -f "Next_Generation_Node_B/openairinterface5g/cmake_targets/ran_build/build/nr-softmodem" ]; then
    GNODEB_INSTALLED=true
fi
UE_INSTALLED=false
if [ -f "User_Equipment/openairinterface5g/cmake_targets/ran_build/build/nr-uesoftmodem" ]; then
    UE_INSTALLED=true
fi

# If any of them are installed then ask the user if they should be reset
if [[ "$OPEN5GS_INSTALLED" = true || "$GNODEB_INSTALLED" = true || "$UE_INSTALLED" = true ]]; then
    echo
    if [ -z "$KEEP_OLD_DIRS" ]; then
        echo "Previous installations were found, do you want to keep the old installations? (y/n)"
        read -r KEEP_OLD_DIRS
        # Normalize input to lowercase and only accept inputs: y, yes, n, no
        KEEP_OLD_DIRS=$(echo "$KEEP_OLD_DIRS" | tr '[:upper:]' '[:lower:]')
        if [[ "$KEEP_OLD_DIRS" != "y" && "$KEEP_OLD_DIRS" != "yes" && "$KEEP_OLD_DIRS" != "n" && "$KEEP_OLD_DIRS" != "no" ]]; then
            echo "Invalid input. Exiting."
            exit 1
        fi
    else
        if [[ "$KEEP_OLD_DIRS" == "n" || "$KEEP_OLD_DIRS" == "no" ]]; then
            echo "Previous installations were found, removing the old installations."
        else
            echo "Previous installations were found, keeping the old installations."
        fi
    fi
    if [[ "$KEEP_OLD_DIRS" = "n" || "$KEEP_OLD_DIRS" = "no" ]]; then
        sudo rm -rf 5G_Core_Network/open5gs
        sudo rm -rf 5G_Core_Network/logs
        sudo rm -rf 5G_Core_Network/configs
        sudo rm -rf 5G_Core_Network/install_time.txt
        sudo rm -rf User_Equipment/openairinterface5g
        sudo rm -rf User_Equipment/logs
        sudo rm -rf User_Equipment/configs
        sudo rm -rf User_Equipment/install_time.txt
        sudo rm -rf Next_Generation_Node_B/openairinterface5g
        sudo rm -rf Next_Generation_Node_B/logs
        sudo rm -rf Next_Generation_Node_B/configs
        sudo rm -rf Next_Generation_Node_B/install_time.txt
        sudo rm -rf RAN_Intelligent_Controllers/Flexible-RIC/flexric
        sudo rm -rf RAN_Intelligent_Controllers/Flexible-RIC/swig
        sudo rm -rf RAN_Intelligent_Controllers/Flexible-RIC/logs
        sudo rm -rf RAN_Intelligent_Controllers/Flexible-RIC/configs
        sudo rm -rf RAN_Intelligent_Controllers/Flexible-RIC/install_time.txt
        echo "Successfully removed previous installations."
    fi
fi

# Ensure backward compatibility with previous installations
sudo ./../Additional_Scripts/migrate_to_new_version.sh

echo
echo
echo "################################################################################"
echo "# Installing 5G Core...                                                        #"
echo "################################################################################"
echo
echo

cd 5G_Core_Network
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
echo "# Installing Next Generation Node B...                                         #"
echo "################################################################################"
echo
echo

cd Next_Generation_Node_B
./full_install.sh
cd ..

echo
echo
echo "################################################################################"
echo "# Installing Near-Real-Time RAN Intelligent Controller...                      #"
echo "################################################################################"
echo
echo

cd RAN_Intelligent_Controllers/Flexible-RIC
./full_install.sh

cd ../..

echo
echo
echo "################################################################################"
echo "# Configuring the applications...                                              #"
echo "################################################################################"
echo
echo

cd 5G_Core_Network
./generate_configurations.sh
cd ../User_Equipment
./generate_configurations.sh
cd ../Next_Generation_Node_B
./generate_configurations.sh
cd ../RAN_Intelligent_Controllers/Flexible-RIC
./generate_configurations.sh
cd ../..

echo
echo
echo "################################################################################"
echo "# Successfully installed the Near-RT RIC, 5G Core, gNodeB, and UE.             #"
echo "################################################################################"

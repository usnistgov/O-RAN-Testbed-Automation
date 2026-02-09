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
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Loop over all arguments to set KEEP_EXISTING_INSTALLS based on -y or -n
KEEP_EXISTING_INSTALLS=""
for arg in "$@"; do
    case $arg in
    -y | --yes)
        KEEP_EXISTING_INSTALLS="y"
        break
        ;;
    -n | --no)
        if [ "$KEEP_EXISTING_INSTALLS" != "y" ]; then
            KEEP_EXISTING_INSTALLS="n"
        fi
        ;;
    esac
done

if [ "$KEEP_EXISTING_INSTALLS" != "y" ]; then
    echo
    echo "The following components will be installed:"
    CORE_DISPLAY="Open5GS"
    if [ -f "5G_Core_Network/options.yaml" ]; then
        VAL=$(grep "^core_to_use:" "5G_Core_Network/options.yaml" | awk '{print $2}')
        if [ -n "$VAL" ]; then
            case $VAL in
            open5gs)
                CORE_DISPLAY="Open5GS"
                ;;
            5gdeploy-oai)
                CORE_DISPLAY="OpenAirInterface (via 5GDeploy)"
                ;;
            5gdeploy-free5gc)
                CORE_DISPLAY="Free5GC (via 5GDeploy)"
                ;;
            5gdeploy-open5gs)
                CORE_DISPLAY="Open5GS (via 5GDeploy)"
                ;;
            5gdeploy-phoenix)
                CORE_DISPLAY="Phoenix (via 5GDeploy)"
                ;;
            *)
                CORE_DISPLAY="$VAL"
                ;;
            esac
        fi
    fi
    echo " - 5G Core Network ($CORE_DISPLAY)"
    echo " - User Equipment (srsRAN_4G)"
    echo " - Next Generation Node B (srsRAN_Project)"
    if [ -d "RAN_Intelligent_Controllers/Near-Real-Time-RIC" ]; then
        echo " - Near-Real-Time RAN Intelligent Controller (O-RAN SC)"
    fi
    echo
    echo "Do you want to proceed? (Y/n)"
    read -r CONFIRM
    CONFIRM=$(echo "${CONFIRM:-y}" | tr '[:upper:]' '[:lower:]')
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "yes" ]]; then
        echo "Installation aborted."
        exit 0
    fi
fi

# Check if the applications are already installed and ask the user if they should be reset
OPEN5GS_INSTALLED=false
if [ -f "5G_Core_Network/open5gs/install/bin/open5gs-amfd" ] && [ -f "5G_Core_Network/open5gs/install/bin/open5gs-upfd" ]; then
    OPEN5GS_INSTALLED=true
fi
GNODEB_INSTALLED=false
if [ -f "Next_Generation_Node_B/srsRAN_Project/build/apps/gnb/gnb" ]; then
    GNODEB_INSTALLED=true
fi
UE_INSTALLED=false
if [ -f "User_Equipment/srsRAN_4G/build/srsue/src/srsue" ]; then
    UE_INSTALLED=true
fi

# If any of them are installed then ask the user if they should be reset
if [[ "$OPEN5GS_INSTALLED" = true || "$GNODEB_INSTALLED" = true || "$UE_INSTALLED" = true ]]; then
    echo
    if [ -z "$KEEP_EXISTING_INSTALLS" ]; then
        echo "Previous installations were found, do you want to keep the old installations? (Y/n)"
        read -r KEEP_EXISTING_INSTALLS
        # Normalize input to lowercase and default to 'y' if empty
        KEEP_EXISTING_INSTALLS=$(echo "${KEEP_EXISTING_INSTALLS:-y}" | tr '[:upper:]' '[:lower:]')
        if [[ "$KEEP_EXISTING_INSTALLS" != "y" && "$KEEP_EXISTING_INSTALLS" != "yes" && "$KEEP_EXISTING_INSTALLS" != "n" && "$KEEP_EXISTING_INSTALLS" != "no" ]]; then
            echo "Invalid input. Exiting."
            exit 1
        fi
    else
        if [[ "$KEEP_EXISTING_INSTALLS" == "n" || "$KEEP_EXISTING_INSTALLS" == "no" ]]; then
            echo "Previous installations were found, removing the old installations."
        else
            echo "Previous installations were found, keeping the old installations."
        fi
    fi
    if [[ "$KEEP_EXISTING_INSTALLS" = "n" || "$KEEP_EXISTING_INSTALLS" = "no" ]]; then
        sudo rm -rf 5G_Core_Network/open5gs
        sudo rm -rf 5G_Core_Network/logs
        sudo rm -rf 5G_Core_Network/configs
        sudo rm -rf 5G_Core_Network/install_time.txt
        sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/5gdeploy
        sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/compose
        sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/logs
        sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/configs
        sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/install_time.txt
        sudo rm -rf User_Equipment/srsRAN_4G
        sudo rm -rf User_Equipment/czmq
        sudo rm -rf User_Equipment/libzmq
        sudo rm -rf User_Equipment/logs
        sudo rm -rf User_Equipment/configs
        sudo rm -rf User_Equipment/install_time.txt
        sudo rm -rf Next_Generation_Node_B/srsRAN_Project
        sudo rm -rf Next_Generation_Node_B/czmq
        sudo rm -rf Next_Generation_Node_B/libzmq
        sudo rm -rf Next_Generation_Node_B/logs
        sudo rm -rf Next_Generation_Node_B/configs
        sudo rm -rf Next_Generation_Node_B/install_time.txt
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/ric-dep
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/appmgr
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/e2-interface
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/charts
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/xApps
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/logs
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/influxdb
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/influxdb_auth_token.json
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/additional_scripts/pod_pcaps
        sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/install_time.txt
        echo "Successfully removed previous installations."
    fi
fi

# Ensure backward compatibility with previous installations
sudo ./Additional_Scripts/migrate_to_new_version.sh

# Ensure the correct YAML editor is installed
sudo "$SCRIPT_DIR/5G_Core_Network/install_scripts/./ensure_consistent_yq.sh"

# Check which core will be used
if [ -f "5G_Core_Network/options.yaml" ]; then
    CORE_TO_USE=$(yq eval '.core_to_use' 5G_Core_Network/options.yaml)
fi
if [[ "$CORE_TO_USE" == "null" || -z "$CORE_TO_USE" ]]; then
    CORE_TO_USE="open5gs" # Default
fi

if [ "$CORE_TO_USE" == "open5gs" ]; then
    echo
    echo
    echo "################################################################################"
    echo "# Installing 5G Core Network (Open5GS)...                                      #"
    echo "################################################################################"
    echo
    echo

    cd 5G_Core_Network
    ./full_install.sh

    cd ..
fi

echo
echo
echo "################################################################################"
echo "# Installing User Equipment (srsRAN 4G)...                                     #"
echo "################################################################################"
echo
echo

cd User_Equipment
./full_install.sh

cd ..

echo
echo
echo "################################################################################"
echo "# Installing Next Generation Node B (srsRAN Project)...                        #"
echo "################################################################################"
echo
echo

cd Next_Generation_Node_B
./full_install.sh

cd ..

INSTALL_NEAR_RT_RIC=false
if [ -d "RAN_Intelligent_Controllers/Near-Real-Time-RIC" ]; then
    INSTALL_NEAR_RT_RIC=true
    echo
    echo
    echo "################################################################################"
    echo "# Installing Near-Real-Time RAN Intelligent Controller (O-RAN SC)...           #"
    echo "################################################################################"
    echo
    echo

    cd RAN_Intelligent_Controllers/Near-Real-Time-RIC
    ./full_install.sh

    cd ../..
fi

# If using a core from 5gdeploy, the installation needs to be after O-RAN SC's Near-RT RIC to prevent docker conflicts
if [ "$CORE_TO_USE" != "open5gs" ]; then
    echo
    echo
    echo "################################################################################"
    echo "# Installing 5G Core Network...                                                #"
    echo "################################################################################"
    echo
    echo

    cd 5G_Core_Network
    ./full_install.sh

    cd ..
fi

echo
echo
echo "################################################################################"
echo "# Configuring the applications...                                              #"
echo "################################################################################"
echo
echo

cd 5G_Core_Network
./generate_configurations.sh
cd ../Next_Generation_Node_B
./generate_configurations.sh
cd ../User_Equipment
./generate_configurations.sh
cd ..

if [ "$INSTALL_NEAR_RT_RIC" = true ]; then
    echo
    echo
    echo "################################################################################"
    echo "# Successfully installed the Near-RT RIC, 5G Core, gNodeB, and UE.             #"
    echo "################################################################################"
else
    echo
    echo
    echo "################################################################################"
    echo "# Successfully installed the 5G Core, gNodeB, and UE.                          #"
    echo "################################################################################"
fi

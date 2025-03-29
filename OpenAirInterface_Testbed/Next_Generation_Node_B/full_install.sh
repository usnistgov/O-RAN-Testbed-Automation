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

CLEAN_INSTALL=false

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Check if a symbolic link can be created to the openairinterface5g directory
if [ ! -f "openairinterface5g/cmake_targets/build_oai" ]; then
    sudo rm -rf openairinterface5g
    if [ -f "../User_Equipment/openairinterface5g/cmake_targets/build_oai" ]; then
        echo "Creating symbolic link to openairinterface5g..."
        ln -s "../User_Equipment/openairinterface5g" openairinterface5g
    fi
fi

# Check for gNB binary to determine if srsRAN_Project is already installed
if [ "$CLEAN_INSTALL" = false ] && [ -f "openairinterface5g/cmake_targets/ran_build/build/nr-softmodem" ]; then
    echo "Open Air Interface gNB is already installed, skipping."
    exit 0
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

if [ ! -d "openairinterface5g" ]; then
    echo "Cloning openairinterface5g..."
    ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/oai/openairinterface5g.git openairinterface5g
fi

# Modify CMakeLists.txt to set E2AP_VERSION to E2AP_V3 and KPM_VERSION to KPM_V3_00 (must match FlexRIC)
if [ -f "openairinterface5g/CMakeLists.txt" ]; then
    echo "Modifying CMakeLists.txt to set E2AP_VERSION to E2AP_V3..."
    sed -i 's/set(E2AP_VERSION "[^"]*"/set(E2AP_VERSION "E2AP_V3"/' openairinterface5g/CMakeLists.txt
fi
if [ -f "openairinterface5g/CMakeLists.txt" ]; then
    echo "Modifying CMakeLists.txt to set KPM_VERSION to KPM_V3_00..."
    sed -i 's/set(KPM_VERSION "[^"]*"/set(KPM_VERSION "KPM_V3_00"/' openairinterface5g/CMakeLists.txt
fi

# Apply patches to OpenAirInterface to add support for RSRP in the KPI report
if [ ! -f "openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.previous" ]; then
    cp openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.previous
    echo
    echo "Patching ran_func_kpm.c..."
    cd openairinterface5g
    git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.patch"
    cd ..
fi
if [ ! -f "openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.previous" ]; then
    cp openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.previous
    echo
    echo "Patching ran_func_kpm_subs.c..."
    cd openairinterface5g
    git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.patch"
    cd ..
fi
if [ ! -f "openairinterface5g/openair2/LAYER2/NR_MAC_gNB/main.c.previous" ]; then
    cp openairinterface5g/openair2/LAYER2/NR_MAC_gNB/main.c openairinterface5g/openair2/LAYER2/NR_MAC_gNB/main.c.previous
    echo
    echo "Patching main.c..."
    cd openairinterface5g
    git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/main.c.patch"
    cd ..
fi
if [ ! -f "openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.previous" ]; then
    cp openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.previous
    echo
    echo "Patching nr_mac_gNB.h..."
    cd openairinterface5g
    git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.patch"
    cd ..
fi

# If using Linux Mint, add support for Linux Mint 20, 21, and 22 to OpenAirInterface
if grep -q "Linux Mint" /etc/os-release; then
    echo
    echo "Linux Mint detected, attempting to patching OpenAirInterface to support Linux Mint 20, 21, and 22..."
    cd openairinterface5g
    git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/cmake_targets/tools/build_helper.patch" || true
    cd ..
    echo "Patching completed."
    echo
fi

echo "Updating package lists..."
sudo apt-get update

echo
echo
echo "Installing Open Air Interface Next Generation Node B..."
export DEBIAN_FRONTEND=noninteractive
# Modifies the needrestart configuration to suppress interactive prompts
if [ -f "/etc/needrestart/needrestart.conf" ]; then
    if ! grep -q "^\$nrconf{restart} = 'a';$" "/etc/needrestart/needrestart.conf"; then
        sudo sed -i "/\$nrconf{restart} = /c\$nrconf{restart} = 'a';" "/etc/needrestart/needrestart.conf"
        echo "Modified needrestart configuration to auto-restart services."
    fi
fi
export NEEDRESTART_SUSPEND=1

# Check if GCC 13 is installed, if not, install it and set it as the default
GCC_VERSION=$(gcc -v 2>&1 | grep "gcc version" | awk '{print $3}')
if [[ -z "$GCC_VERSION" || ! "$GCC_VERSION" == 13.* ]]; then
    echo "Installing GCC 13..."
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update
    sudo apt-get install -y gcc-13 g++-13
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
fi

if ! command -v cmake &>/dev/null; then
    echo "Installing CMake..."
    sudo apt-get install -y cmake
fi
CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
if [[ "$CMAKE_VERSION" == 3.16.* ]]; then
    echo "Detected CMake 3.16. Updating CMake for compatibility with OpenAirInterface..."
    # Add Kitware's APT repository
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo apt-key add -
    sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'
    sudo apt update
    sudo apt-get install -y cmake
fi

ADDITIONAL_FLAGS=""
# if clean install is true, add flag -C
if [ "$CLEAN_INSTALL" = true ]; then
    ADDITIONAL_FLAGS="-C"
fi

cd "$SCRIPT_DIR"

echo
echo
echo "Compiling and Installing Open Air Interface gNB..."

# Install OAI dependencies
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
./build_oai -I

# Build OAI 5G gNB
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
./build_oai --ninja --gNB --build-e2 -w SIMU $ADDITIONAL_FLAGS # -w USRP

cd "$SCRIPT_DIR"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
    DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
    echo "The gNodeB installation process took $DURATION_MINUTES minutes to complete."
    echo "$DURATION_MINUTES minutes" >>install_time.txt
fi

echo "The gNodeB installation completed successfully."

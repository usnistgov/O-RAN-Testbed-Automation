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

CLEAN_INSTALL=true # Note: If set to true, then full_install.sh needs to be ran in the Next_Generation_Node_B directory too.
DEBUG_SYMBOLS=false

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if ! grep -q avx2 /proc/cpuinfo; then
    echo "WARNING: Support for AVX2 is not available on this machine. Errors may occur when building due to unsupported AVX instructions."
    echo "Please consider following the instructions \"Enabling VT-x/AMD-V for the AVX2 instruction set\" in OpenAirInterface_Testbed/README.md."
    echo
    echo "Press any key to continue."
    read -r -n 1 -s
fi

# Check if a symbolic link can be created to the openairinterface5g directory
if [ ! -f "openairinterface5g/cmake_targets/build_oai" ]; then
    sudo rm -rf openairinterface5g
    if [ -f "../Next_Generation_Node_B/openairinterface5g/cmake_targets/build_oai" ]; then
        echo "Creating symbolic link to openairinterface5g..."
        ln -s "../Next_Generation_Node_B/openairinterface5g" openairinterface5g
    fi
fi

# Check for UE binary to determine if srsRAN_Project is already installed
if [ "$CLEAN_INSTALL" = false ] && [ -f "openairinterface5g/cmake_targets/ran_build/build/nr-uesoftmodem" ]; then
    echo "OpenAirInterface UE is already installed, skipping."
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

echo "Patching OpenAirInterface..."
./install_scripts/apply_patches.sh

echo
echo
echo "Installing OpenAirInterface User Equipment..."
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
    sudo apt-get update
    sudo apt-get install -y cmake
fi
CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
if [[ "$CMAKE_VERSION" == 3.16.* ]]; then
    echo "Detected CMake 3.16. Updating CMake for compatibility with OpenAirInterface..."
    # Add Kitware's APT repository
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo apt-key add -
    sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'
    sudo apt-get update
    sudo apt-get install -y cmake
fi

ADDITIONAL_FLAGS=""
if [ "$CLEAN_INSTALL" = true ]; then
    ADDITIONAL_FLAGS="-C"
fi
if [ "$DEBUG_SYMBOLS" = true ]; then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -g"
fi

cd "$SCRIPT_DIR"

echo
echo
echo "Compiling and Installing OpenAirInterface UE..."

# Install OAI dependencies
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
./build_oai -I

# Build OAI 5G UE
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
./build_oai --ninja --nrUE -w SIMU $ADDITIONAL_FLAGS # -w USRP

cd "$SCRIPT_DIR"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
    DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
    echo "The User Equipment installation process took $DURATION_MINUTES minutes to complete."
    echo "$DURATION_MINUTES minutes" >>install_time.txt
fi

echo "The User Equipment installation completed successfully."

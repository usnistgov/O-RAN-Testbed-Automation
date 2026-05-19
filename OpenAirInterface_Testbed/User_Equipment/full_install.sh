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

APPLY_PATCHES=true
CLEAN_INSTALL=false # Note: If set to true, then full_install.sh needs to be ran in the Next_Generation_Node_B directory too.
RADIO_TYPE="SIMU"   # Set to "SIMU", "ZMQ", or "USRP"
DEBUG_SYMBOLS=false

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
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

# Check for binary to determine if OpenAirInterface is already installed
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
    ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/oai/openairinterface5g.git openairinterface5g --https
fi

if [ "$APPLY_PATCHES" = true ]; then
    echo "Patching OpenAirInterface..."
    ./install_scripts/apply_patches.sh
fi

echo
echo
echo "Installing User Equipment (OpenAirInterface)..."
# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

# Check if GCC 13 or newer is installed, if not, install it and set it as the default
MIN_GCC_VERSION="13.0.0"
INSTALL_GCC=false
if ! command -v gcc >/dev/null 2>&1; then
    INSTALL_GCC=true
else
    GCC_VERSION=$(gcc -dumpfullversion -dumpversion)
    if dpkg --compare-versions "$GCC_VERSION" lt "$MIN_GCC_VERSION"; then
        INSTALL_GCC=true
    fi
fi
if [[ "$INSTALL_GCC" == "true" ]]; then
    echo "Installing GCC 13..."
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update
    sudo env $APTVARS apt-get install -y gcc-13 g++-13
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
fi

if ! command -v cmake &>/dev/null; then
    echo "Installing CMake..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y cmake
fi
CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
if [[ "$CMAKE_VERSION" == 3.16.* ]]; then
    echo "Detected CMake 3.16. Updating CMake for compatibility with OpenAirInterface..."
    # Add Kitware's apt repository
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo apt-key add -
    sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'
    sudo apt-get update
    sudo env $APTVARS apt-get install -y cmake
fi

if ! command -v ccache &>/dev/null; then
    echo "Installing ccache..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y ccache
fi

if ! dpkg -s libtool &>/dev/null; then
    echo "Installing libtool..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y libtool
fi

if ! dpkg -s libsimde-dev &>/dev/null; then
    echo "Attempting to install libsimde-dev..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y libsimde-dev || true
fi
if [ -d /usr/include/simde ]; then
    sudo chown --recursive root:root /usr/include/simde
    sudo find /usr/include/simde -type d -exec chmod 755 {} +
    sudo find /usr/include/simde -type f -exec chmod 644 {} +
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

if [ "$RADIO_TYPE" = "ZMQ" ]; then
    echo "Building ZeroMQ libzmq..."
    if [ -d ../Next_Generation_Node_B/libzmq ]; then
        if [ ! -L libzmq ]; then
            echo "Found gNodeB library. Creating libzmq link instead."
            ln -s ../Next_Generation_Node_B/libzmq libzmq
        else
            echo "Link to libzmq already created."
        fi
    else
        if [ ! -d libzmq ]; then
            ./install_scripts/git_clone.sh https://github.com/zeromq/libzmq.git
        fi
    fi

    if ! pkg-config --exists libzmq; then
        cd libzmq
        ./autogen.sh
        ./configure
        make -j$(nproc)
        sudo make install
        sudo ldconfig
        cd "$SCRIPT_DIR"
    fi

    echo
    echo "Building ZeroMQ czmq..."
    if [ -d ../Next_Generation_Node_B/czmq ]; then
        if [ ! -L czmq ]; then
            echo "Found gNodeB library. Creating czmq link instead."
            ln -s ../Next_Generation_Node_B/czmq czmq
        else
            echo "Link to czmq already created."
        fi
    else
        if [ ! -d czmq ]; then
            ./install_scripts/git_clone.sh https://github.com/zeromq/czmq.git
        fi
    fi

    if ! pkg-config --exists libczmq; then
        cd czmq
        ./autogen.sh
        ./configure
        make -j$(nproc)
        sudo make install
        sudo ldconfig
        cd "$SCRIPT_DIR"
    fi

    # Verify ZeroMQ installation
    if ! pkg-config --exists libzmq || ! pkg-config --exists libczmq; then
        echo "ZeroMQ was not installed correctly. Exiting."
        exit 1
    else
        echo "ZeroMQ installed successfully."
    fi

    cd "$SCRIPT_DIR"
fi

echo "Compiling and Installing OpenAirInterface UE..."

cd "$SCRIPT_DIR/openairinterface5g"
source oaienv

# Install OAI dependencies
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
./build_oai -I

# Build OAI 5G UE
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
if [ "$RADIO_TYPE" = "SIMU" ] || [ "$RADIO_TYPE" = "ZMQ" ]; then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -w $RADIO_TYPE"
else
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -w USRP"
fi
./build_oai --ninja --nrUE $ADDITIONAL_FLAGS

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

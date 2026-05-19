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
CLEAN_INSTALL=false # If SHARE_OAI_DIR_FROM_UE is true, set to false since the UE hosts openairinterface5g
RADIO_TYPE="SIMU"   # Set to "SIMU", "ZMQ", or "USRP"
DEBUG_SYMBOLS=false
NRSCOPE_GUI=false
TELNET_SERVER=true
E2_TERM_PORT=36421            # Default is 36421, which will result in no modification
E2_TERM_PORT_SUBSTITUTE=36423 # If E2_TERM_PORT is used already, substitute it before replacing with E2_TERM_PORT
SHARE_FLEXRIC_DIR_FROM_TESTBED=false
SHARE_OAI_DIR_FROM_UE=true

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Check if a symbolic link can be created to the openairinterface5g directory
if [ "$SHARE_OAI_DIR_FROM_UE" = true ] && [ ! -f "openairinterface5g/cmake_targets/build_oai" ]; then
    sudo rm -rf openairinterface5g
    echo "Creating symbolic link to openairinterface5g..."
    ln -s "../User_Equipment/openairinterface5g" openairinterface5g
fi

# Check for binary to determine if OpenAirInterface is already installed
if [ "$CLEAN_INSTALL" = false ] && [ -f "openairinterface5g/cmake_targets/ran_build/build/nr-softmodem" ]; then
    if [ "$NRSCOPE_GUI" != true ] || [ -f "openairinterface5g/cmake_targets/ran_build/build/libimscope.so" ]; then
        echo "OpenAirInterface gNB is already installed, skipping."
        exit 0
    fi
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

if [ "$SHARE_OAI_DIR_FROM_UE" = true ]; then
    # Make sure that the User Equipment has the source openairinterface5g repository
    mkdir -p "../User_Equipment" || true
    if [ ! -f "../User_Equipment/openairinterface5g/cmake_targets/build_oai" ]; then
        echo "Cloning shared openairinterface5g to User Equipment..."
        sudo rm -rf ../User_Equipment/openairinterface5g
        ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/oai/openairinterface5g.git ../User_Equipment/openairinterface5g --https
    fi
else
    if [ ! -d "openairinterface5g" ]; then
        echo "Cloning openairinterface5g..."
        sudo rm -rf openairinterface5g
        ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/oai/openairinterface5g.git openairinterface5g --https
    fi
fi

if [ "$APPLY_PATCHES" = true ]; then
    echo "Patching OpenAirInterface..."
    ./install_scripts/apply_patches.sh
fi

# Ensure that the flexric repository is cloned at the right commit
cd openairinterface5g/openair2/E2AP/
if [ "$SHARE_FLEXRIC_DIR_FROM_TESTBED" = true ]; then
    # Symbolic link to RAN_Intelligent_Controllers/Flexible-RIC/flexric
    FLEXRIC_PARENT_DIR="../../../../RAN_Intelligent_Controllers/Flexible-RIC"
    FLEXRIC_DIR="$FLEXRIC_PARENT_DIR/flexric"
    if [ ! -L "flexric" ]; then
        sudo rm -rf flexric
        ln -s "$FLEXRIC_DIR" flexric
    fi
else
    FLEXRIC_PARENT_DIR="$SCRIPT_DIR/openairinterface5g/openair2/E2AP"
    FLEXRIC_DIR="$FLEXRIC_PARENT_DIR/flexric"
    if [ -L "flexric" ]; then
        sudo rm -rf flexric
    fi
fi

cd "$SCRIPT_DIR"
if [ ! -d "$FLEXRIC_DIR/src/agent/e2_agent_api.c" ]; then
    echo "Cloning Flexible RAN Intelligent Controller (FlexRIC)..."
    ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/mosaic5g/flexric.git "$FLEXRIC_DIR" --https
fi

FLEXRIC_PATCH_DIR="../RAN_Intelligent_Controllers/Flexible-RIC"
if [ -f "$FLEXRIC_PATCH_DIR/install_scripts/apply_patches.sh" ] && [ ! -f "$FLEXRIC_DIR/README.previous.md" ]; then
    echo "Applying FlexRIC patches to openairinterface5g/openair2/E2AP/flexric..."
    "$FLEXRIC_PATCH_DIR/install_scripts/apply_patches.sh" "$FLEXRIC_DIR"
    if [ ! -f "$FLEXRIC_DIR/README.previous.md" ]; then
        echo "WARNING: Could not verify that FlexRIC patches were applied successfully."
        sleep 10
    fi
fi

CURRENT_E2_PORT=$(sed -nE 's/.*e2ap_server_port *= *([0-9]+);/\1/p' $FLEXRIC_DIR/src/agent/e2_agent_api.c)
if [ -z "$CURRENT_E2_PORT" ]; then
    echo "ERROR: e2ap_server_port not found in $FLEXRIC_DIR/src/agent/e2_agent_api.c" >&2
    exit 1
fi
# Check if the substitute port is already in use
if sudo find $FLEXRIC_DIR/ -type f -exec grep -l -w "$E2_TERM_PORT_SUBSTITUTE" {} + | grep -q .; then
    echo "ERROR: The E2 Termination Port Substitute ($E2_TERM_PORT_SUBSTITUTE) is already in use in the following files. Please choose a different substitute port."
    sudo find $FLEXRIC_DIR/ -type f -exec grep -l -w "$E2_TERM_PORT_SUBSTITUTE" {} +
    exit 1
fi
# Configure the E2 termination port
if [ "$E2_TERM_PORT" != "$CURRENT_E2_PORT" ]; then
    sudo find $FLEXRIC_DIR/ -type f -exec sed -i "s/$CURRENT_E2_PORT/$E2_TERM_PORT_SUBSTITUTE/g" {} + # Change current port to substitute
    sudo find $FLEXRIC_DIR/ -type f -exec sed -i "s/$E2_TERM_PORT_SUBSTITUTE/$E2_TERM_PORT/g" {} +    # Change substitute to specified port
    echo "Configured E2 termination from port $CURRENT_E2_PORT to port $E2_TERM_PORT"
fi

# Increase FR_CONF_FILE_LEN from 128 to 1024 to prevent buffer overflows with long paths
sed -i 's/#define FR_CONF_FILE_LEN 128/#define FR_CONF_FILE_LEN 1024/g' "$FLEXRIC_DIR/src/util/conf_file.h"

echo
echo
echo "Installing Next Generation Node B (OpenAirInterface)..."
# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

echo "Ensuring that SCTP is enabled..."
sudo ./install_scripts/enable_sctp.sh

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

ADDITIONAL_FLAGS=""
if [ "$CLEAN_INSTALL" = true ]; then
    ADDITIONAL_FLAGS="-C"
fi
if [ "$DEBUG_SYMBOLS" = true ]; then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -g"
fi
if [ "$TELNET_SERVER" = true ]; then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --build-lib telnetsrv"
    # Install telnet client if not already installed
    if ! command -v telnet &>/dev/null; then
        echo "Installing telnet client..."
        sudo env $APTVARS apt-get install -y telnet
    fi
fi
if [ "$NRSCOPE_GUI" = true ]; then
    sudo env $APTVARS apt-get install -y libglfw3-dev libopengl-dev
    sudo env $APTVARS apt-get install -y libforms-bin libforms-dev
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --build-lib imscope"
fi

cd "$SCRIPT_DIR"

echo
echo

if [ "$RADIO_TYPE" = "ZMQ" ]; then
    echo "Building ZeroMQ libzmq..."
    if [ -d ../User_Equipment/libzmq ]; then
        if [ ! -L libzmq ]; then
            echo "Found UE library. Creating libzmq link instead."
            ln -s ../User_Equipment/libzmq libzmq
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
    if [ -d ../User_Equipment/czmq ]; then
        if [ ! -L czmq ]; then
            echo "Found UE library. Creating czmq link instead."
            ln -s ../User_Equipment/czmq czmq
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

echo "Compiling and Installing OpenAirInterface gNB..."

cd "$SCRIPT_DIR/openairinterface5g"
source oaienv

# Install OAI dependencies
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
./build_oai -I

# Build OAI 5G gNB
cd "$SCRIPT_DIR/openairinterface5g/cmake_targets"
if [ "$RADIO_TYPE" = "SIMU" ] || [ "$RADIO_TYPE" = "ZMQ" ]; then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -w $RADIO_TYPE"
else
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -w USRP"
fi
./build_oai --ninja --gNB --build-e2 $ADDITIONAL_FLAGS

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

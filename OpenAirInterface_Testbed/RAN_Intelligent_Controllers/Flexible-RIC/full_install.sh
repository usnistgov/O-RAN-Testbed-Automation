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

# FLEXRIC_LIBRARY_DIR="/usr/local/lib/flexric/" # Default
FLEXRIC_LIBRARY_DIR="flexric/build/flexric_libraries/lib/flexric/"

APPLY_PATCHES=true
CLEAN_INSTALL=false
DEBUG_SYMBOLS=false
E2AP_VERSION="E2AP_V3"        # E2AP_V1, E2AP_V2, E2AP_V3
KPM_VERSION="KPM_V3_00"       # KPM_V2_03, KPM_V3_00
E2_TERM_PORT=36421            # Ensure this matches the gNodeB's full_install.sh E2_TERM_PORT. Default is 36421, which will result in no modification
E2_TERM_PORT_SUBSTITUTE=36423 # If E2_TERM_PORT is used already, substitute it before replacing with E2_TERM_PORT
APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Check for binary to determine if FlexRIC is already installed
if [ "$CLEAN_INSTALL" != "true" ] && [ -f "flexric/build/examples/ric/nearRT-RIC" ] && [ -d "$FLEXRIC_LIBRARY_DIR" ]; then
    echo "FlexRIC is already installed, skipping."
    exit 0
fi
# Remove the build directory if it exists and CLEAN_INSTALL is true
if [ "$CLEAN_INSTALL" = "true" ] && [ -d "flexric/build" ]; then
    rm -rf flexric/build
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh
trap './install_scripts/stop_sudo_refresh.sh 2>/dev/null || true' EXIT

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

echo "Installing dependencies..."
sudo env $APTVARS apt-get install -y build-essential automake autoconf libtool bison flex
sudo env $APTVARS apt-get install -y libsctp-dev python3 cmake-curses-gui libpcre2-dev python3-dev

UBUNTU_CODENAME=$(./install_scripts/get_ubuntu_codename.sh)

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
    if ! curl -fsSL --connect-timeout 10 "https://ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu/dists/${UBUNTU_CODENAME}/Release" >/dev/null; then
        echo "ERROR: Cannot reach the Ubuntu Toolchain PPA package repository."
        exit 1
    fi
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update
    sudo env $APTVARS apt-get install -y gcc-13 g++-13
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
fi
export CFLAGS="-Wno-error=incompatible-pointer-types"
export CXXFLAGS="-Wno-error=incompatible-pointer-types"

if ! command -v cmake &>/dev/null; then
    echo "Installing CMake..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y cmake
fi
CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
if [[ "$CMAKE_VERSION" == 3.16.* ]]; then
    echo "Detected CMake $CMAKE_VERSION. Updating CMake for FlexRIC compatibility..."
    # Add Kitware's apt repository
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo apt-key add -
    sudo apt-add-repository -y "deb https://apt.kitware.com/ubuntu/ $UBUNTU_CODENAME main"
    sudo apt-get update
    sudo env $APTVARS apt-get install -y cmake
fi

if [ ! -d "swig" ]; then
    echo "Cloning SWIG..."
    ./install_scripts/git_clone.sh https://github.com/swig/swig.git
fi

if ! command -v swig &>/dev/null; then
    echo "Building SWIG..."
    cd swig
    ./autogen.sh
    ./configure --prefix=/usr/
    make -j$(nproc)

    echo "Installing SWIG..."
    sudo make install
    cd ..
else
    echo "SWIG is already installed, skipping."
fi

cd "$SCRIPT_DIR"

if [ ! -d "flexric" ]; then
    echo "Cloning Flexible RAN Intelligent Controller (FlexRIC)..."
    ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/mosaic5g/flexric.git --https
fi

CURRENT_E2_PORT=$(sed -nE 's/.*e2ap_server_port *= *([0-9]+);/\1/p' flexric/src/agent/e2_agent_api.c)
if [ -z "$CURRENT_E2_PORT" ]; then
    echo "ERROR: e2ap_server_port not found in flexric/src/agent/e2_agent_api.c"
    exit 1
fi
# Check if the substitute port is already in use
if sudo find flexric/ -type f -exec grep -l -w "$E2_TERM_PORT_SUBSTITUTE" {} + | grep -q .; then
    echo "ERROR: The E2 Termination Port Substitute ($E2_TERM_PORT_SUBSTITUTE) is already in use in the following files. Please choose a different substitute port."
    sudo find flexric/ -type f -exec grep -l -w "$E2_TERM_PORT_SUBSTITUTE" {} +
    exit 1
fi
# Configure the E2 termination port
if [ "$E2_TERM_PORT" != "$CURRENT_E2_PORT" ]; then
    sudo find flexric/ -type f -exec sed -i "s/$CURRENT_E2_PORT/$E2_TERM_PORT_SUBSTITUTE/g" {} + # Change current port to substitute
    sudo find flexric/ -type f -exec sed -i "s/$E2_TERM_PORT_SUBSTITUTE/$E2_TERM_PORT/g" {} +    # Change substitute to specified port
    echo "Configured E2 termination from port $CURRENT_E2_PORT to port $E2_TERM_PORT"
fi

if [ "$APPLY_PATCHES" = true ]; then
    echo "Patching FlexRIC..."
    ./install_scripts/apply_patches.sh
fi

# Use Duranta OpenAirInterface build_helper if asn1c is not found
ASN1C_EXEC_PATH="/opt/asn1c/bin/asn1c"
if [ ! -x "$ASN1C_EXEC_PATH" ]; then
    PARENT_DIR=$(dirname "$SCRIPT_DIR")
    BASE_DIR=$(dirname "$PARENT_DIR")
    cd "$BASE_DIR/User_Equipment"
    if [ ! -d "openairinterface5g" ]; then
        echo "Cloning Duranta OpenAirInterface repository for asn1c installer ($BASE_DIR/User_Equipment/openairinterface5g)..."
        ./install_scripts/git_clone.sh https://github.com/duranta-project/openairinterface5g.git openairinterface5g
        APPLY_DURANTA_PATCHES=true
        if [ "$APPLY_DURANTA_PATCHES" = true ]; then
            echo "Patching Duranta UE..."
            ./install_scripts/apply_patches.sh
        fi
    fi
    # Install OAI dependencies
    cd openairinterface5g/cmake_targets
    ./build_oai -I
    if [ ! -x "$ASN1C_EXEC_PATH" ]; then
        echo "ERROR: Duranta did not install asn1c at $ASN1C_EXEC_PATH."
        exit 1
    fi
    cd "$SCRIPT_DIR"
    echo "Successfully installed dependencies required to build FlexRIC."
    echo
fi
if ! "$ASN1C_EXEC_PATH" -h 2>&1 | grep -q -- "-gen-UPER"; then
    echo "ERROR: $ASN1C_EXEC_PATH does not support -gen-UPER."
    exit 1
fi

ADDITIONAL_FLAGS="-DCMAKE_BUILD_TYPE=Release"
if [ "$DEBUG_SYMBOLS" = true ]; then
    ADDITIONAL_FLAGS="-DCMAKE_BUILD_TYPE=Debug"
fi

echo "Building FlexRIC..."
cd flexric
sudo rm -rf build
mkdir build
cd build
# Strip /lib/flexric* to derive install prefix
PREFIX_DIR="${FLEXRIC_LIBRARY_DIR%/lib/flexric*}"
if [[ "$PREFIX_DIR" != /* ]]; then
    PREFIX_DIR="$SCRIPT_DIR/$PREFIX_DIR"
fi
CC=gcc CXX=g++ cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR" -DASN1C_EXEC="$ASN1C_EXEC_PATH" -DASN1C_EXEC_PATH="$ASN1C_EXEC_PATH" -DXAPP_DB=NONE_XAPP -DE2AP_VERSION="$E2AP_VERSION" -DKPM_VERSION="$KPM_VERSION" $ADDITIONAL_FLAGS
make -j$(nproc)

echo "Installing FlexRIC..."
make install

#ctest -j8 --output-on-failure

cd "$SCRIPT_DIR"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
    DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
    echo "The FlexRIC installation process took $DURATION_MINUTES minutes to complete."
    mkdir -p logs
    echo "$DURATION_MINUTES minutes" >>install_time.txt
fi

echo "The FlexRIC installation completed successfully."

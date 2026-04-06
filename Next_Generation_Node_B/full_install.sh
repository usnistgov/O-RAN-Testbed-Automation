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
DEBUG_SYMBOLS=false
RUN_TESTS=false
TUNE_PERFORMANCE=false

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Check for binary to determine if OCUDU is already installed
if [ -f "ocudu/build/apps/gnb/gnb" ]; then
    echo "OCUDU is already installed, skipping."
    exit 0
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

sudo rm -rf logs/

# Detect if systemctl is available
USE_SYSTEMCTL=false
if command -v systemctl >/dev/null 2>&1; then
    if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        OUTPUT="$(systemctl 2>&1 || true)"
        if echo "$OUTPUT" | grep -qiE 'not supported|System has not been booted with systemd'; then
            echo "Detected systemctl is not supported. Using background processes instead."
        elif systemctl list-units >/dev/null 2>&1 || systemctl is-system-running --quiet >/dev/null 2>&1; then
            USE_SYSTEMCTL=true
        fi
    fi
fi

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if [[ "$USE_SYSTEMCTL" == "true" ]]; then
    if systemctl is-active --quiet unattended-upgrades; then
        sudo systemctl stop unattended-upgrades &>/dev/null && echo "Successfully stopped unattended-upgrades service."
        sudo systemctl disable unattended-upgrades &>/dev/null && echo "Successfully disabled unattended-upgrades service."
    fi
    if systemctl is-active --quiet apt-daily.timer; then
        sudo systemctl stop apt-daily.timer &>/dev/null && echo "Successfully stopped apt-daily.timer service."
        sudo systemctl disable apt-daily.timer &>/dev/null && echo "Successfully disabled apt-daily.timer service."
    fi
    if systemctl is-active --quiet apt-daily-upgrade.timer; then
        sudo systemctl stop apt-daily-upgrade.timer &>/dev/null && echo "Successfully stopped apt-daily-upgrade.timer service."
        sudo systemctl disable apt-daily-upgrade.timer &>/dev/null && echo "Successfully disabled apt-daily-upgrade.timer service."
    fi
fi

if [ ! -d "ocudu" ]; then
    echo "Cloning OCUDU..."
    ./install_scripts/git_clone.sh https://gitlab.com/ocudu/ocudu.git
fi

if [ "$APPLY_PATCHES" = true ]; then
    echo "Patching OCUDU..."
    ./install_scripts/apply_patches.sh
fi

echo "Updating package lists..."
if ! sudo apt-get update; then
    sudo "$SCRIPT_DIR/install_scripts/./remove_expired_apt_keys.sh"
    echo "Trying to update package lists again..."
    if ! sudo apt-get update; then
        echo "Failed to update package lists"
        exit 1
    fi
fi

echo
echo
echo "Installing Next Generation Node B (OCUDU)..."
# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

# Code from (https://gitlab.com/ocudu/ocudu):
MIN_GCC_VERSION="11.4.0"
if command -v gcc >/dev/null 2>&1; then
    GCC_VERSION=$(gcc -dumpfullversion -dumpversion)
    if dpkg --compare-versions "$GCC_VERSION" lt "$MIN_GCC_VERSION"; then
        echo "Detected GCC $GCC_VERSION, which is below required $MIN_GCC_VERSION. Removing gcc/g++ before reinstalling."
        sudo env $APTVARS apt-get remove -y gcc g++
    fi
fi

# Code from (https://gitlab.com/ocudu/ocudu):
sudo env $APTVARS apt-get install -y cmake make gcc g++ pkg-config libmbedtls-dev libsctp-dev libyaml-cpp-dev libtool
if [[ "$RUN_TESTS" == "true" ]]; then
    sudo env $APTVARS apt-get install -y libgtest-dev
fi
sudo apt-get install -y libfftw3-dev

sudo env $APTVARS apt-get install -y ccache

echo "Ensuring that SCTP is enabled..."
sudo ./install_scripts/enable_sctp.sh

cd "$SCRIPT_DIR"

echo
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

if [ ! -f "zmq_broker/multi_ue_scenario.py" ]; then
    if ! command -v grcc >/dev/null 2>&1; then
        echo "Installing GNU Radio Companion Compiler (grcc) for the ZeroMQ Broker..."
        sudo env $APTVARS apt-get install -y gnuradio
    fi
fi

echo
echo
if [ ! -d "zmq_broker" ] || [ ! -f "zmq_broker/multi_ue_scenario.grc" ]; then
    echo "Downloading ZeroMQ Broker GNU Radio Companion flowgraph..."
    mkdir -p zmq_broker
    wget -qO zmq_broker/multi_ue_scenario.grc https://gitlab.com/ocudu/ocudu_docs/-/raw/main/docs/user_manual/tutorials/srsue/assets/multi_ue_scenario.grc
fi

echo
echo
echo "Compiling and Installing OCUDU..."
cd ocudu
mkdir -p build
cd build
CMAKE_FLAGS="-DENABLE_WERROR=OFF"
if [[ "$DEBUG_SYMBOLS" == "true" ]]; then
    CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Debug"
fi

if [[ "$RUN_TESTS" == "true" ]]; then
    CMAKE_FLAGS="$CMAKE_FLAGS -DBUILD_TESTING=ON"
else
    CMAKE_FLAGS="$CMAKE_FLAGS -DBUILD_TESTING=OFF"
fi

cmake ../ $CMAKE_FLAGS
make -j$(nproc)
if [[ "$RUN_TESTS" == "true" ]]; then
    ctest -j$(nproc)
fi
sudo make install

cd "$SCRIPT_DIR"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
    DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
    echo "The gNodeB installation process took $DURATION_MINUTES minutes to complete."
    mkdir -p logs
    echo "$DURATION_MINUTES minutes" >>install_time.txt
fi

if [[ "$TUNE_PERFORMANCE" == "true" ]]; then
    echo
    echo
    echo "Tuning OCUDU performance..."
    cd ocudu
    sudo ./scripts/ocudu_performance
    cd ..
fi

echo "The gNodeB installation completed successfully."

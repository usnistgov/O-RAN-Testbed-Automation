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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Check for gnb binary to determine if srsRAN_Project is already installed
if [ -f "srsRAN_Project/build/apps/gnb/gnb" ]; then
    echo "srsRAN_Project is already installed, skipping."
    exit 0
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

sudo rm -rf logs/

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
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

if [ ! -d "srsRAN_Project" ]; then
    echo "Cloning srsRAN_Project..."
    git clone https://github.com/srsran/srsRAN_Project.git
fi

echo
echo
echo "Installing gNodeB..."

sudo apt-get update
sudo apt-get install -y build-essential autoconf automake libtool libboost-program-options-dev libconfig++-dev
sudo apt-get install -y cmake make gcc g++ pkg-config libgtest-dev
sudo apt-get install -y libuhd-dev
sudo apt-get install -y uhd-host
sudo apt-get install -y libdw-dev libbfd-dev libdwarf-dev
sudo apt-get install -y libgtest-dev
sudo apt-get install -y libmbedtls-dev
sudo apt-get install -y libfftw3-dev
sudo apt-get install -y libyaml-cpp-dev
sudo apt-get install -y timelimit

# Enable SCTP
sudo apt-get install -y libsctp-dev
# Check if SCTP is available and load it if necessary
if ! lsmod | grep -q sctp; then
    echo "Loading SCTP module..."
    sudo modprobe sctp
fi
# Verify if SCTP is successfully loaded
if ! lsmod | grep -q sctp; then
    echo "SCTP module could not be loaded. Exiting."
    exit 1
else
    echo "SCTP module loaded successfully."
fi

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
        git clone https://github.com/zeromq/libzmq.git
    fi
    cd libzmq
    ./autogen.sh
    ./configure
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd ..
fi

cd "$SCRIPT_DIR"

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
        git clone https://github.com/zeromq/czmq.git
    fi
    cd czmq
    ./autogen.sh
    ./configure
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd ..
fi

# Verify ZeroMQ installation
if ! pkg-config --exists libzmq; then
    echo "ZeroMQ was not installed correctly. Exiting."
    exit 1
else
    echo "ZeroMQ installed successfully."
fi

cd "$SCRIPT_DIR"

echo
echo
echo "Compiling and Installing srsRAN_Project..."
cd srsRAN_Project
# rm -rf build
mkdir -p build
cd build
SUPPRESS_WARNINGS="-Wno-error=array-bounds -Wno-error=unused-but-set-variable -Wno-error=unused-function -Wno-error=unused-parameter -Wno-error=unused-result -Wno-error=unused-variable -Wno-error=all"
cmake .. -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON -DCMAKE_CXX_FLAGS="$SUPPRESS_WARNINGS"
make clean
# Remove -Werror from the flags.make files to prevent the build from failing due to warnings
make -j$(nproc)
# sudo make test -j$(nproc)
sudo make -j$(nproc) install

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

echo "The gNodeB installation completed successfully."

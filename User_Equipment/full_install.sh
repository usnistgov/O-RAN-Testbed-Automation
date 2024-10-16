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

if [ -f "srsRAN_4G/build/srsue/src/srsue" ]; then
    echo "srsRAN_4G is already installed. Skipping."
    exit 0
fi

if ! command -v realpath &> /dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

# Starts a script in background that calls `sudo -v` every minute to ensure that sudo stays active, ensuring the script runs without requiring user interaction
sudo ls
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

BASE_DIR=$(pwd)

echo "Installing User Equipment..."

sudo apt-get update

sudo apt-get install libuhd-dev -y
sudo apt-get install uhd-host -y
sudo apt-get install libdw-dev libbfd-dev libdwarf-dev -y
sudo apt-get install libgtest-dev -y
sudo apt-get install libmbedtls-dev -y
sudo apt-get install libfftw3-dev -y
sudo apt-get install libyaml-cpp-dev -y

sudo apt-get install build-essential cmake libtool libfftw3-dev libmbedtls-dev libboost-program-options-dev libconfig++-dev libsctp-dev -y
sudo apt-get install libfftw3-dev libmbedtls-dev -y

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

cd $BASE_DIR

echo
echo
echo "Building ZeroMQ libzmq..."
# if ! sudo apt-get install -y libzmq3; then
#     sudo apt-get install -y libzmq3-dev
# fi
# rm -rf libzmq
if [ -d ../gNodeB/libzmq ]; then
    if [ ! -L libzmq ]; then
        echo "Found gNodeB library. Creating libqmz link instead."
        ln -s ../gNodeB/libzmq libzmq
    else
        echo "Link to libqmz already created."
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

cd $BASE_DIR

echo
echo
echo "Building ZeroMQ czmq..."
#rm -rf czmq
if [ -d ../gNodeB/czmq ]; then
    if [ ! -L czmq ]; then
        echo "Found gNodeB library. Creating czmq link instead."
        ln -s ../gNodeB/czmq czmq
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

cd $BASE_DIR

echo
echo
echo "Compiling and Installing srsRAN..."
if [ ! -d "srsRAN_4G" ]; then
    echo "Cloning srsRAN_4G..."
    git clone https://github.com/srsran/srsRAN_4G.git
fi
cd srsRAN_4G
echo
echo
echo "Building srsRAN..."
# rm -rf build
mkdir -p build
cd build
#cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS="-Wno-error=array-bounds" ../ # Enable debugging info
cmake .. -DCMAKE_CXX_FLAGS="-Wno-error=array-bounds"

make clean
make -j$(nproc)
sudo make -j$(nproc) install
echo "srsRAN_4G was installed successfully."

cd $BASE_DIR

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
  DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
  DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
  echo "The srsUE installation process took $DURATION_MINUTES minutes to complete."
  mkdir -p logs
  echo "$DURATION_MINUTES minutes" >> install_time.txt
fi

echo "The User Equipment installation completed successfully."

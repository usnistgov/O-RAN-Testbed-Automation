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
if [ -f "flexric/build/examples/ric/nearRT-RIC" ]; then
    echo "FlexRIC is already installed, skipping."
    exit 0
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

echo "Installing dependencies..."
sudo apt-get update || true
sudo apt-get install -y build-essential automake
sudo apt-get install -y gcc-10 g++-10
sudo apt-get install -y libsctp-dev python3 cmake-curses-gui libpcre2-dev python3-dev

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
    ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/mosaic5g/flexric.git
fi

# Apply patch to FlexRIC to add support for RSRP in the KPI report
if [ ! -f "flexric/examples/xApp/c/monitor/xapp_kpm_moni.c.previous" ]; then
    cp flexric/examples/xApp/c/monitor/xapp_kpm_moni.c flexric/examples/xApp/c/monitor/xapp_kpm_moni.c.previous
    echo
    echo "Patching xapp_kpm_moni.c..."
    cd flexric
    git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni.c.patch"
    cd ..
fi

echo "Building FlexRIC..."
cd flexric
sudo rm -rf build
mkdir build
cd build
CC=gcc-10 CXX=g++-10 cmake .. -DE2AP_VERSION=E2AP_V3 -DKPM_VERSION=KPM_V3_00
make -j$(nproc)

echo "Installing FlexRIC..."
sudo make install

#ctest -j8 --output-on-failure

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

echo "The FlexRIC installation completed successfully."

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

if [ ! -d "srsRAN_Project" ]; then
    echo "Cloning srsRAN_Project..."
    ./install_scripts/git_clone.sh https://github.com/srsran/srsRAN_Project.git
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
echo "Installing Next Generation Node B (srsRAN Project)..."
# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

# Code from (https://docs.srsran.com/projects/project/en/latest/user_manuals/source/installation.html#manual-installation-dependencies):
sudo env $APTVARS apt-get install -y build-essential cmake cmake-data make gcc g++ pkg-config libfftw3-dev libmbedtls-dev libsctp-dev libyaml-cpp-dev libgtest-dev

sudo env $APTVARS apt-get install -y autoconf automake libtool
sudo env $APTVARS apt-get install -y libuhd-dev
sudo env $APTVARS apt-get install -y uhd-host
sudo env $APTVARS apt-get install -y libdw-dev libbfd-dev libdwarf-dev
sudo env $APTVARS apt-get install -y libgtest-dev
sudo env $APTVARS apt-get install -y libyaml-cpp-dev
sudo env $APTVARS apt-get install -y timelimit

echo "Ensuring that SCTP is enabled..."
sudo ./install_scripts/enable_sctp.sh

# Check if GCC 13 is installed, if not, install it and set it as the default
GCC_VERSION=$(gcc -v 2>&1 | grep "gcc version" | awk '{print $3}')
if [[ -z "$GCC_VERSION" || ! "$GCC_VERSION" == 13.* ]]; then
    echo "Installing GCC 13..."
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update
    sudo env $APTVARS apt-get install -y gcc-13 g++-13
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
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
        ./install_scripts/git_clone.sh https://github.com/zeromq/libzmq.git
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
        ./install_scripts/git_clone.sh https://github.com/zeromq/czmq.git
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
SUPPRESS_WARNINGS="-Wno-error=array-bounds -Wno-error=unused-but-set-variable -Wno-error=unused-function -Wno-error=unused-parameter -Wno-error=unused-result -Wno-error=unused-variable -Wno-error=all -Wno-return-type"
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

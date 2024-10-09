#!/bin/bash

# Exit immediately if a command fails
set -e

if [ -f "srsRAN_Project/build/apps/gnb/gnb" ]; then
    echo "srsRAN_Project is already installed. Skipping."
    exit 0
fi

# Starts a script in background that calls `sudo -v` every minute to ensure that sudo stays active, ensuring the script runs without requiring user interaction
sudo ls
./install_scripts/start_sudo_refresh.sh 

# Get the start timestamp in seconds
gnb_start_time=$(date +%s)


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

baseDirectory=$(pwd)

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

cd $baseDirectory

echo
echo
echo "Building ZeroMQ libzmq..."
# if ! sudo apt-get install -y libzmq3; then
#     sudo apt-get install -y libzmq3-dev
# fi
#rm -rf libzmq
if [ ! -d libzmq ]; then
	git clone https://github.com/zeromq/libzmq.git
fi
cd libzmq
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig

cd $baseDirectory

echo
echo
echo "Building ZeroMQ czmq..."
#rm -rf czmq
if [ ! -d czmq ]; then
	git clone https://github.com/zeromq/czmq.git
fi
cd czmq
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify ZeroMQ installation
if ! pkg-config --exists libzmq; then
    echo "ZeroMQ was not installed correctly. Exiting."
    exit 1
else
    echo "ZeroMQ installed successfully."
fi

cd $baseDirectory

echo "Compiling and Installing srsRAN..."
cd srsRAN_Project
# rm -rf build
mkdir -p build
cd build
#cmake .. -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo ../ # Enable debugging info
cmake .. -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON
make clean
make -j$(nproc)
#sudo make test -j$(nproc)
sudo make -j$(nproc) install

cd $baseDirectory

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh 

# Calculate how long the script took to run
gnb_end_time=$(date +%s)
if [ -n "$gnb_start_time" ]; then
  duration=$((gnb_end_time - gnb_start_time))
  duration_minutes=$(echo "scale=5; $duration / 60" | bc)
  echo "The gNodeB installation process took $duration_minutes minutes to complete."
  echo "$duration_minutes minutes" > install_time.txt
fi

echo "The gNodeB installation completed successfully."

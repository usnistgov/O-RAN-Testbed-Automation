#!/bin/bash

# Starts a script in background that calls `sudo -v` every minute to ensure that sudo stays active, ensuring the script runs without requiring user interaction
sudo ls
./install_scripts/start_sudo_refresh.sh 

# Get the start timestamp in seconds
gnb_start_time=$(date +%s)

# Exit immediately if a command fails
set -e

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if sudo systemctl stop unattended-upgrades; then
  echo "Successfully stopped unattended-upgrades service."
fi
if sudo systemctl disable unattended-upgrades; then
  echo "Successfully disabled unattended-upgrades service."
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
  echo "The gNodeB installation process took $duration seconds to complete."
  echo "$duration seconds" > installation_time.txt
fi

echo "The gNodeB installation completed successfully."

#!/bin/bash

# Starts a script in background that calls `sudo -v` every minute to ensure that sudo stays active, ensuring the script runs without requiring user interaction
sudo ls
./install_scripts/start_sudo_refresh.sh 

# Get the start timestamp in seconds
ue_start_time=$(date +%s)

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

cd $baseDirectory

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

cd $baseDirectory

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

cd $baseDirectory

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

cd $baseDirectory

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh 

# Calculate how long the script took to run
ue_end_time=$(date +%s)
if [ -n "$ue_start_time" ]; then
  duration=$((ue_end_time - ue_start_time))
  echo "The User Equipment installation process took $duration seconds to complete."
  echo "$duration seconds" > installation_time.txt
fi

echo "The User Equipment installation completed successfully."

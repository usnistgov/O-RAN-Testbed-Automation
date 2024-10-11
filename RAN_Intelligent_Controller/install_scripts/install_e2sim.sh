#!/bin/bash
echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

if [ ! -f "full_install.sh" ]; then
    echo "You must run this script from the main directory with full_install.sh"
    exit 1
fi

# Set docker to use Google's DNS servers, then restart docker
sudo ./install_scripts/update_docker_dns.sh

sudo apt-get install -y cmake g++ libsctp-dev
DOCKER_FILE_PATH="e2-interface/e2sim/Dockerfile_kpm_MODIFIED"
cp e2-interface/e2sim/Dockerfile_kpm $DOCKER_FILE_PATH
sudo ./install_scripts/revise_e2sim_dockerfile.sh $DOCKER_FILE_PATH
cd e2-interface/e2sim/

mkdir -p build
cd build/
cmake .. && make package && cmake .. -DDEV_PKG=1 && make package
cp *.deb ../e2sm_examples/kpm_e2sm/
cd ../
sudo docker build -t oransim:0.0.999 . -f Dockerfile_kpm_MODIFIED

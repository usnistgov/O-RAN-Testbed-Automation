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

echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"

# Set the RAN Function ID if not set
if [ -z "$RAN_FUNC_ID" ]; then
    export RAN_FUNC_ID="2"
fi

# Set docker's DNS server then restart docker
sudo ./install_scripts/update_docker_dns.sh

sudo apt-get install -y cmake g++ libsctp-dev
DOCKER_FILE_PATH="e2-interface/e2sim/Dockerfile_kpm_updated"
cp e2-interface/e2sim/Dockerfile_kpm $DOCKER_FILE_PATH
sudo ./install_scripts/revise_e2sim_dockerfile.sh $DOCKER_FILE_PATH

# Patch the E2 simulator with source code developed by Abdul Fikih Kurnia in https://hackmd.io/@abdfikih/BkIeoH9D0
cp install_patch_files/e2-interface/e2sim/src/messagerouting/e2ap_message_handler.cpp e2-interface/e2sim/src/messagerouting/
cp install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/reports.json e2-interface/e2sim/e2sm_examples/kpm_e2sm/
cp install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.cpp e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/
cp install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.cpp e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/

cd e2-interface/e2sim/

mkdir -p build
cd build/
cmake .. && make -j$(nproc) package && cmake .. -DDEV_PKG=1 && make -j$(nproc) package
cp *.deb ../e2sm_examples/kpm_e2sm/
cd ../
sudo docker build -t oransim:0.0.999 . -f Dockerfile_kpm_updated
if [ $? -ne 0 ]; then
    echo "Error: Docker build failed. Cleaning up the E2 simulator..."
    sudo rm -rf e2-interface
    echo
    echo "Please try installing the E2 simulator again."
    exit 1
fi

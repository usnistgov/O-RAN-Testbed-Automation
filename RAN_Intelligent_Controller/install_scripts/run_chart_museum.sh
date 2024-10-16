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

# Function to check if a specific port is already used
function is_port_in_use {
    local port=$1
    if ss -tulpn | grep -q ":${port} "; then
        return 0 # Port is in use
    else
        return 1 # Port is not in use
    fi
}

# Container settings
PORT=8090
CONTAINER_NAME="chartmuseum"
IMAGE="chartmuseum/chartmuseum:latest"
STORAGE_DIR="$(pwd)/charts"

# Check if the container is already running
if [ $(docker ps -q -f name=^/${CONTAINER_NAME}$ | wc -l) -eq 1 ]; then
    echo "Container '${CONTAINER_NAME}' is already running."
elif [ $(docker ps -aq -f name=^/${CONTAINER_NAME}$ | wc -l) -eq 1 ]; then
    echo "Container '${CONTAINER_NAME}' exists but is not running, starting container..."
    docker start ${CONTAINER_NAME}
else
    # Check if the port is already in use
    if is_port_in_use $PORT; then
        echo "Port ${PORT} is already in use, chartmuseum is already running."
    else
        echo "Starting container '${CONTAINER_NAME}'..."
        docker run --rm -u 0 -it -d -p ${PORT}:8080 \
            -e DEBUG=1 \
            -e STORAGE=local \
            -e STORAGE_LOCAL_ROOTDIR=/charts \
            -v ${STORAGE_DIR}:/charts ${IMAGE}
    fi
fi

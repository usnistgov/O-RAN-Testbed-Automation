#!/bin/bash

set -e

# Function to check if a specific port is already used
function is_port_in_use {
    local port=$1
    # Check for listening services on the port
    if ss -tulpn | grep -q ":${port} "; then
        return 0  # Port is in use
    else
        return 1  # Port is not in use
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

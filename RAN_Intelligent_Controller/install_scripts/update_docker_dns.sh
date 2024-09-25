#!/bin/bash

set -e

# Set DNS servers
DNS_SERVERS='["8.8.8.8", "8.8.4.4"]'

# Docker daemon configuration file
DOCKER_CONFIG="/etc/docker/daemon.json"

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Check if Docker daemon configuration file exists
if [ -f "$DOCKER_CONFIG" ]; then
    # Check if DNS settings are already configured
    if grep -q '"dns"' $DOCKER_CONFIG; then
        # DNS settings exist, update them
        echo "Updating DNS settings in Docker configuration..."
        jq '.dns = $newVal' --argjson newVal "$DNS_SERVERS" $DOCKER_CONFIG > temp.json && mv temp.json $DOCKER_CONFIG
    else
        # DNS settings do not exist, add them
        echo "Adding DNS settings to Docker configuration..."
        jq '. + {"dns": $newVal}' --argjson newVal "$DNS_SERVERS" $DOCKER_CONFIG > temp.json && mv temp.json $DOCKER_CONFIG
    fi
else
    # Docker configuration file does not exist, create it with DNS settings
    echo "Creating Docker configuration file with DNS settings..."
    echo "{\"dns\": $DNS_SERVERS}" > $DOCKER_CONFIG
fi

# Restart Docker service to apply changes
echo "Restarting Docker service..."
systemctl restart docker

echo "Docker DNS configuration updated successfully."


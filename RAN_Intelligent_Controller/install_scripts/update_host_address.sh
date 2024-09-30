#!/bin/bash

# Exit immediately if a command fails
set -e

# Fetch the current IP address and hostname
IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
HOSTNAME=$(hostname)

# Check if the IP address and hostname are not empty
if [ -z "$IP_ADDRESS" ] || [ -z "$HOSTNAME" ]; then
    echo "Error: IP address or hostname is empty. Exiting script."
    exit 1
fi

# Remove existing entries for the hostname from /etc/hosts
sudo sed -i "/$HOSTNAME/d" /etc/hosts

# Add the new entry to /etc/hosts
echo "$IP_ADDRESS $HOSTNAME" | sudo tee -a /etc/hosts

echo "Updated /etc/hosts with: $IP_ADDRESS $HOSTNAME"

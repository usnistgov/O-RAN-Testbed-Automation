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

echo "# Script: $(realpath "$0")..."

# Exit immediately if a command fails
set -e

# Set DNS servers
DNS_SERVERS=$(grep 'nameserver' /run/systemd/resolve/resolv.conf | awk '{print $2}' | jq -R . | jq -s .)

if [ -z "$(echo $DNS_SERVERS | jq '. | select(length > 0)')" ]; then
    echo "Could not find DNS servers in /run/systemd/resolve/resolv.conf, defaulting Google DNS..."
    DNS_SERVERS='["8.8.8.8", "8.8.4.4"]'
fi

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
        jq '.dns = $NEW_VALUE' --argjson NEW_VALUE "$DNS_SERVERS" $DOCKER_CONFIG >temp.json && mv temp.json $DOCKER_CONFIG
    else
        # DNS settings do not exist, add them
        echo "Adding DNS settings to Docker configuration..."
        jq '. + {"dns": $NEW_VALUE}' --argjson NEW_VALUE "$DNS_SERVERS" $DOCKER_CONFIG >temp.json && mv temp.json $DOCKER_CONFIG
    fi
else
    # Docker configuration file does not exist, create it with DNS settings
    echo "Creating Docker configuration file with DNS settings..."
    echo "{\"dns\": $DNS_SERVERS}" >$DOCKER_CONFIG
fi

# Restart Docker service to apply changes
echo "Restarting Docker service..."
systemctl restart docker

echo "Docker DNS configuration updated successfully."

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

# Set DNS servers for Docker daemon
DNS_SERVERS=$(grep 'nameserver' /run/systemd/resolve/resolv.conf 2>/dev/null | awk '{print $2}' | jq -R . | jq -s . 2>/dev/null || echo '[]')
if [ -z "$(echo "$DNS_SERVERS" | jq '. | select(length > 0)')" ]; then
    echo "Could not find DNS servers in /run/systemd/resolve/resolv.conf, trying /etc/resolv.conf..."
    DNS_SERVERS=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | jq -R . | jq -s . 2>/dev/null || echo '[]')
fi
if [ -z "$(echo "$DNS_SERVERS" | jq '. | select(length > 0)')" ]; then
    echo "Could not find DNS servers in system resolv.conf files, defaulting to Google DNS..."
    DNS_SERVERS='["8.8.8.8", "8.8.4.4"]'
fi
echo "Using DNS servers: $DNS_SERVERS"

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

# Detect if systemctl is available
USE_SYSTEMCTL=false
if command -v systemctl >/dev/null 2>&1; then
    if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        OUTPUT="$(systemctl 2>&1 || true)"
        if echo "$OUTPUT" | grep -qiE 'not supported|System has not been booted with systemd'; then
            echo "Detected systemctl is not supported. Using background processes instead."
        elif systemctl list-units >/dev/null 2>&1 || systemctl is-system-running --quiet >/dev/null 2>&1; then
            USE_SYSTEMCTL=true
        fi
    fi
fi

# Restart Docker service to apply changes
if [ "$USE_SYSTEMCTL" = true ]; then
    systemctl restart docker
else
    echo "Restarting Docker process..."
    if ! command -v dockerd >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
        echo "ERROR: Docker binaries not found in PATH."
        exit 1
    fi
    DOCKERD_LOG="/tmp/dockerd.log"
    # Stop running dockerd and containerd in background
    sudo pkill -x dockerd >/dev/null 2>&1 || true
    sudo pkill -x containerd >/dev/null 2>&1 || true
    sudo rm -f /var/run/docker.pid /var/run/docker.sock
    sudo mkdir -p /run /var/run
    sudo sh -c 'setsid dockerd --config-file=/etc/docker/daemon.json >>'"${DOCKERD_LOG}"' 2>&1 </dev/null &'
    for _ in $(seq 1 60); do
        if sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    if ! (sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1); then
        echo "Docker failed to start with configured options. Retrying with cgroupfs driver..."
        sudo pkill -x dockerd >/dev/null 2>&1 || true
        # Update daemon.json temporarily
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
        sudo sed -i 's/"native.cgroupdriver=systemd"/"native.cgroupdriver=cgroupfs"/' /etc/docker/daemon.json
        sudo sh -c 'setsid dockerd --config-file=/etc/docker/daemon.json >>'"${DOCKERD_LOG}"' 2>&1 </dev/null &'
        for _ in $(seq 1 60); do
            if sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        if ! (sudo test -S /var/run/docker.sock && sudo docker version >/dev/null 2>&1); then
            # Restore the original daemon.json
            sudo mv /etc/docker/daemon.json.bak /etc/docker/daemon.json 2>/dev/null || true
            echo "ERROR: Docker daemon failed to start without systemd."
            tail -n 200 "${DOCKERD_LOG}" 2>/dev/null || true
            exit 1
        fi
    fi
    echo "Docker started successfully."
fi

echo "Docker DNS configuration updated successfully."

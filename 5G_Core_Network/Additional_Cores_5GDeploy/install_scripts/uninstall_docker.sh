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

# Exit immediately if a command fails
set -e

# Echo every command as it is ran
set -x

SCRIPT_DIR=$(dirname "$(realpath "$0")")
BASE_DIR=$(realpath "$SCRIPT_DIR/../..")
cd "$SCRIPT_DIR"

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

echo
echo
echo "Stopping and removing existing Docker installations, then uninstalling Docker..."

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    if [ -n "$(docker ps -q 2>/dev/null)" ]; then # Graceful attempt first
        docker stop $(docker ps -q) || true
    fi
    if [ -n "$(docker ps -aq 2>/dev/null)" ]; then
        docker rm -f $(docker ps -aq) || true
    fi
    docker network prune -f || true
    docker volume prune -f || true
fi
if [ "$USE_SYSTEMCTL" = true ]; then
    if sudo systemctl is-active --quiet docker.socket; then
        sudo systemctl stop docker.socket
    fi
    if sudo systemctl is-active --quiet docker.service; then
        sudo systemctl stop docker.service
    fi
    if sudo systemctl is-active --quiet docker; then
        sudo systemctl stop docker
    fi
    if sudo systemctl is-active --quiet containerd.service; then
        sudo systemctl stop containerd.service
    fi
    if sudo systemctl is-enabled --quiet docker.socket; then
        sudo systemctl disable docker.socket
    fi
    if sudo systemctl is-enabled --quiet docker.service; then
        sudo systemctl disable docker.service
    fi
    if sudo systemctl is-enabled --quiet docker; then
        sudo systemctl disable docker
    fi
    if sudo systemctl is-enabled --quiet containerd.service; then
        sudo systemctl disable containerd.service
    fi
else
    if pgrep "dockerd" >/dev/null; then
        echo "Killing dockerd process..."
        sudo pkill -9 -f '^dockerd(\s|$)' 2>/dev/null || true
    fi
    if pgrep "containerd" >/dev/null; then
        echo "Killing containerd process..."
        sudo pkill -9 -f '^containerd(\s|$)' 2>/dev/null || true
    fi
    sudo pkill -9 -f 'containerd-shim' 2>/dev/null || true
    sudo pkill -9 -f 'docker-proxy' 2>/dev/null || true
    sudo pkill -9 -f 'runc' 2>/dev/null || true
    # If console breaks, reset it
    stty sane || true
fi

# Uninstall all possible Docker packages
sudo apt-get remove --purge -y --allow-change-held-packages \
    docker docker-engine docker-ce docker.io containerd runc \
    docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    docker-ce-rootless-extras docker-scan-plugin || true

# Unmount Docker and containerd mount points
echo "Unmounting Docker and containerd mount points..."
# Unmount all mount points under /var/lib/docker and /var/lib/containerd starting at deepest paths
sudo awk '$5 ~ /^\/var\/lib\/docker/ || $5 ~ /^\/var\/lib\/containerd/ {print $5}' /proc/self/mountinfo | sort -r | xargs -r -n1 sudo umount -l 2>/dev/null || true
# Unmount common overlay and shm paths
sudo umount -l /var/lib/docker/overlay2/*/merged 2>/dev/null || true
sudo umount -l /var/lib/docker/containers/*/mounts/shm 2>/dev/null || true
sudo umount -l /var/lib/containerd/*/*/*/rootfs 2>/dev/null || true

# Remove Docker directories
sudo rm -rf /var/lib/docker /etc/docker /home/docker

# Remove Docker group and user from group
if getent group docker >/dev/null; then
    sudo groupdel docker
fi
if id -nG "$(id -un)" | grep -qw docker; then
    sudo deluser "$(id -un)" docker
fi

# Remove Docker binaries if present
if [ -f /usr/bin/docker ]; then
    echo "Removing /usr/bin/docker..."
    sudo rm -f /usr/bin/docker
fi
if [ -f /usr/local/bin/docker ]; then
    echo "Removing /usr/local/bin/docker..."
    sudo rm -f /usr/local/bin/docker
fi

# Clean up
sudo apt-get autoremove --purge -y

# Reset the shell's command hash table to recognize changes in available executables
hash -r

echo "Successfully uninstalled Docker."

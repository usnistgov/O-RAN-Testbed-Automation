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

echo
echo
echo "Stopping and removing existing Docker installations, then uninstalling Docker..."

# Stop and disable Docker services and sockets
if sudo systemctl is-active --quiet docker.socket; then
    sudo systemctl stop docker.socket
fi
if sudo systemctl is-active --quiet docker.service; then
    sudo systemctl stop docker.service
fi
if sudo systemctl is-enabled --quiet docker.socket; then
    sudo systemctl disable docker.socket
fi
if sudo systemctl is-enabled --quiet docker.service; then
    sudo systemctl disable docker.service
fi
if sudo systemctl is-active --quiet docker; then
    sudo systemctl stop docker
fi
if sudo systemctl is-enabled --quiet docker; then
    sudo systemctl disable docker
fi

echo "Removing Docker and cleaning config..."

# Uninstall all possible Docker packages
sudo apt-get remove --purge -y --allow-change-held-packages \
    docker docker-engine docker-ce docker.io containerd runc \
    docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    docker-ce-rootless-extras docker-scan-plugin || true

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

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

set -e

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

usage() {
    echo "Usage: $0 [gnb|cu|cucp|cuup|du|ru]"
    echo "    Optionally specify the NETCONF configuration profile to load (default: gnb)"
    echo "    For more information, see https://gitlab.com/ocudu/ocudu_elements/ocudu_oran_apps/ocudu_netconf#run-netopeer2-server-as-standalone-container"
}

if [ "$#" -gt 1 ]; then
    usage
    exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

NETCONF_CONFIG_PROFILE="${1:-gnb}"

cd "$SCRIPT_DIR"

# Check if docker is accessible from the current user, and if not, repair its permissions
if [ -z "$FIXED_DOCKER_PERMS" ]; then
    if ! OUTPUT=$(docker info 2>&1); then
        if echo "$OUTPUT" | grep -qiE 'permission denied|cannot connect to the docker daemon'; then
            echo "Docker permissions will repair on reboot."
            sudo groupadd -f docker
            if [ -n "$SUDO_USER" ]; then
                sudo usermod -aG docker "${SUDO_USER:-root}"
            else
                sudo usermod -aG docker "${USER:-root}"
            fi
            # Rather than requiring a reboot to apply docker permissions, set the docker group and re-run the parent script
            export FIXED_DOCKER_PERMS=1
            if ! command -v sg &>/dev/null; then
                echo
                echo "WARNING: Could not find set group (sg) command, docker may fail without sudo until the system reboots."
                echo
            else
                exec sg docker -c "$(printf '%q ' "$CURRENT_DIR/$0" "$@")"
            fi
        fi
    fi
fi

cd "$PARENT_DIR"

if ! docker image inspect ocudu-netconf/ocudu-netconf:latest >/dev/null 2>&1; then
    echo "Docker image 'ocudu-netconf/ocudu-netconf:latest' not found. Please run ./install_o1_adapter.sh first."
    exit 1
fi

if [ ! -d "ocudu_o1_adapter" ]; then
    echo "Cannot find ocudu_o1_adapter directory. Please run ./install_o1_adapter.sh first."
    exit 1
fi

echo "Starting OCUDU Netconf with '$NETCONF_CONFIG_PROFILE' configuration profile..."

cd ocudu_netconf
if docker ps -q -f name=^/ocudu_netconf$ | grep -q .; then
    echo "ERROR: Docker container name 'ocudu_netconf' is already in use. Stop the existing container before starting the O1 adapter."
    exit 1
fi
if docker ps -aq -f name=^/ocudu_netconf$ | grep -q .; then
    echo "Removing stopped Docker container 'ocudu_netconf'..."
    docker rm ocudu_netconf >/dev/null
fi
if ss -H -tln "sport = :830" 2>/dev/null | grep -q .; then
    echo "ERROR: Host port 830 is already in use. Stop the conflicting service before starting the O1 adapter."
    exit 1
fi

# Upon exit, stop the O1 adapter
trap 'trap - EXIT SIGINT SIGTERM; echo "Stopping O1 adapter..."; "$SCRIPT_DIR/stop_o1_adapter.sh"; exit' EXIT SIGINT SIGTERM

# Code from (https://gitlab.com/ocudu/ocudu_elements/ocudu_oran_apps/ocudu_netconf#run-netopeer2-server-as-standalone-container):
docker run -d --name ocudu_netconf -p 830:830 -v "$(pwd)/default_config.xml:/config/default_config.xml:ro" ocudu-netconf/ocudu-netconf:latest --config "$NETCONF_CONFIG_PROFILE" --custom-config /config/default_config.xml

cd ..

echo "Starting OCUDU O1 Adapter..."
cd ocudu_o1_adapter
source venv/bin/activate
nohup python3 src/o1_adapter.py >../logs/o1_adapter_stdout.txt 2>&1 &
deactivate
cd ..

echo "OCUDU O1 Adapter and Netconf started."

# Tail the O1 adapter logs to prevent trap exit from triggering
tail -f logs/o1_adapter_stdout.txt

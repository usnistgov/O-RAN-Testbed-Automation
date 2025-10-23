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
cd "$PARENT_DIR"

INCLUDE_HANDOVER_SUPPORT_PATCH=true
GNB_DU_ID=3584 # 0xe00
NETCONF_ADDRESS=0.0.0.0
NETCONF_PORT=11830
SFTP_PORT=11221
TELNET_PORT=9099
VES_ENDPOINT=https://127.0.0.1:8443/eventListener/v7

if [ -z "$NETCONF_ADDRESS" ]; then
    echo "Could not determine the IP address of this machine. Please check your network connection."
    exit 1
fi

if [ ! -d "o1-adapter" ]; then
    echo "Cloning o1-adapter..."
    ./install_scripts/git_clone.sh https://gitlab.eurecom.fr/oai/o1-adapter.git o1-adapter
fi

if grep -q -- "-p 11221:21 adapter-gnb" o1-adapter/start-adapter.sh; then
    echo "Patching o1-adapter/start-adapter.sh to use host networking for telnet server access..."
    sed -i.bak "s/-p 11221:21 adapter-gnb/-p 11221:21 --network=host adapter-gnb/g" o1-adapter/start-adapter.sh
fi

if [ "$INCLUDE_HANDOVER_SUPPORT_PATCH" = true ]; then
    echo "Applying patches to o1-adapter for handover support..."
    cd o1-adapter
    git restore docker/Dockerfile.adapter
    if [ ! -f "docker/Dockerfile.adapter.previous" ]; then
        cp docker/Dockerfile.adapter docker/Dockerfile.adapter.previous
        cp docker/Dockerfile.adapter.previous "$PARENT_DIR/install_patch_files/o1-adapter/docker/Dockerfile.previous.adapter"
    fi
    echo "Patching Dockerfile.adapter..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/docker/Dockerfile.adapter.patch"
    cd ..

    cd o1-adapter
    git restore docker/scripts/get-yangs.sh
    if [ ! -f "docker/scripts/get-yangs.sh.previous" ]; then
        cp docker/scripts/get-yangs.sh docker/scripts/get-yangs.sh.previous
        cp docker/scripts/get-yangs.sh.previous "$PARENT_DIR/install_patch_files/o1-adapter/docker/scripts/get-yangs.previous.sh"
    fi
    echo "Patching get-yangs.sh..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/docker/scripts/get-yangs.sh.patch"
    cd ..

    cd o1-adapter
    git restore docker/scripts/install-yangs.sh
    if [ ! -f "docker/scripts/install-yangs.sh.previous" ]; then
        cp docker/scripts/install-yangs.sh docker/scripts/install-yangs.sh.previous
        cp docker/scripts/install-yangs.sh.previous "$PARENT_DIR/install_patch_files/o1-adapter/docker/scripts/install-yangs.previous.sh"
    fi
    echo "Patching install-yangs.sh..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/docker/scripts/install-yangs.sh.patch"
    cd ..

    cd o1-adapter
    git restore src/main.c
    if [ ! -f "src/main.c.previous" ]; then
        cp src/main.c src/main.c.previous
        cp src/main.c.previous "$PARENT_DIR/install_patch_files/o1-adapter/src/main.previous.c"
    fi
    echo "Patching main.c..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/src/main.c.patch"
    cd ..

    cd o1-adapter
    git restore src/netconf/netconf_data.c
    if [ ! -f "src/netconf/netconf_data.c.previous" ]; then
        cp src/netconf/netconf_data.c src/netconf/netconf_data.c.previous
        cp src/netconf/netconf_data.c.previous "$PARENT_DIR/install_patch_files/o1-adapter/src/netconf/netconf_data.previous.c"
    fi
    echo "Patching netconf_data.c..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/src/netconf/netconf_data.c.patch"
    cd ..

    cd o1-adapter
    git restore src/netconf/netconf_data.h
    if [ ! -f "src/netconf/netconf_data.h.previous" ]; then
        cp src/netconf/netconf_data.h src/netconf/netconf_data.h.previous
        cp src/netconf/netconf_data.h.previous "$PARENT_DIR/install_patch_files/o1-adapter/src/netconf/netconf_data.previous.h"
    fi
    echo "Patching netconf_data.h..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/src/netconf/netconf_data.h.patch"
    cd ..

    cd o1-adapter
    git restore src/telnet/telnet.c
    if [ ! -f "src/telnet/telnet.c.previous" ]; then
        cp src/telnet/telnet.c src/telnet/telnet.c.previous
        cp src/telnet/telnet.c.previous "$PARENT_DIR/install_patch_files/o1-adapter/src/telnet/telnet.previous.c"
    fi
    echo "Patching telnet.c..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/src/telnet/telnet.c.patch"
    cd ..

    cd o1-adapter
    git restore src/telnet/telnet.h
    if [ ! -f "src/telnet/telnet.h.previous" ]; then
        cp src/telnet/telnet.h src/telnet/telnet.h.previous
        cp src/telnet/telnet.h.previous "$PARENT_DIR/install_patch_files/o1-adapter/src/telnet/telnet.previous.h"
    fi
    echo "Patching telnet.h..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/o1-adapter/src/telnet/telnet.h.patch"
    cd ..

    cd o1-adapter
    echo "Copying oai-handover.yang..."
    cp "$PARENT_DIR/install_patch_files/o1-adapter/docker/scripts/oai-handover.yang" docker/scripts/
    cd ..

    cd o1-adapter
    echo "Copying handover_support.md..."
    cp "$PARENT_DIR/install_patch_files/o1-adapter/handover_support.md" .
    cd ..

    echo "Successfully patched o1-adapter for handover support."
    echo
fi

# If docker is not installed
if ! command -v docker &>/dev/null; then
    ./install_scripts/install_docker.sh
fi

if ! command -v lazydocker &>/dev/null; then
    ./install_scripts/install_lazydocker.sh
fi

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

if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    sudo env $APTVARS apt-get install -y jq
fi

# Configure the o1 adapter
CONFIG_PATH="$PARENT_DIR/o1-adapter/docker/config/config.json"
if [ ! -f "$CONFIG_PATH" ]; then
    echo "Could not find $CONFIG_PATH, aborting."
    exit 1
fi

# Update the IP addresses
TEMP_CONF="o1-adapter-config.tmp.json"
jq --arg ip "$NETCONF_ADDRESS" '.network.host = $ip' "$CONFIG_PATH" >"$TEMP_CONF" && mv "$TEMP_CONF" "$CONFIG_PATH"
jq --arg ip "$NETCONF_ADDRESS" '.telnet.host = $ip' "$CONFIG_PATH" >"$TEMP_CONF" && mv "$TEMP_CONF" "$CONFIG_PATH"

# Update the gNB DU ID
jq --argjson id "$GNB_DU_ID" '.info["gnb-du-id"] = $id' "$CONFIG_PATH" >"$TEMP_CONF" && mv "$TEMP_CONF" "$CONFIG_PATH"

# Update the ports
jq --argjson port "$NETCONF_PORT" '.network["netconf-port"] = $port' "$CONFIG_PATH" >"$TEMP_CONF" && mv "$TEMP_CONF" "$CONFIG_PATH"
jq --argjson port "$SFTP_PORT" '.network["sftp-port"] = $port' "$CONFIG_PATH" >"$TEMP_CONF" && mv "$TEMP_CONF" "$CONFIG_PATH"
jq --argjson port "$TELNET_PORT" '.telnet.port = $port' "$CONFIG_PATH" >"$TEMP_CONF" && mv "$TEMP_CONF" "$CONFIG_PATH"

# Update the VES URL to point to localhost
jq --arg url "$VES_ENDPOINT" '.ves.url = $url' "$CONFIG_PATH" >"$TEMP_CONF" && mv "$TEMP_CONF" "$CONFIG_PATH"

# Optionally, link the configuration to the configs directory
# However, changes to this file will not take effect until the adapter is uninstalled and reinstalled
# mkdir -p configs
# cd configs
# sudo rm -f o1-adapter-config.json
# ln -s "$CONFIG_PATH" o1-adapter-config.json
# cd ..

# Build the o1 adapter
cd o1-adapter
./build-adapter.sh --adapter --no-cache

echo "Successfully built O1 Adapter."

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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

CONFIG_FILE="/etc/mongod/mongod.conf"

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

if [[ "$USE_SYSTEMCTL" == "true" ]]; then
    # Point mongodb to the correct configuration file
    if [ -f /lib/systemd/system/mongod.service ]; then
        sudo sed -i "s|ExecStart=/usr/bin/mongod --config .*|ExecStart=/usr/bin/mongod --config $CONFIG_FILE|" /lib/systemd/system/mongod.service
        sudo systemctl daemon-reload
    fi

    echo "Checking MongoDB service..."
    if sudo systemctl is-active --quiet mongod; then
        echo "Stopping MongoDB service..."
        sudo systemctl stop mongod
    fi

    if sudo systemctl is-enabled --quiet mongod; then
        echo "Disabling MongoDB service from starting on boot..."
        sudo systemctl disable mongod
    fi
else
    # Ensure that the service is not running and is disabled
    if command -v systemctl &>/dev/null; then
        sudo systemctl stop mongod &>/dev/null || true
        sudo systemctl disable mongod &>/dev/null || true
    fi

    if sudo pgrep -x "mongod" -a >/dev/null; then
        echo "Stopping existing MongoDB process..."
        sudo pkill -f "mongod" || true
    fi
fi

if sudo pgrep -x "mongod" >/dev/null 2>&1; then
    echo "Stopping remaining MongoDB processes..."
    sudo pkill -9 mongod 2>/dev/null || true
    sudo killall -9 mongod 2>/dev/null || true
fi

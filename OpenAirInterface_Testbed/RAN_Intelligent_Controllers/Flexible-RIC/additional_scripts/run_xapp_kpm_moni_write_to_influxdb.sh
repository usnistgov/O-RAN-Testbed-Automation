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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

echo "# Script: $(realpath $0)..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Check that the xApp binary exists
if [ ! -f "$PARENT_DIR/flexric/build/examples/xApp/c/monitor/xapp_kpm_moni_write_to_influxdb" ]; then
    echo "xapp_kpm_moni_write_to_influxdb binary not found. Please build flexric first."
    exit 1
fi

INFLUXDB_ORG="xapp-kpm-moni"
INFLUXDB_BUCKET="xapp-kpm-moni"
INFLUXDB_TOKEN_PATH="$PARENT_DIR/influxdb_auth_token.json"

# Check if influxdb is even installed:
if ! command -v influx &>/dev/null; then
    echo "InfluxDB is not installed. Installing InfluxDB..."
    ./install_scripts/install_influxdb.sh
fi

if ! systemctl is-active --quiet influxdb; then
    echo "Starting InfluxDB service..."
    ./install_scripts/start_influxdb_service.sh
    sleep 5
    # Check if the service is running
    if ! systemctl is-active --quiet influxdb; then
        echo "Failed to start InfluxDB service."
        exit 1
    fi
    echo "InfluxDB service started."
fi

# Ensure that an InfluxDB token is created
if [ -f "$INFLUXDB_TOKEN_PATH" ]; then
    if [ ! -s "$INFLUXDB_TOKEN_PATH" ]; then
        echo "Deleting empty InfluxDB token file..."
        sudo rm -f "$INFLUXDB_TOKEN_PATH"
    fi
else
    echo "InfluxDB token file does not exist."
fi
if [ ! -f "$INFLUXDB_TOKEN_PATH" ]; then
    echo "Creating an InfluxDB token to influxdb_auth_token.json..."
    influx auth create --all-access --json >"$INFLUXDB_TOKEN_PATH"
fi
INFLUXDB_TOKEN=$(jq -r '.token' "$INFLUXDB_TOKEN_PATH")

cd "$PARENT_DIR/flexric/"

CONFIG_PATH=""
if [ -f "../configs/flexric.conf" ]; then
    CONFIG_PATH="-c ../configs/flexric.conf"
fi

echo "Starting xApp KPM monitor..."
./build/examples/xApp/c/monitor/xapp_kpm_moni_write_to_influxdb "$INFLUXDB_TOKEN" $CONFIG_PATH

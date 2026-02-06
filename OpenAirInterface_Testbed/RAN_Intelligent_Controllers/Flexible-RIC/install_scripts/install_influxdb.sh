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
set -x

# Initial configuration parameters for InfluxDB initialization
INFLUXDB_ORG="xapp-kpm-moni"
INFLUXDB_BUCKET="xapp-kpm-moni"
INFLUXDB_ROOT_USER="root"
INFLUXDB_ROOT_PASS="g10bNbAj31@K"                     # Randomly generated
INFLUXDB_ROOT_TOKEN="A684h862N3b01j3KJC04Ssf2K1H95L2" # Randomly generated

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Code from (https://docs.influxdata.com/influxdb/v2/install/?t=Linux):
sudo mkdir -p /etc/apt/keyrings
curl --silent --location -O https://repos.influxdata.com/influxdata-archive.key
gpg --show-keys --with-fingerprint --with-colons ./influxdata-archive.key 2>&1 |
    grep -q '^fpr:\+24C975CBA61A024EE1B631787C3D57159FC2F927:$' &&
    cat influxdata-archive.key |
    gpg --dearmor |
        sudo tee /etc/apt/keyrings/influxdata-archive.gpg >/dev/null &&
    echo 'deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' |
    sudo tee /etc/apt/sources.list.d/influxdata.list
# Install influxdb
sudo apt-get update
sudo env $APTVARS apt-get install -y --reinstall influxdb2

# Make sure InfluxDB does not start on boot (manual start only)
if [ -f /lib/systemd/system/influxdb.service ] || [ -f /etc/systemd/system/influxdb.service ] || systemctl list-units --full -all | grep -Fq "influxdb.service"; then
    sudo systemctl unmask influxdb || true
    sudo systemctl disable influxdb
    sudo systemctl stop influxdb
    sudo service influxdb start

    # Wait for InfluxDB to be up and running before running setup
    echo "Waiting for InfluxDB to be ready..."
    COUNT=0
    while ! curl -s "http://localhost:8086/health" >/dev/null; do
        if [ $COUNT -gt 30 ]; then
            echo "Timed out waiting for InfluxDB to start."
            break
        fi
        sleep 1
        COUNT=$((COUNT + 1))
    done
else
    echo "WARNING: influxdb.service not found after installation."
fi

if [ -f influxdata-archive.key ]; then
    echo "Initializing InfluxDB 2.x..."
    influx setup \
        --username "$INFLUXDB_ROOT_USER" \
        --password "$INFLUXDB_ROOT_PASS" \
        --org "$INFLUXDB_ORG" \
        --bucket "$INFLUXDB_BUCKET" \
        --retention 0 \
        --token "$INFLUXDB_ROOT_TOKEN" \
        --force
    # Clean up the key file
    sudo rm -f influxdata-archive.key
fi

echo "Successfully installed InfluxDB 2.x"
echo "InfluxDB 2.x is running on port 8086 and will not start on boot."

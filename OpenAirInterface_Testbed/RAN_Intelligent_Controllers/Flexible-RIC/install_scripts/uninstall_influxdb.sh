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

# Do not exit immediately if a command fails
set +e

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

INFLUXDB_TOKEN_PATH="$PARENT_DIR/influxdb_auth_token.json"

echo "Uninstalling InfluxDB 2.x..."

# Fix for broken installations where the service file is missing but prerm/postrm scripts expect it
if [ ! -f /etc/systemd/system/influxdb.service ]; then
    echo "Creating dummy influxdb.service to satisfy package removal scripts..."
    sudo bash -c 'cat > /etc/systemd/system/influxdb.service <<EOF
[Unit]
Description=Dummy InfluxDB Service
[Service]
ExecStart=/bin/true
[Install]
WantedBy=multi-user.target
EOF'
    sudo systemctl daemon-reload
    CREATED_DUMMY_SERVICE=true
fi

sudo ./install_scripts/stop_influxdb_service.sh

sudo apt-get remove -y influxdb
sudo apt-get remove -y influxdb-client
sudo apt-get purge -y influxdb2 influxdb2-cli || true
sudo apt-get autoclean -y
sudo apt-get autoremove -y

if [ "$CREATED_DUMMY_SERVICE" = true ]; then
    echo "Removing dummy service file..."
    sudo rm -f /etc/systemd/system/influxdb.service
    sudo systemctl daemon-reload
fi

sudo rm -rf /var/lib/influxdb/
sudo rm -rf /var/log/influxdb/
sudo rm -rf /etc/influxdb/
sudo rm -rf ~/.influxdbv2/configs

if [ -f "$INFLUXDB_TOKEN_PATH" ]; then
    sudo rm -rf "$INFLUXDB_TOKEN_PATH"
fi

if dpkg -l | grep -q influxdb; then
    echo "ERROR: InfluxDB packages still appear to be installed."
    echo "Please check the output above for errors."
    exit 1
else
    echo "Successfully uninstalled InfluxDB 2.x."
fi

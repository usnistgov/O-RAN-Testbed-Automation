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
    sudo $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "Stopping Near-RT RIC..."
./stop.sh
./additional_scripts/stop_grafana_and_python_server.sh

if [ -d swig ]; then
    echo "Uninstalling Swig..."
    cd swig
    sudo make uninstall
    cd ..
fi
sudo rm -rf swig

if [ -d flexric/build ]; then
    echo "Uninstalling FlexRIC..."
    cd flexric/build
    sudo make uninstall
    cd ../..
fi
sudo rm -rf flexric
sudo rm -rf /usr/local/lib/flexric/
sudo rm -rf /usr/local/etc/flexric/

if command -v grafana-server &>/dev/null; then
    echo "Uninstalling Grafana..."
    sudo systemctl stop grafana-server
    sudo apt-get remove --purge -y grafana
    sudo rm -f /etc/apt/sources.list.d/grafana.list
    sudo rm -rf /etc/apt/keyrings/grafana.gpg
    sudo apt-get autoremove --purge -y
fi

sudo rm -rf logs/
sudo rm -rf configs/
sudo rm -rf install_time.txt

if [ -f influxdb_auth_token.json ]; then
    echo "Uninstalling InfluxDB..."
    ./install_scripts/uninstall_influxdb.sh

    echo "Deleting InfluxDB auth token..."
    sudo rm -f influxdb_auth_token.json
fi

echo
echo
echo "################################################################################"
echo "# Successfully uninstalled FlexRIC                                             #"
echo "################################################################################"

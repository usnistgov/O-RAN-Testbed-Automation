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

SERVER_LOG_FILE="$PARENT_DIR/logs/python_server.log"

if ! command -v grafana-server &>/dev/null; then
    echo "Grafana not found, installing..."
    # Code from (https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian):
    sudo apt-get install -y apt-transport-https software-properties-common wget
    sudo mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
    # Updates the list of available packages
    sudo apt-get update
    # Installs the latest OSS release:
    sudo apt-get install -y grafana
fi

# Installing and configuring Grafana to use the CSV data source plugin
if ! sudo grafana-cli plugins ls | grep -q yesoreyeram-infinity-datasource; then
    echo "CSV data source plugin not found, installing..."
    sudo grafana-cli plugins install yesoreyeram-infinity-datasource
fi

if ! command -v python3 &>/dev/null; then
    echo "Python3 not found, installing..."
    sudo apt-get install -y python3
fi

cd additional_scripts
if ! pgrep -f "grafana_host_kpi_metrics_over_http.py" >/dev/null; then
    echo "Hosting file: http://localhost:3030/KPI_Metrics.csv"
    >"$SERVER_LOG_FILE" # Clear the log file
    nohup python3 -u grafana_host_kpi_metrics_over_http.py >"$SERVER_LOG_FILE" 2>&1 &
else
    echo "Already hosting file: http://localhost:3030/KPI_Metrics.csv"
fi
cd ..
if ! systemctl is-active grafana-server &>/dev/null; then
    echo "Starting Grafana server..."
    if [ "$(find /etc/systemd/system -type f -newer /run/systemd/system 2>/dev/null)" ]; then
        echo "Detected changes in systemd service files. Reloading systemd daemon..."
        sudo systemctl daemon-reload
    fi
    sudo systemctl start grafana-server
else
    if $NEEDS_RESTART; then
        echo "Restarting Grafana server due to configuration changes..."
        sudo systemctl restart grafana-server
    fi
fi
sleep 3

if command -v google-chrome &>/dev/null; then
    echo "Opening Grafana in Google Chrome..."
    google-chrome "http://localhost:3000/dashboards" >/dev/null 2>&1 &
elif command -v firefox &>/dev/null; then
    echo "Opening Grafana in Firefox..."
    firefox "http://localhost:3000/dashboards" >/dev/null 2>&1 &
else
    echo "No supported browser detected. Visit http://localhost:3000/dashboards to access the WebUI."
fi

echo
echo "The default login credentials are as follows."
echo "    - U: \"admin\""
echo "    - P: \"admin\""
echo

"$PARENT_DIR/additional_scripts/run_xapp_kpm_moni_write_to_csv.sh"

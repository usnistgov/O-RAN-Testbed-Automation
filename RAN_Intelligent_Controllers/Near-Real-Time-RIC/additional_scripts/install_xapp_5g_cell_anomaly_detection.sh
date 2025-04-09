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

echo "# Script: $(realpath $0)..."

# Run this script to build and deploy the 5G Cell Anamoly Detection xApp (ad-cell) in the Near-Real-Time RIC.
# More information can be found at: https://github.com/o-ran-sc/ric-app-ad-cell and https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ad/en/latest/overview.html

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

if ! kubectl get pods -n ricplt | grep r4-influxdb-influxdb2 &>/dev/null; then
    echo "The InfluxDB pod is not running, installing it..."
    ./install_scripts/install_influxdb_pod.sh
fi

if [ "$CHART_REPO_URL" != "http://0.0.0.0:8090" ]; then
    echo "Registering the Chart Museum URL..."
    ./install_scripts/register_chart_museum_url.sh
    export CHART_REPO_URL="http://0.0.0.0:8090"
fi
sudo ./install_scripts/run_chart_museum.sh

mkdir -p xApps
cd xApps

if [ ! -d "ad-cell" ]; then
    echo "Cloning 5G Cell Anamoly Detection xApp (ad-cell)..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/ad-cell.git
fi

cd ad-cell

################################################################################
# Patching the 5G Cell Anamoly Detection xApp (ad-cell)                        #
################################################################################

INFLUXDB_TOKEN_PATH="$PARENT_DIR/influxdb_auth_token.json"
if [ ! -f "$INFLUXDB_TOKEN_PATH" ]; then
    echo "Creating an InfluxDB token to influxdb_auth_token.json..."
    kubectl exec -it r4-influxdb-influxdb2-0 --namespace ricplt -- influx auth create --org influxdata --all-access --json >"$INFLUXDB_TOKEN_PATH"
fi
INFLUXDB_TOKEN=$(jq -r '.token' "$INFLUXDB_TOKEN_PATH")

if [ ! -f "src/configuration/config.previous.ini" ]; then
    echo "Patching src/configuration/config.ini..."
    cp src/configuration/config.ini src/configuration/config.previous.ini
fi

# Set the InfluxDB URL in src/ad_config.ini
if grep -q "INFLUX_URL *= *.*" src/configuration/config.ini; then
    echo "Patching src/configuration/config.ini to change 'INFLUX_URL = $INFLUXDB_TOKEN'..."
    sed -i "s/INFLUX_URL *= *.*$/INFLUX_URL = http:\/\/r4-influxdb-influxdb2.ricplt:80/g" src/configuration/config.ini
else
    echo "Could not find 'INFLUX_URL = *' in src/configuration/config.ini."
fi

# Set the token in src/ad_config.ini
if grep -q "INFLUX_TOKEN *= *.*" src/configuration/config.ini; then
    echo "Patching src/configuration/config.ini to change 'INFLUX_TOKEN = $INFLUXDB_TOKEN'..."
    sed -i "s/INFLUX_TOKEN *= *.*$/INFLUX_TOKEN = $INFLUXDB_TOKEN/g" src/configuration/config.ini
else
    echo "Could not find 'INFLUX_TOKEN = *' in src/configuration/config.ini."
fi

# Set the bucket in src/ad_config.ini
if grep -q "INFLUX_BUCKET *= *.*" src/configuration/config.ini; then
    echo "Patching src/configuration/config.ini to change 'INFLUX_BUCKET = $INFLUXDB_TOKEN'..."
    sed -i "s/INFLUX_BUCKET *= *.*$/INFLUX_BUCKET = kpimon/g" src/configuration/config.ini
else
    echo "Could not find 'INFLUX_BUCKET = *' in src/configuration/config.ini."
fi

# Set the org in src/ad_config.ini
if grep -q "INFLUX_ORG *= *.*" src/configuration/config.ini; then
    echo "Patching src/configuration/config.ini to change 'INFLUX_ORG = $INFLUXDB_TOKEN'..."
    sed -i "s/INFLUX_ORG *= *.*$/INFLUX_ORG = influxdata/g" src/configuration/config.ini
else
    echo "Could not find 'INFLUX_ORG = *' in src/configuration/config.ini."
fi

echo "Patch completed for 5G Cell Anamoly Detection xApp (ad-cell)."

echo "Creating and modifying the configuration file init/config-file_updated.json..."
# Check if jq is installed; if not, install it
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update
    sudo apt-get install -y jq
fi

FILE="init/config-file_updated.json"
sudo rm -rf $FILE
cp init/config-file.json $FILE
# Modify the required fields using jq and overwrite the original file
jq '.containers[0].image.tag = "latest" |
    .containers[0].image.registry = "127.0.0.1:80" |
    .containers[0].image.name = "ad-cell"' "$FILE" >tmp.$$.json && mv tmp.$$.json "$FILE"

if [ ! -f ad-cell.tar ]; then
    sudo docker build -t 127.0.0.1:80/ad-cell:latest .
    sudo docker save -o ad-cell.tar 127.0.0.1:80/ad-cell:latest
    sudo chmod 755 ad-cell.tar
    sudo chown $USER:$USER ad-cell.tar

    # Import the image into the containerd container runtime
    sudo ctr -n=k8s.io image import ad-cell.tar
else
    echo "5G Cell Anamoly Detection xApp (ad-cell) is already built, skipping."
fi

echo "Onboarding the 5G Cell Anamoly Detection xApp (ad-cell)..."
OUTPUT=$(sudo dms_cli onboard ./init/config-file_updated.json ./init/schema.json)
echo $OUTPUT
if echo "$OUTPUT" | grep -q '"status": "Created"'; then
    echo "Onboarding successful: status is 'Created'."
else
    echo "Onboarding failed or 'Created' status not found."
    exit 1
fi

echo "Checking if namespace 'ricxapp' exists..."
if ! kubectl get namespace ricxapp &>/dev/null; then
    echo "Namespace 'ricxapp' does not exist. Creating it..."
    kubectl create namespace ricxapp
fi

echo "Uninstalling application 'ad-cell' if it exists..."
UNINSTALL_OUTPUT=$(dms_cli uninstall ad-cell ricxapp 2>&1) || true
if echo "$UNINSTALL_OUTPUT" | grep -q 'release: not found\|No Xapp to uninstall' || true; then
    echo "Application ad-cell not found or already uninstalled."
else
    echo "$UNINSTALL_OUTPUT"
fi

XAPP_VERSION=$(dms_cli get_charts_list | jq -r '.["ad-cell"][0].version')

echo "Installing application 'ad-cell'..."
OUTPUT=$(dms_cli install ad-cell $XAPP_VERSION ricxapp) || echo "Failed to install ad-cell xApp with dms_cli."
echo "$OUTPUT"
if echo "$OUTPUT" | grep -qE '"?status"?:\s*"?\bOK\b"?'; then
    echo "Application successfully deployed."
else
    echo "Application failed to deploy."
    exit 1
fi

cd "$PARENT_DIR"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

echo
echo
echo "################################################################################"
echo "# Successfully installed 5G Cell Anomaly Detection xApp (ad-cell)              #"
echo "################################################################################"

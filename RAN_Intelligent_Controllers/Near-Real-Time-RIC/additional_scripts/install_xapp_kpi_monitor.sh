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

# Run this script to build and deploy the Key Performance Indicator (KPI) Monitor xApp (kpimon-go) in the Near-Real-Time RIC.
# More information can be found at: https://github.com/o-ran-sc/ric-app-kpimon-go and https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-kpimon/en/latest/overview.html

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

if [ "$CHART_REPO_URL" != "http://0.0.0.0:8090" ]; then
    echo "Registering the Chart Museum URL..."
    ./install_scripts/register_chart_museum_url.sh
    export CHART_REPO_URL="http://0.0.0.0:8090"
fi
sudo ./install_scripts/run_chart_museum.sh

if [ ! -f influxdb_auth_token.json ]; then
    echo "Creating an InfluxDB token to influxdb_auth_token.json..."
    kubectl exec -it r4-influxdb-influxdb2-0 --namespace ricplt -- influx auth create --org influxdata --all-access --json >influxdb_auth_token.json
fi
INFLUXDB_TOKEN=$(jq -r '.token' influxdb_auth_token.json)

mkdir -p xApps
cd xApps

if [ ! -d "kpimon-go" ]; then
    echo "Cloning KPI Monitor xApp (kpimon-go)..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/kpimon-go.git
fi

cd kpimon-go

################################################################################
# Patching the KPI Monitor xApp (kpimon-go) control/control.go file            #
################################################################################

if [ ! -f "control/control.go.previous" ]; then
    echo "Backing up control/control.go to control/control.go.previous..."
    cp control/control.go control/control.go.previous
fi

# Replace my-org with influxdata in control/control.go
if grep -q '"my-org"' control/control.go; then
    echo "Replacing \"my-org\" with \"influxdata\"..."
    sed -i 's/"my-org"/"influxdata"/g' control/control.go
fi

# Comment out create_db() function call since it will be created here:
if grep -qE '^[[:space:]]*create_db\(\)' control/control.go; then
    echo "Commenting out create_db() function call..."
    sed -i '/^[[:space:]]*create_db()/s/^/\/\/ /' control/control.go
fi
# Create the bucket here instead of in the control.go file:
echo "Creating the 'kpimon' bucket in the 'influxdata' organization if it does not exist..."
kubectl exec -n ricplt -it r4-influxdb-influxdb2-0 -- influx bucket create --org influxdata --name kpimon --json || true

# Get the IP of the InfluxDB service
SERVICE_INFO=$(kubectl get service -n ricplt | grep r4-influxdb-influxdb)
if [ -z "$SERVICE_INFO" ]; then
    echo "No service found or kubectl command failed."
    exit 1
else
    IP_INFLUXDB=$(echo "$SERVICE_INFO" | awk '{print $3}')
fi

# Set influxdb2.NewClient("$IP_INFLUXDB", "$INFLUXDB_TOKEN")
if grep -q "influxdb2.NewClient(" control/control.go; then
    echo "Patching control/control.go to replace 'influxdb2.NewClient(' with the new client call..."
    if [ ! -f "src/control/control.go.previous" ]; then
        cp control/control.go control/control.go.previous
    fi
    sed -i "s|influxdb2.NewClient([^)]*)|influxdb2.NewClient(\"$IP_INFLUXDB\", \"$INFLUXDB_TOKEN\")|g" control/control.go
else
    echo "No modification needed in control/control.go."
fi

# In case the previous replacement failed, replace "ricplt-influxdb.ricplt" with the InfluxDB IP in control/control.go
if grep -q "ricplt-influxdb.ricplt" control/control.go; then
    echo "Patching control/control.go to replace 'ricplt-influxdb.ricplt' with '$IP_INFLUXDB'..."

    sed -i "s/ricplt-influxdb.ricplt/$IP_INFLUXDB/g" control/control.go
else
    echo "No modification needed in control/control.go."
fi

# Set the RAN Function ID if not set
if [ -z "$RAN_FUNC_ID" ]; then
    export RAN_FUNC_ID="2"
fi

# Replace the RAN Function ID to RAN_FUNC_ID
if grep -qP "\bfuncId *= *int64\([0-9]+\)" control/control.go; then
    echo "Patching control/control.go to replace 'funcId += int64(N)' with 'funcId += int64($RAN_FUNC_ID)'..."

    # Replace first occurrence of "funcId = int64(N)" to "funcId = int64($RAN_FUNC_ID)"
    sed -i "0,/funcId *= *int64([0-9]\+)/s/\(funcId *= *\)\(int64([0-9]\+)\)/\1int64($RAN_FUNC_ID)/" control/control.go
else
    echo "No modification needed in control/control.go."
fi
# Replace .RanFunctionId == N in control/control.go
if grep -q ".RanFunctionId == [0-9]\+" control/control.go; then
    echo "Patching control/control.go to replace '.RanFunctionId == [0-9]\+' with '.RanFunctionId == $RAN_FUNC_ID'..."

    sed -i "s/.RanFunctionId == [0-9]\+/.RanFunctionId == $RAN_FUNC_ID/g" control/control.go
else
    echo "No modification needed in control/control.go."
fi

echo "Creating and modifying the configuration file deploy/config_updated.json"
# Check if jq is installed; if not, install it
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update
    sudo apt-get install -y jq
fi

FILE="deploy/config_updated.json"
sudo rm -rf $FILE
cp deploy/config.json $FILE
# Modify the required fields using jq and overwrite the original file
jq '.containers[0].image.tag = "latest" |
    .containers[0].image.registry = "example.com:80" |
    .containers[0].image.name = "kpimon-go"' "$FILE" >tmp.$$.json && mv tmp.$$.json "$FILE"

if [ ! -f kpimon-go.tar ]; then
    sudo docker build -t example.com:80/kpimon-go:latest .
    sudo docker save -o kpimon-go.tar example.com:80/kpimon-go:latest
    sudo chmod 755 kpimon-go.tar
    sudo chown $USER:$USER kpimon-go.tar

    # Import the image into the containerd container runtime
    sudo ctr -n=k8s.io image import kpimon-go.tar
else
    echo "KPI Monitor xApp (kpimon-go) is already built, skipping."
fi

echo "Onboarding the KPI Monitor xApp (kpimon-go)..."
OUTPUT=$(sudo dms_cli onboard ./deploy/config_updated.json ./deploy/schema.json)
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

echo "Uninstalling application 'kpimon-go' if it exists..."
UNINSTALL_OUTPUT=$(dms_cli uninstall kpimon-go ricxapp 2>&1) || true
if echo "$UNINSTALL_OUTPUT" | grep -q 'release: not found\|No Xapp to uninstall' || true; then
    echo "Application kpimon-go not found or already uninstalled."
else
    echo "$UNINSTALL_OUTPUT"
fi

XAPP_VERSION=$(dms_cli get_charts_list | jq -r '.["kpimon-go"][0].version')

echo "Installing application 'kpimon-go'..."
OUTPUT=$(dms_cli install kpimon-go $XAPP_VERSION ricxapp) || echo "Failed to install kpimon-go xApp with dms_cli."
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
echo "# Successfully installed KPI Monitor xApp (kpimon-go)                          #"
echo "################################################################################"

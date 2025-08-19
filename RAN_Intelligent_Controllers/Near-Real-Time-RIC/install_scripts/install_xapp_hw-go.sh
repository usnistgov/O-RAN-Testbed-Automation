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

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"

cd xApps/hw-go

echo "Creating and modifying the configuration file config/config-file_updated.json"
# Check if jq is installed; if not, install it
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update
    APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
    sudo $APTVARS apt-get install -y jq
fi

FILE="config/config-file_updated.json"
sudo rm -rf $FILE
cp config/config-file.json $FILE
# Modify the required fields using jq and overwrite the original file, following the NIST TN 2311 blueprint
jq '.containers[0].image.tag = "latest" |
    .containers[0].image.registry = "example.com:80" |
    .containers[0].image.name = "hw-go"' "$FILE" >tmp.$$.json && mv tmp.$$.json "$FILE"

# Check if the Dockerfile contains the correct RMR version; if not, update it.
# This ensures that within the hw-go pod, /usr/local/lib/librmr_si.so doesn't
# contain the rmr_free_consts memory leak bug, that was fixed in PR 7209:
# https://gerrit.o-ran-sc.org/r/c/ric-plt/xapp-frame-py/+/7209
if grep -q "4.7.0" Dockerfile; then
    echo "Updating RMR from version 4.7.0 to 4.9.4 in hw-go Dockerfile..."
    sed -i 's/4.7.0/4.9.4/g' Dockerfile
fi

docker build -t example.com:80/hw-go:latest .

if [ "$CHART_REPO_URL" != "http://0.0.0.0:8090" ]; then
    export CHART_REPO_URL=http://0.0.0.0:8090
fi

docker save -o hw-go.tar example.com:80/hw-go:latest
sudo chmod 755 hw-go.tar
sudo chown $USER:$USER hw-go.tar

# Import the image into the containerd container runtime
sudo ctr -n=k8s.io image import hw-go.tar

echo "Onboarding the xApp (hw-go)..."
OUTPUT=$(sudo dms_cli onboard ./config/config-file_updated.json ./config/schema.json)
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

echo "Uninstalling application 'hw-go' if it exists..."
UNINSTALL_OUTPUT=$(dms_cli uninstall hw-go ricxapp 2>&1) || true
if echo "$UNINSTALL_OUTPUT" | grep -q 'release: not found\|No Xapp to uninstall' || true; then
    echo "Application hw-go not found or already uninstalled."
else
    echo "$UNINSTALL_OUTPUT"
fi

XAPP_VERSION=$(dms_cli get_charts_list | jq -r '.["hw-go"][0].version')

echo "Installing application 'hw-go'..."
OUTPUT=$(dms_cli install hw-go $XAPP_VERSION ricxapp || echo "Failed to install hw-go xApp with dms_cli.")
echo "$OUTPUT"
if echo "$OUTPUT" | grep -qE '"?status"?:\s*"?\bOK\b"?'; then
    echo "Application successfully deployed."
else
    echo "Application failed to deploy."
    exit 1
fi

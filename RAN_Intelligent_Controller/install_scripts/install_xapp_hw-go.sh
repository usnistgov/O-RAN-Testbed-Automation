#!/bin/bash

# Exit immediately if a command fails
set -e

if [ ! -f "full_install.sh" ]; then
    echo "You must run this script from the main directory with full_install.sh"
    exit 1
fi

cd xApps/hw-go

echo "Creating and modifying the configuration file config/config-file_MODIFIED.json"
# Check if jq is installed; if not, install it
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    sudo apt update -y
    sudo apt install -y jq
fi

if [ ! -f "config/config-file_MODIFIED.json" ]; then
    cp config/config-file.json config/config-file_MODIFIED.json
    FILE="config/config-file_MODIFIED.json"
    # Modify the required fields using jq and overwrite the original file
    jq '.containers[0].image.tag = "1.2" | 
        .containers[0].image.registry = "example.com:80" | 
        .containers[0].image.name = "hw-go"' "$FILE" > tmp.$$.json && mv tmp.$$.json "$FILE"
fi

sudo docker build -t example.com:80/hw-go:1.2 .

if [ "$CHART_REPO_URL" != "http://0.0.0.0:8090" ]; then
    export CHART_REPO_URL=http://0.0.0.0:8090
fi

sudo docker save -o hw-go.tar example.com:80/hw-go:1.2

sudo ctr -n=k8s.io image import hw-go.tar

# Run the dms_cli onboard command and capture the output
output=$(dms_cli onboard ./config/config-file_MODIFIED.json ./config/schema.json)
echo $output
if echo "$output" | grep -q '"status": "Created"'; then
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

# Check if the xApp is already installed and uninstall it if necessary
if dms_cli get_charts_list | grep -q 'hw-go' || true; then
    echo "Uninstalling application 'hw-go'..."
    uninstall_output=$(dms_cli uninstall hw-go ricxapp 2>&1) || true
    if echo "$uninstall_output" | grep -q 'release: not found\|No Xapp to uninstall' || true; then
        echo "Application hw-go not found or already uninstalled."
    else
        echo "$uninstall_output"
    fi
fi

echo "Installing application 'hw-go'..."
output=$(dms_cli install hw-go 1.0.0 ricxapp || echo "Failed to install hw-go xApp with dms_cli.")
echo "$output"
if [[ "$output" == *"status: OK"* ]]; then
    echo "Application successfully installed."
else
    echo "Application failed to install."
    exit 1
fi

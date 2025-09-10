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

# Run this script to build and deploy the Hello World Python xApp (hw-python) in the Near-Real-Time RIC.
# More information can be found at: https://github.com/o-ran-sc/ric-app-hw-python

# Exit immediately if a command fails
set -e

CURRENT_DIR=$(pwd)
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

mkdir -p xApps
cd xApps

if [ ! -d "hw-python" ]; then
    echo "Cloning the Hello World Python xApp (hw-python)..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/hw-python.git
fi

cd hw-python

echo "Creating and modifying the configuration file init/config-file_updated.json..."
# Check if jq is installed; if not, install it
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update
    APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
    sudo env $APTVARS apt-get install -y jq
fi

FILE="init/config-file_updated.json"
sudo rm -rf $FILE
cp init/config-file.json $FILE
# Modify the required fields using jq and overwrite the original file
jq '.containers[0].image.tag = "latest" |
    .containers[0].image.registry = "127.0.0.1:80" |
    .containers[0].image.name = "hw-python"' "$FILE" >tmp.$$.json && mv tmp.$$.json "$FILE"

# Check if docker is accessible from the current user, and if not, repair its permissions
if [ -z "$FIXED_DOCKER_PERMS" ]; then
    if ! OUTPUT=$(docker info 2>&1); then
        if echo "$OUTPUT" | grep -qiE 'permission denied|cannot connect to the docker daemon'; then
            echo "Docker permissions will repair on reboot."
            sudo groupadd -f docker
            if [ -n "$SUDO_USER" ]; then
                sudo usermod -aG docker "${SUDO_USER:-root}"
            else
                sudo usermod -aG docker "${USER:-root}"
            fi
            # Rather than requiring a reboot to apply docker permissions, set the docker group and re-run the parent script
            export FIXED_DOCKER_PERMS=1
            if ! command -v sg &>/dev/null; then
                echo
                echo "WARNING: Could not find set group (sg) command, docker may fail without sudo until the system reboots."
                echo
            else
                exec sg docker "$CURRENT_DIR/$0" "$@"
            fi
        fi
    fi
fi

if [ ! -f hw-python.tar ]; then
    docker build -t 127.0.0.1:80/hw-python:latest .
    docker save -o hw-python.tar 127.0.0.1:80/hw-python:latest
    sudo chmod 755 hw-python.tar
    sudo chown $USER:$USER hw-python.tar

    # Import the image into the containerd container runtime
    sudo ctr -n=k8s.io image import hw-python.tar
else
    echo "Hello World Python xApp (hw-python) is already built, skipping."
fi

echo "Onboarding the Hello World Python xApp (hw-python)..."
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

echo "Uninstalling application 'hw-python' if it exists..."
UNINSTALL_OUTPUT=$(dms_cli uninstall hw-python ricxapp 2>&1) || true
if echo "$UNINSTALL_OUTPUT" | grep -q 'release: not found\|No Xapp to uninstall' || true; then
    echo "Application hw-python not found or already uninstalled."
else
    echo "$UNINSTALL_OUTPUT"
fi

XAPP_VERSION=$(dms_cli get_charts_list | jq -r '.["hw-python"][0].version')

echo "Installing application 'hw-python'..."
OUTPUT=$(dms_cli install hw-python $XAPP_VERSION ricxapp) || echo "Failed to install hw-python xApp with dms_cli."
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
echo "# Successfully installed Hello World Python xApp (hw-python)                   #"
echo "################################################################################"

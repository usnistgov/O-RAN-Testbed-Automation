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

# Ensure you're in the correct directory
cd appmgr/xapp_orchestrater/dev/xapp_onboarder

# Install prerequisites
if ! command -v python3 &>/dev/null; then
    sudo apt-get install -y python3
fi
if ! command -v pip &>/dev/null; then
    sudo apt-get install -y python3-pip
fi
if ! dpkg -l | grep -q python3-venv; then
    sudo apt-get install -y python3-venv
fi

# Check if the dmi_cli binary is already installed
if [ "$CHART_REPO_URL" != "http://0.0.0.0:8090" ]; then
    export CHART_REPO_URL="http://0.0.0.0:8090"
fi
if [[ $(sudo -E dms_cli health 2>/dev/null) == "True" ]]; then
    echo "Health check was successful."
    exit 0
else
    if [ -d "venv" ]; then
        echo "Cleaning up previous virtual environment before creating a new one..."
        sudo rm -rf venv
    fi
fi

# Ensure that any old build directories are removed before creating a new one
if [ -d build ]; then
    echo "Cleaning up previous build..."
    sudo rm -rf build
fi
if [ -d xapp_onboarder.egg-info ]; then
    echo "Cleaning up previous xapp_onboarder.egg-info..."
    sudo rm -rf xapp_onboarder.egg-info
fi

# Create a virtual environment and activate it
python3 -m venv venv
source venv/bin/activate

# Ensure the virtual environment is activated before proceeding
if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "Virtual environment not activated. Exiting."
    exit 1
fi

# Verify active Python and pip
echo "Using Python: $(which python)"
echo "Using pip: $(which pip)"

# Upgrade pip and install wheel
pip install --upgrade pip setuptools wheel

# Install dependencies ensuring there are no cached packages
pip cache purge

echo "Updating requirements.txt before xapp_onboarder installation..."
if [ ! -f requirements.previous.txt ]; then
    mv requirements.txt requirements.previous.txt
else
    rm -rf requirements.txt
fi
cat <<EOF | sudo tee requirements.txt
aniso8601~=9.0
attrs~=24.2
blinker~=1.8
certifi~=2024.8
chardet~=5.2
charset-normalizer~=3.4
click~=8.1
fire~=0.7
Flask~=3.0
flask-restx~=1.3
idna~=3.10
importlib_metadata~=8.5
importlib_resources~=6.4
itsdangerous~=2.2
Jinja2~=3.1
jsonschema~=4.23
jsonschema-specifications~=2023.12
MarkupSafe~=2.1
pyrsistent~=0.20
pytz>=2024.2
PyYAML~=6.0
referencing~=0.35
requests~=2.32
rpds-py~=0.20
six~=1.16
termcolor~=2.4
urllib3~=2.2
Werkzeug~=3.0
zipp~=3.20
EOF

# In case dms_cli binary is already installed, it can be uninstalled using the following command
# if pip show xapp_onboarder > /dev/null 2>&1; then
#     pip uninstall -y xapp_onboarder
# fi

# Install xapp_onboarder using the following command
if ! pip show xapp_onboarder >/dev/null 2>&1; then
    echo
    echo "Installing..."
    pip install ./
fi

# Set permissions for dms_cli
DMS_CLI_PATH="$(pwd)/venv/bin/dms_cli"
if [ -f "$DMS_CLI_PATH" ]; then
    echo "Setting permissions for dms_cli..."
    chmod 755 "$DMS_CLI_PATH"
else
    echo "dms_cli not found at $DMS_CLI_PATH. Installation may have failed."
    exit 1
fi

# Create a symbolic link to dms_cli in /usr/local/bin
if [ -L /usr/local/bin/dms_cli ] || [ -e /usr/local/bin/dms_cli ]; then
    sudo rm /usr/local/bin/dms_cli
    echo "Existing symbolic link or file 'dms_cli' removed."
fi

sudo ln -s "$DMS_CLI_PATH" /usr/local/bin/dms_cli
echo "Symbolic link created for dms_cli at /usr/local/bin/dms_cli"

cd ../../../../ # Main directory

if ! curl -s $CHART_REPO_URL >/dev/null; then
    echo "Server at http://0.0.0.0:8090 is not running. Attempting to start..."
    sudo ./install_scripts/run_chart_museum.sh
else
    echo "Server at http://0.0.0.0:8090 is running."
fi

# Check if the output is 'True'
if [[ $(sudo -E dms_cli health) == "True" ]]; then
    echo "Health check was successful."
else
    echo "Current PATH: $PATH"
    echo "Current CHART_REPO_URL: $CHART_REPO_URL"
    echo "Error: Health check failed, ensure that \"CHART_REPO_URL=http://0.0.0.0:8090\" then retry running \"dms_cli health\""
    exit 1
fi

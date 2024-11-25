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

# Set the current directory as the script directory
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Install dependencies if not already installed
if ! command -v python3 &>/dev/null; then
    echo "Python is not installed. Installing Python..."
    sudo apt-get update
    sudo apt-get install -y python3
fi
if ! command -v pip &>/dev/null; then
    sudo apt-get install -y python3-pip
fi
if ! dpkg -l | grep -q python3-venv; then
    sudo apt-get install -y python3-venv
fi

# Create a virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating a new virtual environment..."
    python3 -m venv venv
fi

# Activate the virtual environment
source venv/bin/activate

# Ensure the virtual environment is activated before proceeding
if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "Virtual environment not activated. Exiting."
    exit 1
fi

# Create the requirements.txt file if it doesn't exist already
if [ ! -f requirements.txt ]; then
    cat <<EOF | tee "requirements.txt" >/dev/null
cachetools==5.5.0
certifi==2024.8.30
charset-normalizer==3.4.0
durationpy==0.9
google-auth==2.36.0
idna==3.10
iniconfig==2.0.0
kubernetes==31.0.0
oauthlib==3.2.2
packaging==24.2
pluggy==1.5.0
pyasn1==0.6.1
pyasn1_modules==0.4.1
pytest==8.3.3
python-dateutil==2.9.0.post0
PyYAML==6.0.2
requests==2.32.3
requests-oauthlib==2.0.0
rsa==4.9
six==1.16.0
urllib3==2.2.3
websocket-client==1.8.0
EOF
fi

# Check if requirements need to be installed by comparing the hash of the requirements file
REQ_HASH_FILE=".requirements_hash"
if [ ! -f $REQ_HASH_FILE ] || [ "$(sha256sum requirements.txt | awk '{print $1}')" != "$(cat $REQ_HASH_FILE)" ]; then
    echo "Requirements changed. Installing packages..."
    pip install -r requirements.txt
    sha256sum requirements.txt | awk '{print $1}' >$REQ_HASH_FILE
fi

pytest tests/ -s

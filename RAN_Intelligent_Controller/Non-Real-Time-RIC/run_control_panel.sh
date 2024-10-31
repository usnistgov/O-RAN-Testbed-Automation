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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"
BASE_DIR=$(pwd)

if [ ! -d nonrtric-controlpanel ]; then
    echo "Cloning the Non RT-RIC Control Panel..."
    git clone https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel
fi
cd nonrtric-controlpanel
if ! docker ps | grep -q nonrtric-controlpanel || ! docker ps | grep -q nonrtric-gateway; then
    echo "Starting the control panel and gateway..."
    cd docker-compose
    docker-compose -f docker-compose.yaml -f control-panel/docker-compose.yaml -f nonrtric-gateway/docker-compose.yaml up -d
    cd ..
else
    echo "The Control Panel and Gateway are already running."
fi

cd webapp-frontend

if ! command -v npm &>/dev/null; then
    echo
    echo "Installing npm..."
    sudo apt-get install -y npm
fi
if ! command -v ng &>/dev/null; then
    echo
    echo "Installing Angular CLI..."
    sudo npm install -g @angular/cli
fi
echo
echo "Installing control panel dependencies..."
if [ -d "$BASE_DIR/nonrtric-controlpanel/webapp-frontend/node_modules" ]; then
    echo "Dependencies appear to be installed."
else
    npm install --force
fi

echo
echo "Starting the control panel..."

# Mock example now using the real backend:
# export NODE_OPTIONS=--openssl-legacy-provider
# npm run start:mock &> $BASE_DIR/logs/controlpanel_stdout.txt &
# firefox localhost:4200

export NODE_OPTIONS=--openssl-legacy-provider
mkdir -p $BASE_DIR/logs
npm start &> $BASE_DIR/logs/controlpanel_stdout.txt &

echo "Opening the control panel in Firefox..."
firefox localhost:8080
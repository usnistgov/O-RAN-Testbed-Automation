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

PARAMS=""
for VAR in "$@"; do
    PARAMS="$PARAMS $VAR"
done

if ! command -v docker-compose &>/dev/null; then
    ./install_scripts/install_docker_compose.sh
fi

if [ ! -d nonrtric-controlpanel ]; then
    git clone https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel
fi
cd nonrtric-controlpanel
if ! sudo docker ps -a | grep -q nonrtric-controlpanel || ! sudo docker ps -a | grep -q nonrtric-gateway; then
    echo "Starting docker-compose for the control panel and gateway..."
    cd docker-compose
    if ! sudo docker-compose -f docker-compose.yaml -f control-panel/docker-compose.yaml -f nonrtric-gateway/docker-compose.yaml up -d; then
        echo "Docker Compose failed to start, attempting to restart Docker..."
        sudo systemctl restart docker
        echo "Retrying Docker Compose..."
        sudo docker-compose -f docker-compose.yaml -f control-panel/docker-compose.yaml -f nonrtric-gateway/docker-compose.yaml up -d
    fi
    sudo systemctl restart docker
    cd ..
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
    export NG_CLI_ANALYTICS=ci # Disable Angular CLI analytics
    sudo npm install -g @angular/cli
fi
if [ ! -d "$SCRIPT_DIR/nonrtric-controlpanel/webapp-frontend/node_modules" ]; then
    echo
    echo "Installing control panel dependencies..."
    # TODO: Fix the deprecated dependencies in the control panel
    npm install --force
    echo
fi

if [[ $PARAMS != *onlyinstall* ]]; then
    mkdir -p "$SCRIPT_DIR/logs"
    export NODE_OPTIONS=--openssl-legacy-provider
    npm start &>"$SCRIPT_DIR/logs/controlpanel_stdout.txt" &

    # Mock example instead of using the real backend
    # export NODE_OPTIONS=--openssl-legacy-provider
    # npm run start:mock &>"$SCRIPT_DIR/logs/controlpanel_stdout.txt" &
    # firefox localhost:4200

    CONTROL_PANEL_PORT=4200
    if ! curl -s localhost:$CONTROL_PANEL_PORT >/dev/null; then
        CONTROL_PANEL_PORT=8080
    fi

    if command -v google-chrome &>/dev/null; then
        echo "Opening the control panel in Google Chrome..."
        google-chrome "http://localhost:$CONTROL_PANEL_PORT" >/dev/null 2>&1 &
        sleep 3
    elif command -v firefox &>/dev/null; then
        echo "Opening the control panel in Firefox..."
        firefox "http://localhost:$CONTROL_PANEL_PORT" >/dev/null 2>&1 &
        sleep 3
    else
        echo "No supported browser detected. Visit http://localhost:$CONTROL_PANEL_PORT to access the control panel."
    fi
fi

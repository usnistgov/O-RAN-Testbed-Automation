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

if [ "$1" = "mock" ]; then
    MOCK_MODE=true
else
    MOCK_MODE=false
fi

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if ! command -v docker-compose &>/dev/null; then
    ./install_scripts/install_docker_compose.sh
fi

if [ ! -d nonrtric-controlpanel ]; then
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel.git nonrtric-controlpanel
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
# Disable Angular CLI analytics to prevent prompting during installation
export NG_CLI_ANALYTICS=ci
unset NODE_OPTIONS

if ! command -v nvm &>/dev/null; then
    # Code from: https://github.com/nvm-sh/nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    source ~/.bashrc
fi
if ! command -v node &>/dev/null || [[ $(node -v) != v14.21.3 ]]; then
    echo "Setting node version..."
    nvm install 14.21.3
    nvm use 14.21.3
fi
if ! command -v ng &>/dev/null && [ ! -f "./ng" ]; then
    echo
    echo "Installing Angular CLI..."
    npm install @angular/cli@9.1.13 --loglevel=error
fi
# sudo rm -rf node_modules/
if [ ! -d "$SCRIPT_DIR/nonrtric-controlpanel/webapp-frontend/node_modules" ]; then
    npm install --legacy-peer-deps --loglevel=error
    echo
fi

mkdir -p "$SCRIPT_DIR/logs"

if [ "$MOCK_MODE" = true ]; then
    ./ng serve --configuration=mock 2>&1 | tee "$SCRIPT_DIR/logs/controlpanel_stdout.txt" &
else
    ./ng serve --proxy-config proxy.conf.json 2>&1 | tee "$SCRIPT_DIR/logs/controlpanel_stdout.txt" &
fi

echo "Waiting for the control panel to start..."
until curl -s -o /dev/null -w "%{http_code}" localhost:4200 | grep -q "200"; do
    sleep 3
done

if command -v google-chrome &>/dev/null; then
    echo "Opening the control panel in Google Chrome..."
    nohup google-chrome "http://localhost:4200" >/dev/null 2>&1 &
elif command -v firefox &>/dev/null; then
    echo "Opening the control panel in Firefox..."
    nohup firefox "http://localhost:4200" >/dev/null 2>&1 &
else
    echo "No supported browser detected. Visit http://localhost:4200 to access the control panel."
fi
sleep 10

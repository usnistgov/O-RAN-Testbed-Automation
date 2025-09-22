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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if ! command -v docker &>/dev/null; then
    echo "Docker not found, installing..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker "$USER"
fi

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
                exec sg docker -c "$(printf '%q ' "$CURRENT_DIR/$0" "$@")"
            fi
        fi
    fi
fi

if ! command -v docker-compose &>/dev/null; then
    ./install_scripts/install_docker_compose.sh
fi

if [ ! -d nonrtric-controlpanel ]; then
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel.git nonrtric-controlpanel
fi

# Ensure the correct YAML editor is installed
sudo "$SCRIPT_DIR/install_scripts/./ensure_consistent_yq.sh"

# Fetch the addresses of the policy management service and information service
SERVICE_INFO_PMS=$(kubectl get service -n nonrtric | grep policymanagementservice || echo "")
if [ ! -z "$SERVICE_INFO_PMS" ]; then
    IP_PMS=$(echo "$SERVICE_INFO_PMS" | awk '{print $3}')
    PORT_PMS=$(echo "$SERVICE_INFO_PMS" | awk '{split($5, a, /[:/]/); print a[1]}')
fi

SERVICE_INFO_ICS=$(kubectl get service -n nonrtric | grep informationservice || echo "")
if [ ! -z "$SERVICE_INFO_ICS" ]; then
    IP_ICS=$(echo "$SERVICE_INFO_ICS" | awk '{print $3}')
    PORT_ICS=$(echo "$SERVICE_INFO_ICS" | awk '{split($5, a, /[:/]/); print a[1]}')
fi

if [ ! -z "$IP_PMS" ] && [ ! -z "$PORT_PMS" ]; then
    YAML_CONFIG_PATH="$SCRIPT_DIR/nonrtric-controlpanel/nonrtric-gateway/config/application.yaml"
    A1_POLICY_URI_EXISTS=$(yq eval '.spring.cloud.gateway.routes[0].id' "$YAML_CONFIG_PATH")
    if [ "$A1_POLICY_URI_EXISTS" != "null" ]; then
        yq eval ".spring.cloud.gateway.routes[0].uri = \"http://$IP_PMS:$PORT_PMS\"" -i "$YAML_CONFIG_PATH"
        echo "Configured A1-Policy route of control panel to http://$IP_PMS:$PORT_PMS."
    fi
    JSON_CONFIG_PATH="$SCRIPT_DIR/nonrtric-controlpanel/webapp-frontend/proxy.conf.json"
    if jq -e '.["/a1-policy"].target' "$JSON_CONFIG_PATH" >/dev/null; then
        jq --arg newUrl "http://$IP_PMS:$PORT_PMS" '.["/a1-policy"].target = $newUrl' "$JSON_CONFIG_PATH" >temp.json && mv -f temp.json "$JSON_CONFIG_PATH"
        echo "Configured A1-Policy proxy target to http://$IP_PMS:$PORT_PMS."
    fi
fi

if [ ! -z "$IP_ICS" ] && [ ! -z "$PORT_ICS" ]; then
    YAML_CONFIG_PATH="$SCRIPT_DIR/nonrtric-controlpanel/nonrtric-gateway/config/application.yaml"
    A1_EL_URI_EXISTS=$(yq eval '.spring.cloud.gateway.routes[1].id' "$YAML_CONFIG_PATH")
    if [ "$A1_EL_URI_EXISTS" != "null" ]; then
        yq eval ".spring.cloud.gateway.routes[1].uri = \"http://$IP_ICS:$PORT_ICS\"" -i "$YAML_CONFIG_PATH"
        echo "Configured A1-EI route of control panel to http://$IP_ICS:$PORT_ICS."
    fi
    JSON_CONFIG_PATH="$SCRIPT_DIR/nonrtric-controlpanel/webapp-frontend/proxy.conf.json"
    if jq -e '.["/data-producer"].target' "$JSON_CONFIG_PATH" >/dev/null; then
        jq --arg newUrl "http://$IP_ICS:$PORT_ICS" '.["/data-producer"].target = $newUrl' "$JSON_CONFIG_PATH" >temp.json && mv -f temp.json "$JSON_CONFIG_PATH"
        echo "Configured /data-producer proxy target to http://$IP_ICS:$PORT_ICS."
    fi
    if jq -e '.["/data-consumer"].target' "$JSON_CONFIG_PATH" >/dev/null; then
        jq --arg newUrl "http://$IP_ICS:$PORT_ICS" '.["/data-consumer"].target = $newUrl' "$JSON_CONFIG_PATH" >temp.json && mv -f temp.json "$JSON_CONFIG_PATH"
        echo "Configured /data-consumer proxy target to http://$IP_ICS:$PORT_ICS."
    fi
fi

cd nonrtric-controlpanel

if ! docker ps -a | grep -q nonrtric-controlpanel || ! docker ps -a | grep -q nonrtric-gateway; then
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
    # Code from (https://github.com/nvm-sh/nvm):
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    if [ ! -f ~/.bashrc ]; then
        touch ~/.bashrc
    fi
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

if command -v xdg-open &>/dev/null; then
    echo "Opening the control panel in the default web browser at URL http://localhost:4200"
    xdg-open "http://localhost:4200" >/dev/null 2>&1 &
else
    echo "No default browser detected. Visit http://localhost:4200 to access the control panel."
fi

sleep 10

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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "Starting Grafana WebUI setup..."

COMPOSE_FILE="ocudu/docker/docker-compose.ui.yml"
OVERRIDE_FILE="ocudu/docker/docker-compose.override.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: Could not find docker-compose file with Grafana configuration."
    exit 1
fi

ENV_FILE="ocudu/docker/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Configuring WS_URL in .env..."
    if getent hosts host.docker.internal >/dev/null 2>&1 || ping -c 1 -W 1 host.docker.internal >/dev/null 2>&1; then
        echo "Using host.docker.internal for WS_URL"
        sed -i 's/^WS_URL=.*/WS_URL=host.docker.internal:8001/' "$ENV_FILE"
    else
        HOST_IP=$(hostname -I | awk '{print $1}')
        echo "Falling back to Host IP $HOST_IP for WS_URL"
        sed -i "s/^WS_URL=.*/WS_URL=${HOST_IP}:8001/" "$ENV_FILE"
    fi
fi

# If docker is not installed
if ! command -v docker &>/dev/null; then
    ./install_scripts/install_docker.sh
fi

if ! command -v lazydocker &>/dev/null; then
    ./install_scripts/install_lazydocker.sh
fi

echo "Checking for docker compose..."
DOCKER_COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "ERROR: Docker compose not found. Please install Docker Compose V2."
    exit 1
fi

echo "Starting Grafana container..."
cat <<'EOF' >"$OVERRIDE_FILE"
services:
  grafana:
    container_name: ocudu-grafana
  telegraf:
    container_name: ocudu-telegraf
  influxdb:
    container_name: ocudu-influxdb
EOF

sudo $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE" up -d grafana

echo "Waiting for Grafana to initialize..."
sleep 5

# Open WebUI
echo "Grafana is running at: http://localhost:3300"

if command -v xdg-open &>/dev/null; then
    echo "Opening Grafana in default web browser at http://localhost:3300..."
    xdg-open "http://localhost:3300" >/dev/null 2>&1 &
else
    echo "No default browser detected. Visit http://localhost:3300 to access the Grafana WebUI."
    echo "Please open http://localhost:3300 in your web browser."
fi

echo
echo "The default login credentials are as follows."
echo "    - U: \"admin\""
echo "    - P: \"admin\""
echo

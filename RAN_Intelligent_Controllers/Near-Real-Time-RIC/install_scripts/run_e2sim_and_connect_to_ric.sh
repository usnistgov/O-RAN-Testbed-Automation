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

# Path to the output file
mkdir -p logs
OUTPUT_FILE="logs/e2sim_output.txt"

# Check if the container with the name 'oransim' is already running
if [ $(sudo docker ps -q -f name=^/oransim$ | wc -l) -eq 1 ]; then
    echo "Container 'oransim' is already running."
elif [ $(sudo docker ps -aq -f name=^/oransim$ | wc -l) -eq 1 ]; then
    echo "Container 'oransim' exists but is not running, starting container..."
    rm -rf OUTPUT_FILE
    sudo docker start oransim
else
    echo "Starting a new container 'oransim'..."
    rm -rf OUTPUT_FILE
    sudo docker run -d -it --name oransim oransim:0.0.999
fi
kubectl get svc -n ricplt | grep e2term-sctp || true

sudo docker exec oransim pkill -f kpm_sim || true

# Get the IP and port of the E2 termination point inside the near Real Time RIC
SERVICE_NAME="service-ricplt-e2term-sctp"
LINE=""

ATTEMPTS=1
MAX_ATTEMPTS=10
KPM_RESTARTS=1
KPM_MAX_RESTARTS=3
export CHART_REPO_URL=http://0.0.0.0:8090

# Monitor output file for a success message
while true; do
    if [ -z "$LINE" ]; then
        LINE=$(kubectl get svc -n ricplt | grep $SERVICE_NAME) || ""
        IP_e2term=$(echo $LINE | awk '{print $3}')
        PORT_e2term=$(echo $LINE | awk '{print $5}' | sed 's/:.*//')
        echo "IP for $SERVICE_NAME: $IP_e2term"
        echo "PORT for $SERVICE_NAME: $PORT_e2term"
    fi
    if [ -z "$IP_e2term" ] || [ -z "$PORT_e2term" ]; then
        echo "Could not find service $SERVICE_NAME. IP or PORT is missing. Services:"
        kubectl get svc -n ricplt
        echo "Retrying in 8 seconds..."
        sleep 8
        continue
    fi
    # Create the log file if it does not exist
    if [ ! -f $OUTPUT_FILE ]; then
        touch $OUTPUT_FILE
        sudo chown $USER:$USER $OUTPUT_FILE
    fi
    # Check if kpm_sim is already running to avoid duplicate runs
    if ! pgrep -f "kpm_sim $IP_e2term $PORT_e2term" >/dev/null; then
        echo "Starting kpm_sim in the background, writing to $OUTPUT_FILE..."
        >"$OUTPUT_FILE" # Clears the content of the output file
        sudo docker exec -i oransim kpm_sim $IP_e2term $PORT_e2term >$OUTPUT_FILE 2>&1 &
        sleep 2
    fi

    if ! grep -q "</E2AP-PDU>" $OUTPUT_FILE; then
        # Alternatively, wait for SETUP-RESPONSE-SUCCESS: if ! grep -q SETUP-RESPONSE-SUCCESS $OUTPUT_FILE; then
        echo "Waiting for connection between E2 Simulator and RIC, please be patient for all pods to be ready... $ATTEMPTS/$MAX_ATTEMPTS"
        sleep 5
    else
        break
    fi

    if [ "$ATTEMPTS" -eq "$MAX_ATTEMPTS" ]; then
        cat $OUTPUT_FILE
        kubectl get pods -A || true
        echo
        echo "Restarting kpm_sim inside of oransim..."
        sudo docker exec oransim pkill -f kpm_sim || true
        ATTEMPTS=0
        KPM_RESTARTS=$((KPM_RESTARTS + 1))
        if [ "$KPM_RESTARTS" -eq "$KPM_MAX_RESTARTS" ]; then
            echo "Restarting Kubernetes pods..."
            sudo systemctl restart kubelet
            KPM_RESTARTS=0
        fi
        sleep 1
    fi
    ATTEMPTS=$((ATTEMPTS + 1))
done

SERVICE_NAME="service-ricplt-e2mgr-http"
LINE=$(kubectl get svc -n ricplt | grep $SERVICE_NAME) || ""
IP_HTTP_e2term=$(echo $LINE | awk '{print $3}')
PORT_HTTP_e2term=$(echo $LINE | awk '{print $5}' | sed 's/\/.*//' | cut -d: -f2)
echo "$IP_HTTP_e2term:$PORT_HTTP_e2term"

response=$(curl -X GET $IP_HTTP_e2term:$PORT_HTTP_e2term/v1/nodeb/states 2>/dev/null)

# Verify if the connectionStatus is "CONNECTED"
status=$(echo "$response" | jq -r '.[].connectionStatus' | grep "CONNECTED" || true)
if [[ $status == "CONNECTED" ]]; then
    echo "$response" | jq
    echo "Successfully connected the E2 simulator and RIC cluster."
else
    echo "Connection between E2 simulator and RIC cluster is pending."
fi

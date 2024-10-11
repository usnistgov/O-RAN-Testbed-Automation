#!/bin/bash
echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

if [ ! -f "full_install.sh" ]; then
    echo "You must run this script from the main directory with full_install.sh"
    exit 1
fi

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
    if ! pgrep -f "kpm_sim $IP_e2term $PORT_e2term" > /dev/null; then
        echo "Starting kpm_sim in the background, writing to $OUTPUT_FILE..."
    	> "$OUTPUT_FILE" # Clears the content of the output file
        sudo docker exec -i oransim kpm_sim $IP_e2term $PORT_e2term > $OUTPUT_FILE 2>&1 &
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

        # Alternative solution: Restarting the entire ricplt-e2term-alpha pod (long wait for the previous one to terminate)
        #POD_NAME=$(kubectl get pods -n ricplt -l app=ricplt-e2term-alpha -o jsonpath='{.items[0].metadata.name}')
        #if [ -n "$POD_NAME" ]; then
        #    echo "Restarting the pod $POD_NAME, please be patient while it restarts..."
        #    kubectl delete pod $POD_NAME -n ricplt
        #    # Wait for the old pod to be completely removed
        #    kubectl wait --for=delete pod/$POD_NAME -n ricplt --timeout=120s
        #    # Wait for a new pod to be ready
        #    sleep 5 # Brief sleep to allow for pod recreation
        #    NEW_POD_NAME=$(kubectl get pods -n ricplt -l app=ricplt-e2term-alpha -o jsonpath='{.items[0].metadata.name}')
        #    kubectl wait --for=condition=ready pod/$NEW_POD_NAME -n ricplt --timeout=120s
        #    ATTEMPTS=0
        #else
        #    echo "No pods found with label app=ricplt-e2term-alpha. Please check your label or deployment."
        #    exit 1
        #fi
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
    kubectl get svc -n ricplt || true
    echo
    echo
    echo "Connection between E2 simulator and RIC cluster did not complete."
    echo "Run the following command to get more information:"
    echo "curl -X GET $IP_HTTP_e2term:$PORT_HTTP_e2term/v1/nodeb/states | jq"
fi
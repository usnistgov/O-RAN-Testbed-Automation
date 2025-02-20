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
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Path to the output file
mkdir -p logs
OUTPUT_FILE="logs/e2sim_output.txt"

# Stop the oransim container before starting it again
if [ $(sudo docker ps -q -f name=^/oransim$ | wc -l) -eq 1 ]; then
    echo "Restarting oransim container..."
    sudo docker stop oransim
fi

# Check if the container with the name 'oransim' is already running
if [ $(sudo docker ps -q -f name=^/oransim$ | wc -l) -eq 1 ]; then
    echo "Container 'oransim' is already running."
elif [ $(sudo docker ps -aq -f name=^/oransim$ | wc -l) -eq 1 ]; then
    echo "Container 'oransim' exists but is not running, starting container..."
    rm -rf $OUTPUT_FILE
    sudo docker start oransim
else
    echo "Starting a new container 'oransim'..."
    rm -rf $OUTPUT_FILE
    sudo docker run -d -it --name oransim oransim:0.0.999
fi

# Get the IP and port of the E2 termination point inside the near Real Time RIC
SERVICE_NAME="service-ricplt-e2term-sctp"
LINE=$(kubectl get svc -n ricplt | grep $SERVICE_NAME) || ""
IP_E2TERM=$(echo $LINE | awk '{print $3}')
PORT_E2TERM=$(echo $LINE | awk '{print $5}' | sed 's/:.*//')
echo "IP for $SERVICE_NAME: $IP_E2TERM"
echo "PORT for $SERVICE_NAME: $PORT_E2TERM"

if [ -z "$IP_E2TERM" ] || [ -z "$PORT_E2TERM" ]; then
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

if ! sudo docker exec oransim pgrep -f "kpm_sim" >/dev/null; then
    echo "Stopping previous instance of kpm_sim..."
    pkill -f kpm_sim || true
fi

sudo docker exec -i oransim kpm_sim $IP_E2TERM $PORT_E2TERM | tee -a $OUTPUT_FILE

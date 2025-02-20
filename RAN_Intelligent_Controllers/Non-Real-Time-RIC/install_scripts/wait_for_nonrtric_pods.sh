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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"

# Exit immediately if a command fails
set -e

# Function to wait for pods to be in a running state across multiple namespaces
wait_for_all_pods_running() {
    local NAMESPACES=("$@")
    local ALL_PODS_RUNNING=0
    local NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

    echo "Initiating wait for all pods to be in 'Running' or 'Completed' state across specified namespaces."

    while [ $ALL_PODS_RUNNING -eq 0 ]; do
        echo
        kubectl get pods -A || true
        ALL_PODS_RUNNING=1 # Assume all pods are running until proven otherwise
        for NAMESPACE in "${NAMESPACES[@]}"; do
            local CMD="kubectl get pods -n $NAMESPACE --no-headers"
            local POD_STATUS=$($CMD 2>/dev/null)
            local CMD_STATUS=$?
            if [ "$CMD_STATUS" -ne 0 ]; then
                echo "Failed to execute kubectl command for namespace $NAMESPACE, retrying..."
                ALL_PODS_RUNNING=0
                break
            fi

            # If namespace is kube-flannel but there are no pods in kube-flannel, skip the namespace
            if [ "$NAMESPACE" == "kube-flannel" ] && [ -z "$POD_STATUS" ]; then
                continue
            fi

            # Process the pod status to check if all are 'Running' or 'Completed', and handle Terminating pods
            echo "$POD_STATUS" | awk '{
                split($2, arr, "/");
                if ($3 == "Terminating") next;
                if ($1 ~ /^oran-nonrtric-kong/) next; # Skip kong check
                if ($3 != "Running" && $3 != "Completed") exit 1;
                if ($3 == "Running" && arr[1] != arr[2]) exit 1
            }' || {
                # Check for disk-pressure taint on the node and warn the user
                if kubectl describe nodes | grep Taints | grep disk-pressure &>/dev/null; then
                    sudo ./install_scripts/handle_disk_pressure_taint.sh
                fi
                echo
                echo "Some pods in $NAMESPACE are not yet ready. Please be patient."
                ALL_PODS_RUNNING=0
                break
            }
        done
        if [ $ALL_PODS_RUNNING -eq 1 ]; then
            echo "All pods are in the desired state across specified namespaces."
            break
        fi

        # Check if the Kong pod is not up, and allow the user to migrate the Kong database if needed
        CAN_MIGRATE_DB=0
        POD_INFO=$(echo $POD_STATUS | grep -oP 'oran-nonrtric-kong-[^\s]+ \S+ \S+' | awk '{print $1, $3}')
        if [ ! -z "$POD_INFO" ]; then
            POD_NAME=$(echo $POD_INFO | awk '{print $1}')
            POD_STATUS=$(echo $POD_INFO | awk '{print $2}')
            if [ ! "$POD_STATUS" == "Running" ]; then
                CAN_MIGRATE_DB=1
            fi
        fi

        if [ $CAN_MIGRATE_DB -eq 1 ]; then
            echo "    Press \"b\" to bootstrap/initialize the Kong database with the necessary schema and configurations."
        fi
        echo "    Press \"k\" to start the interactive k9s pod manager (then use Ctrl+C to return to this script)."

        read -t 5 -n 1 KEY || true
        if [ "$KEY" == "k" ]; then
            K9S_SCRIPT_PATH="$(dirname "$SCRIPT_DIR")/./start_k9s.sh"
            trap '' SIGINT
            sudo k9s -A || exec "$K9S_SCRIPT_PATH" || true
            echo
            echo "Resuming parent script (ignoring Ctrl+C input for 8 seconds)..."
            sleep 8
            trap - SIGINT
            echo "Resumed parent script."

        elif [ "$KEY" == "b" ]; then
            echo
            echo "Attempting to bootstrap the Kong database..."
            kubectl exec -n nonrtric -c wait-for-db $POD_NAME -- kong migrations bootstrap || true
            sleep 8

        elif [ ! -z "$KEY" ]; then
            sleep 5
        fi

        # Check if the API server is not up, and wait for that first
        if ! kubectl get --raw="/api/v1/namespaces/kube-system/pods" >/dev/null 2>&1; then
            sudo ./install_scripts/wait_for_kubectl.sh
        fi
    done
}

# Remaining taints may prevent the RIC components from initializing
# Check for remaining taints with: kubectl describe nodes | grep Taints
KUBEVERSION=$(kubectl version | awk '/Server Version:/ {print $3}' | sed 's/v//')
if [[ ${KUBEVERSION} == 1.28.* ]]; then
    echo "Attempting to remove any remaining taints from control-plane..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
else
    echo "Attempting to remove any remaining taints from master..."
    kubectl taint nodes --all node-role.kubernetes.io/master- || true
fi

# Wait for essential system pods and RIC components to be ready
echo "Waiting for essential system pods and RIC components to be ready..."

wait_for_all_pods_running "kube-flannel" "nonrtric"

# Initialize the Kong database with the necessary schema and configurations
POD_INFO=$(kubectl get pods -n nonrtric --no-headers | grep 'oran-nonrtric-kong' | awk '{print $1, $3}')
if [ ! -z "$POD_INFO" ]; then
    POD_NAME=$(echo $POD_INFO | awk '{print $1}')
    POD_STATUS=$(echo $POD_INFO | awk '{print $2}')
    if [ ! "$POD_STATUS" == "Running" ]; then
        echo "Bootstrapping the Kong database..."
        kubectl exec -n nonrtric -c wait-for-db $POD_NAME -- kong migrations bootstrap
    fi
fi

echo "All required pods are now running."

#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Exit immediately if a command fails
set -e

# Function to wait for pods to be in a running state across multiple namespaces
wait_for_all_pods_running () {
    local NAMESPACES=("$@")
    local ALL_PODS_RUNNING=0

    echo "Initiating wait for all pods to be in 'Running' or 'Completed' state across specified namespaces."

    while [ $ALL_PODS_RUNNING -eq 0 ]; do
        ALL_PODS_RUNNING=1 # Assume all pods are running until proven otherwise
        for NAMESPACE in "${NAMESPACES[@]}"; do
            local CMD="kubectl get pods -n $NAMESPACE --no-headers"
            local POD_STATUS=$($CMD 2>/dev/null)  # Suppress error output and prevent script exit on command fail
            local CMD_STATUS=$?
            if [ "$CMD_STATUS" -ne 0 ]; then
                echo "Failed to execute kubectl command for namespace $NAMESPACE, retrying..."
                ALL_PODS_RUNNING=0
                break
            fi
            # Process the pod status to check if all are 'Running' or 'Completed'
            echo "$POD_STATUS" | awk '{ split($2, arr, "/"); if ($3 != "Running" && $3 != "Completed") exit 1; if ($3 == "Running" && arr[1] != arr[2]) exit 1}' || {
                echo
                echo "Some pods in $NAMESPACE are not yet in the 'Running' or 'Completed' state, or not all containers are ready. Please be patient as it may take some time for the ricplt pods (e.g., e2term) to be ready."
                ALL_PODS_RUNNING=0
                break
            }
        done
        if [ $ALL_PODS_RUNNING -eq 1 ]; then
            echo "All pods are in the desired state across specified namespaces."
            break
        fi
        kubectl get pods -A || true
        sleep 5
    done
    kubectl get pods -A || true
}


KUBEVERSION=$(kubectl version | awk '/Server Version:/ {print $3}' | sed 's/v//')
# Fetch the Helm version
HELMVERSION=$(helm version --short | sed 's/.*v\([0-9]\).*/\1/')

# Remaining taints may prevent the RIC components from initializing
# Check for remaining taints with: kubectl describe nodes | grep Taints
if [[ ${KUBEVERSION} == 1.28.* ]]; then
    echo "Attempting to remove any remaining taints from control-plane..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
else
    echo "Attempting to remove any remaining taints from master..."
    kubectl taint nodes --all node-role.kubernetes.io/master- || true
fi

# Wait for essential system pods and RIC components to be ready
echo "Waiting for essential system pods and RIC components to be ready..."

# Check if the version is not 2
if [ "$HELMVERSION" != "2" ]; then
    echo "Helm version $HELMVERSION is in use"
    wait_for_all_pods_running "kube-flannel" "ricplt"
else
    echo "Helm version 2 is in use."
    wait_for_all_pods_running "kube-flannel" "ricinfra" "ricplt"
fi

echo "All required pods are now running."

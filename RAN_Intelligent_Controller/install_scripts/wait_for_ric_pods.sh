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
    local TIMER_START=0
    local INTERVAL_UNTIL_PURGE=600 # 10 minutes in seconds
    local DURATION=$INTERVAL_UNTIL_PURGE

    echo "Initiating wait for all pods to be in 'Running' or 'Completed' state across specified namespaces."

    while [ $ALL_PODS_RUNNING -eq 0 ]; do
        kubectl get pods -A || true
        ALL_PODS_RUNNING=1 # Assume all pods are running until proven otherwise
        for NAMESPACE in "${NAMESPACES[@]}"; do
            local CMD="kubectl get pods -n $NAMESPACE --no-headers"
            local POD_STATUS=$($CMD 2>/dev/null) # Suppress error output and prevent script exit on command fail
            local CMD_STATUS=$?
            if [ "$CMD_STATUS" -ne 0 ]; then
                echo "Failed to execute kubectl command for namespace $NAMESPACE, retrying..."
                ALL_PODS_RUNNING=0
                break
            fi
            # Process the pod status to check if all are 'Running' or 'Completed', and handle Terminating pods
            echo "$POD_STATUS" | awk '{
                split($2, arr, "/"); 
                if ($3 == "Terminating") next;
                if ($3 != "Running" && $3 != "Completed") exit 1;
                if ($3 == "Running" && arr[1] != arr[2]) exit 1
            }' || {
                # Check for 'Terminating' pods with a running counterpart
                TERMINATING_PODS=$(echo "$POD_STATUS" | awk '$3 == "Terminating" || $3 == "ContainerStatusUnknown" || $3 == "Evicted" || $3 == "Error" { print $1 }')
                RUNNING_PODS=$(echo "$POD_STATUS" | awk '$3 == "Running" { split($2, a, "/"); if (a[1] == a[2]) print $1 }')
                for POD in $TERMINATING_PODS; do
                    base_name=$(echo $POD | sed 's/-[^-]*$//') # Strip the last part after the final dash
                    if echo $RUNNING_PODS | grep -q $base_name; then
                        echo "Force deleting terminating pod $POD as a fully ready counterpart exists."
                        kubectl delete pod $POD -n $NAMESPACE --grace-period=0 --force --wait=false
                    fi
                done

                # Handle 'CrashLoopBackOff' and 'Error' by restarting the pod when all initializing pods are complete
                INITIALIZING_PODS=$(echo "$POD_STATUS" | awk '$3 == "ContainerCreating" || $3 == "PodInitializing" || $3 ~ /^Init:/ { print $1 }')
                if [ -n "$INITIALIZING_PODS" ]; then
                    echo "Some pods in $NAMESPACE are in initializing states. Waiting..."
                    TIMER_START=0
                else
                    # No pods in critical initializing states, safe to delete pods in 'CrashLoopBackOff' or 'Error' states
                    echo "$POD_STATUS" | awk '$3 == "CrashLoopBackOff" || $3 == "Evicted" || $3 == "Error" { print $1 }' | xargs -I {} kubectl delete pod {} -n $NAMESPACE --wait=false

                    if [[ $TIMER_START -eq 0 ]]; then
                        TIMER_START=$(date +%s) # Set TIMER_START to current Unix timestamp
                        echo "Timer started at $(date)"
                    fi
                    CURRENT_TIME=$(date +%s)
                    let ELAPSED_TIME=(${CURRENT_TIME:-0}-${TIMER_START:-0}) || true
                    let DURATION=($INTERVAL_UNTIL_PURGE-$ELAPSED_TIME) || true
                    if [ $ELAPSED_TIME -ge $INTERVAL_UNTIL_PURGE ]; then
                        echo "10 minutes have passed since all pods were ready. Running purge script."
                        sudo ./install_scripts/purge_unready_pods.sh
                        TIMER_START=$(date +%s) # Reset timer
                    fi
                fi
                echo
                echo "Some pods in $NAMESPACE are not yet in the 'Running' or 'Completed' state, or not all containers are ready. Please be patient. Unready nodes will be purged in $DURATION seconds."
                ALL_PODS_RUNNING=0
                break
            }
        done
        if [ $ALL_PODS_RUNNING -eq 1 ]; then
            echo "All pods are in the desired state across specified namespaces."
            break
        fi
        sleep 5

        # Check if the API server is not up, and wait for that first
        if [ ! $(kubectl get --raw="/api/v1/namespaces/kube-system/pods" > /dev/null 2>&1) ]; then
            sudo ./install_scripts/wait_for_kubectl.sh
        fi
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

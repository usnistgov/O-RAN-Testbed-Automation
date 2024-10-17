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

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Exit immediately if a command fails
set -e

# Function to extract the base name from a pod name, e.g., deployment-ricplt-e2mgr-856f655b4-7sn49 --> deployment-ricplt-e2mgr
get_base_name () {
    local POD_NAME=$1
    local NODE_NAME=$2
    local BASE_NAME
    if [[ "$POD_NAME" == *"$NODE_NAME" ]]; then
        BASE_NAME="$POD_NAME"
    else
        BASE_NAME=$(echo "$POD_NAME" | sed -E 's/(-[a-zA-Z0-9]+){1,2}$//')
        if [ -z "$BASE_NAME" ]; then
            BASE_NAME="$POD_NAME"
        fi
    fi
    echo "$BASE_NAME"
}

# Function to wait for pods to be in a running state across multiple namespaces
wait_for_all_pods_running () {
    local NAMESPACES=("$@")
    local ALL_PODS_RUNNING=0
    local TIMER_START=0
    local INTERVAL_UNTIL_PURGE=60 # 1 minute
    local DURATION=$INTERVAL_UNTIL_PURGE
    local NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

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
                # Check for disk-pressure taint on the node and warn the user
                if kubectl describe nodes | grep Taints | grep disk-pressure &>/dev/null; then
                    sudo ./install_scripts/handle_disk_pressure_taint.sh
                fi

                # Check for 'Terminating' pods with a running counterpart
                TERMINATING_PODS=$(echo "$POD_STATUS" | awk '$3 == "Terminating" || $3 == "ContainerStatusUnknown" || $3 == "Evicted" || $3 == "Error" { print $1 }')
                RUNNING_PODS=$(echo "$POD_STATUS" | awk '$3 == "Running" { split($2, a, "/"); if (a[1] == a[2]) print $1 }')
                for POD_NAME in $TERMINATING_PODS; do
                    # Extract the base name by removing the last two dash-separated fields
                    BASE_NAME=$(get_base_name "$POD_NAME" "$NODE_NAME")
                    if echo $RUNNING_PODS | grep -q $BASE_NAME; then
                        echo "Force deleting terminating pod $POD in 5 seconds, as a fully ready counterpart exists."
                        sleep 5
                        kubectl delete pod $POD -n $NAMESPACE --grace-period=0 --force --wait=false || true
                    fi
                done

                # Associative array to store pods by their base name
                declare -A BASE_NAME_TO_PODS
                BASE_NAME_TO_PODS=()

                POD_INFO=$(kubectl get pods -A --no-headers)
                while read -r NAMESPACE POD_NAME _; do
                    # Extract the base name by removing the last two dash-separated fields
                    BASE_NAME=$(get_base_name "$POD_NAME" "$NODE_NAME")
                    BASE_NAME_TO_PODS["$BASE_NAME"]+="$NAMESPACE $POD_NAME,"
                done <<< "$POD_INFO"

                # Iterate over the base names and their corresponding pods
                for BASE_NAME in "${!BASE_NAME_TO_PODS[@]}"; do
                    if [ "$BASE_NAME" == "kube" ] || [ "$BASE_NAME" == "coredns" ]; then
                        continue
                    fi
                    POD_LIST="${BASE_NAME_TO_PODS[$BASE_NAME]}"
                    # Remove the trailing comma and split the entries into an array
                    IFS=',' read -ra POD_ENTRIES <<< "${POD_LIST%,}"
                    # Check if there are more than one pod for the same base name
                    if [ "${#POD_ENTRIES[@]}" -gt 1 ]; then
                        echo "Found duplicate pods for base name '$BASE_NAME'."
                        # Loop through the array from the second element to delete duplicates, keeping the first one
                        for (( i=${#POD_ENTRIES[@]}-1; i>0; i-- )); do
                            read -r POD_NAMESPACE POD_NAME <<< "${POD_ENTRIES[i]}"
                            echo "    Deleting duplicate pod '$POD_NAME' in namespace '$POD_NAMESPACE'."
                            kubectl delete pod "$POD_NAME" -n "$POD_NAMESPACE" --grace-period=0 --force --wait=false
                        done
                    fi
                done

                # Handle 'CrashLoopBackOff' and 'Error' by restarting the pod when all initializing pods are complete
                INITIALIZING_PODS=$(echo "$POD_STATUS" | awk '$3 == "ContainerCreating" || $3 == "PodInitializing" || $3 ~ /^Init:/ { print $1 }')
                if [ -n "$INITIALIZING_PODS" ]; then
                    TIMER_START=0
                    echo
                    echo "Some pods in $NAMESPACE are still initializing. Please be patient."
                else
                    if [[ $TIMER_START -eq 0 ]]; then
                        TIMER_START=$(date +%s) # Set TIMER_START to current Unix timestamp
                        echo "Timer started at $(date)"
                    fi
                    CURRENT_TIME=$(date +%s)
                    let ELAPSED_TIME=(${CURRENT_TIME:-0}-${TIMER_START:-0}) || true
                    let DURATION=($INTERVAL_UNTIL_PURGE-$ELAPSED_TIME) || true
                    if [ $ELAPSED_TIME -ge $INTERVAL_UNTIL_PURGE ]; then
                        echo "$INTERVAL_UNTIL_PURGE minute$([ "$INTERVAL_UNTIL_PURGE" -ne 1 ] && echo s) passed since all pods were ready. Running purge script."
                        sudo ./install_scripts/purge_unready_pods.sh
                        TIMER_START=$CURRENT_TIME
                        let DURATION=$INTERVAL_UNTIL_PURGE
                    fi
                    echo
                    echo "Some pods in $NAMESPACE are not yet ready. Please be patient. Unready nodes will be purged in $DURATION seconds."
                fi
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

echo "Scanning for and deleting all terminating pods across all namespaces."
CMD="kubectl get pods -n ricplt --no-headers"
POD_STATUS=$($CMD 2>/dev/null) # Suppress error output and prevent script exit on command fail
TERMINATING_PODS=$(echo "$POD_STATUS" | awk '$3 == "Terminating" || $3 == "ContainerStatusUnknown" || $3 == "Evicted" || $3 == "Error" { print $1 }')
for POD in $TERMINATING_PODS; do
    echo "Force deleting terminating pod $POD as a fully ready counterpart exists."
    kubectl delete pod $POD -n ricplt --grace-period=0 --force --wait=false
done

echo "All required pods are now running."

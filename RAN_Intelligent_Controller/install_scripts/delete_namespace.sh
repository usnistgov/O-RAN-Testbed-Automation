#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <namespace1> [<namespace2> ...]"
    echo "Please provide at least one namespace as argument."
    exit 1
fi

for NAMESPACE in "$@"; do
    echo "Processing namespace $NAMESPACE..."

    # Check if the namespace exists and exit if it does not
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Namespace $NAMESPACE already does not exist."
        continue
    fi

    # Function to force delete finalizers
    function force_delete_finalizers {
        echo "Attempting to remove finalizers from all remaining resources in $NAMESPACE..."
        for resource in $(kubectl api-resources --verbs=list --namespaced -o name); do
            kubectl get "$resource" -n "$NAMESPACE" -o name 2>/dev/null | \
            xargs -r -n1 kubectl patch -n "$NAMESPACE" --type=merge -p '{"metadata":{"finalizers":[]}}' 2>/dev/null
        done
    }

    # Delete all resources within the namespace
    echo "Deleting all resources in the namespace $NAMESPACE..."
    for resource in $(kubectl api-resources --verbs=delete --namespaced -o name); do
        kubectl delete "$resource" --all -n "$NAMESPACE" --grace-period=0 --force 2>/dev/null
    done

    # Removing any stuck finalizers
    echo "Checking for stuck resources and removing finalizers..."
    force_delete_finalizers

    # Deleting the namespace
    echo "Deleting the namespace $NAMESPACE..."
    kubectl delete namespace "$NAMESPACE" --wait=false 2>/dev/null

    echo "Requested deletion of namespace $NAMESPACE. Monitoring status..."
    # Set a timeout for namespace deletion
    TIMEOUT=300
    START_TIME=$(date +%s)

    while true; do
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
        if [ "$ELAPSED_TIME" -ge "$TIMEOUT" ]; then
            echo "Timeout reached. Proceeding with forced removal of any lingering resources."
            force_delete_finalizers
            break
        fi
        if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
            echo "Namespace $NAMESPACE has been successfully deleted."
            break
        else
            echo "Namespace $NAMESPACE is still terminating..."
            sleep 5
        fi
    done

    echo "$NAMESPACE has been processed for deletion."
done

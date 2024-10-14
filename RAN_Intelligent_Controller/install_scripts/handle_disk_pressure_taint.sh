#!/bin/bash

# If the disk-pressure taint is not present then skip
if ! kubectl describe nodes | grep Taints | grep -q "disk-pressure"; then
    echo "No disk-pressure taint found on any nodes, skipping."
    exit 0
fi

# Get a list of nodes with the disk-pressure taint
AFFECTED_NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints[*].key}{"\t"}{.spec.taints[*].effect}{"\n"}' | grep "disk-pressure" | cut -f1)
if [ -z "$AFFECTED_NODES" ]; then
    echo "No nodes with disk-pressure taint found, skipping."
    exit 0
fi

# Remove the disk-pressure taint from each affected node
for NODE in $AFFECTED_NODES; do
    echo "Removing taint disk-pressure from $NODE..."
    if ! kubectl taint nodes $NODE node.kubernetes.io/disk-pressure- --overwrite; then
        echo "Failed to remove taint from $NODE. Check your permissions or connectivity."
    fi
done

sleep 1

# Check if the taint was successfully removed from each affected node
TAINT_REMOVAL_FAILED=0
for NODE in $AFFECTED_NODES; do
    if kubectl describe node $NODE | grep -q "node.kubernetes.io/disk-pressure"; then
        echo "Error: Taint disk-pressure is still present on $NODE."
        TAINT_REMOVAL_FAILED=1
    else
        echo "Taint: disk-pressure was successfully removed from $NODE."
    fi
done

# If any taint removal failed
if [ $TAINT_REMOVAL_FAILED -eq 1 ]; then
    echo "ERROR: Disk-pressure taint is active. Please ensure sufficient RAM and disk space is available."
    exit 1
fi

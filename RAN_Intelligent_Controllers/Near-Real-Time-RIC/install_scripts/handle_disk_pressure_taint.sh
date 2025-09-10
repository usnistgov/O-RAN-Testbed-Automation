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

echo "# Script: $(realpath "$0")..."

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
    echo "Error: Disk-pressure taint is active. Please ensure sufficient RAM and disk space is available."
    exit 1
fi

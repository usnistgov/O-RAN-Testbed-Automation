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

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "# Script: $(realpath "$0")..."

echo "Stopping the cluster..."
sudo systemctl start kubelet
if kubectl get pdb r4-influxdb-influxdb2 -n ricplt &>/dev/null; then
    kubectl delete pdb r4-influxdb-influxdb2 -n ricplt
fi

NAMESPACES=("ricplt" "ricxapp" "ricinfra")

for NAMESPACE in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        kubectl scale deployment --all --replicas=0 -n "$NAMESPACE" || true
        kubectl scale statefulset --all --replicas=0 -n "$NAMESPACE" || true

        # Suspend jobs
        if kubectl get job -n "$NAMESPACE" &>/dev/null; then
            kubectl get jobs -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}' | while read JOB_NAME; do
                kubectl patch job "$JOB_NAME" -n "$NAMESPACE" --type=merge -p '{"spec":{"suspend":true}}' 2>/dev/null || true
            done
        fi

        # Remove completed pods as they are no longer needed
        kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep 'Completed' | awk '{print $1}' | while read POD_NAME; do
            echo "Cleaning up completed pod $POD_NAME in namespace $NAMESPACE..."
            kubectl delete pod "$POD_NAME" -n "$NAMESPACE" 2>/dev/null || true
        done

        # Remove remaining pods that cannot scale to 0
        kubectl delete pods --all -n "$NAMESPACE" 2>/dev/null || true
    fi
done

kubectl get pods -A

for NAMESPACE in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Waiting for $NAMESPACE pods to terminate..."
        kubectl wait --for=delete pod --all -n "$NAMESPACE" --timeout=120s 2>/dev/null || true
    fi
done

echo "Stopping RIC platform services..."
sudo systemctl stop kubelet
sudo systemctl stop docker
kubectl get pods -A

echo "Successfully stopped cluster."

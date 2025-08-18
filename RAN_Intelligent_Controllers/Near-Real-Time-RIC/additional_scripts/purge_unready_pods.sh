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

echo "Scanning for pods that are not in the ready state..."

# Get all pods across all namespaces without headers
PODS=$(kubectl get pods --all-namespaces --no-headers)

# Loop through each line of PODS
echo "$PODS" | while read -r NAMESPACE NAME READY STATUS RESTARTS AGE; do
    READY_READY=$(echo "$READY" | cut -d'/' -f1)
    READY_TOTAL=$(echo "$READY" | cut -d'/' -f2)

    if [ "$READY_READY" -ne "$READY_TOTAL" ]; then
        echo "Pod $NAME in namespace $NAMESPACE is not ready."

        # Get the owner references of the pod to find its controller
        CONTROLLER_KIND=$(kubectl get pod "$NAME" -n "$NAMESPACE" -o json | jq -r '.metadata.ownerReferences[0].kind')
        CONTROLLER_NAME=$(kubectl get pod "$NAME" -n "$NAMESPACE" -o json | jq -r '.metadata.ownerReferences[0].name')

        if [ -n "$CONTROLLER_KIND" ] && [ -n "$CONTROLLER_NAME" ]; then
            echo "Pod $NAME is managed by $CONTROLLER_KIND $CONTROLLER_NAME."

            case "$CONTROLLER_KIND" in
            "ReplicaSet")
                # Find the Deployment managing the ReplicaSet
                DEPLOYMENT_NAME=$(kubectl get rs "$CONTROLLER_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null)
                if [ -n "$DEPLOYMENT_NAME" ]; then
                    echo "Restarting Deployment $DEPLOYMENT_NAME in namespace $NAMESPACE."
                    kubectl rollout restart deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"
                else
                    echo "ReplicaSet $CONTROLLER_NAME is not managed by a Deployment. Deleting pod $NAME."
                    kubectl delete pod "$NAME" -n "$NAMESPACE" --wait=false
                fi
                ;;
            "StatefulSet")
                echo "Restarting StatefulSet $CONTROLLER_NAME in namespace $NAMESPACE."
                kubectl rollout restart statefulset "$CONTROLLER_NAME" -n "$NAMESPACE"
                ;;
            "DaemonSet")
                echo "Restarting DaemonSet $CONTROLLER_NAME in namespace $NAMESPACE."
                kubectl rollout restart daemonset "$CONTROLLER_NAME" -n "$NAMESPACE"
                ;;
            "Job" | "CronJob")
                echo "Controller is a $CONTROLLER_KIND. Not restarting. Considering deleting pod $NAME."
                # Uncomment the next line to delete it
                # kubectl delete pod "$NAME" -n "$NAMESPACE" --wait=false
                ;;
            *)
                echo "Unknown controller kind: $CONTROLLER_KIND. Considering deleting pod $NAME."
                # Uncomment the next line to delete it
                # kubectl delete pod "$NAME" -n "$NAMESPACE" --wait=false
                ;;
            esac
        else
            echo "Pod $NAME does not have a controller. Considering deleting pod $NAME."
            # Uncomment the next line to delete it
            # kubectl delete pod "$NAME" -n "$NAMESPACE" --wait=false
        fi
    fi
done

echo "Scanning for and deleting all terminating pods across all namespaces."
CMD="kubectl get pods -n corbin-oran --no-headers"
POD_STATUS=$($CMD 2>/dev/null) # Suppress error output and prevent script exit on command fail
TERMINATING_PODS=$(echo "$POD_STATUS" | awk '$3 == "Terminating" || $3 == "ContainerStatusUnknown" || $3 == "Evicted" || $3 == "Error" { print $1 }')
for POD in $TERMINATING_PODS; do
    echo "Deleting terminating pod $POD."
    kubectl delete pod $POD -n corbin-oran --grace-period=0 --force --wait=false
done

echo "Restarting kubelet service to ensure proper pod status updates."
sudo systemctl restart kubelet

echo "Processing of unready pods is complete."

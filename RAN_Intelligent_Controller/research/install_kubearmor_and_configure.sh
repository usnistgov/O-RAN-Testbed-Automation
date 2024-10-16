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

# Function to wait for pods to be in a running state
wait_for_pods_running () {
    local EXPECTED_COUNT="$1"
    local NAMESPACE="${2-all-namespaces}"
    local KEYWORD="${3-Running}"
    local ACTUAL_COUNT

    if [ "$NAMESPACE" == "all-namespaces" ]; then
        cmd="kubectl get pods -A"
    else
        cmd="kubectl get pods -n $NAMESPACE"
    fi

    echo "Initiating wait for $EXPECTED_COUNT pods to be in '$KEYWORD' state in namespace '$NAMESPACE'."

    while true; do
        ACTUAL_COUNT=$($cmd | grep -E "$KEYWORD" | wc -l 2>/dev/null)
        local CMD_STATUS=$?

        if [ "$CMD_STATUS" -ne 0 ]; then
            echo "Failed to execute kubectl command, retrying..."
            sleep 5
            continue
        fi

        echo
        echo "Currently, $ACTUAL_COUNT/$EXPECTED_COUNT pods are in the desired state in namespace $NAMESPACE."

        if [[ "$ACTUAL_COUNT" -ge "$EXPECTED_COUNT" ]]; then
            echo "Required pod count reached in namespace '$NAMESPACE'."
            break
        fi

        sleep 5
        kubectl get pods -A || true
    done
}

echo "Installing KubeArmor..."
helm repo add kubearmor https://kubearmor.github.io/charts
helm repo update
helm upgrade --install kubearmor-operator kubearmor/kubearmor-operator -n kubearmor --create-namespace
kubectl apply -f https://raw.githubusercontent.com/kubearmor/KubeArmor/main/pkg/KubeArmorOperator/config/samples/sample-config.yml

curl -sfL http://get.kubearmor.io/ | sudo sh -s -- -b /usr/local/bin


echo "Waiting for KubeArmor to initialize..."
wait_for_pods_running 1 kubearmor

echo "KubeArmor Successfully Installed. Adding configurations..."

cat <<EOF | kubectl apply -f -
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata:
  name: block-pkg-mgmt-tools-exec
spec:
  selector: {}  # Empty selector to apply to all pods
  process:
    matchPaths:
    - path: /usr/bin/apt
    - path: /usr/bin/apt-get
  action:
    Block
EOF

cat <<EOF | kubectl apply -f -
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata:
  name: block-service-access-token-access
spec:
  selector: {}  # Empty selector to apply to all pods
  file:
    matchDirectories:
    - dir: /run/secrets/kubernetes.io/serviceaccount/
      recursive: true
  action:
    Block
EOF

echo "KubeArmor initialized successfully."

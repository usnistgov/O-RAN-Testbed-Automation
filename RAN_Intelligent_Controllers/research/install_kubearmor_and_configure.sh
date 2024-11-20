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

if [ -f /etc/upstream-release/lsb-release ]; then
    UBUNTU_RELEASE=$(cat /etc/upstream-release/lsb-release | grep 'DISTRIB_RELEASE' | sed 's/.*=\s*//')
else
    UBUNTU_RELEASE=$(lsb_release -sr)
fi
SUPPORT_MATRIX=$(curl -fs https://raw.githubusercontent.com/kubearmor/KubeArmor/refs/heads/main/getting-started/support_matrix.md)
if [ $? -ne 0 ]; then
    echo "Failed to fetch the support matrix for KubeArmor (used to verify if this OS version is supported by KubeArmor)."
    read -p "Do you want to proceed anyway? (y/n): " PROCEED
    if [[ $PROCEED != "y" && $PROCEED != "yes" ]]; then
        echo "Exiting."
        exit 1
    fi
fi
if ! echo "$SUPPORT_MATRIX" | grep -q "Ubuntu.*$UBUNTU_RELEASE"; then
    echo "KubeArmor has not mentioned that Ubuntu $UBUNTU_RELEASE is supported."
    echo "However, you can try to install it and see if it works."
    read -p "Do you want to proceed anyway? (y/n): " PROCEED
    if [[ $PROCEED != "y" && $PROCEED != "yes" ]]; then
        echo "Exiting."
        exit 1
    fi
fi

SELINUX_OR_APPARMOR_ENABLED=false
# Check if SELinux is installed and active
if command -v sestatus >/dev/null 2>&1; then
    SELINUX_STATUS=$(sestatus | grep "SELinux status" | awk '{print $3}')
    if [ "$SELINUX_STATUS" != "disabled" ]; then
        SELINUX_OR_APPARMOR_ENABLED=true
    else
        echo "SELinux is installed but disabled. Activating now..."
        sudo selinux-activate
        if [ $? -eq 0 ]; then
            echo "SELinux has been activated. Please reboot your system before rerunning this script."
            exit 0
        else
            echo "Failed to activate SELinux. Please check your system configuration."
            exit 1
        fi
    fi
fi
# Check if AppArmor is installed and active only if SELinux is not enabled
if ! $SELINUX_OR_APPARMOR_ENABLED && command -v aa-status >/dev/null 2>&1; then
    APPARMOR_STATUS=$(aa-status | grep "apparmor module is loaded")
    if [ -n "$APPARMOR_STATUS" ]; then
        SELINUX_OR_APPARMOR_ENABLED=true
    else
        echo "AppArmor is installed but not active. Activating now..."
        sudo systemctl enable apparmor
        sudo systemctl start apparmor
        if systemctl is-active --quiet apparmor; then
            echo "AppArmor has been activated."
            SELINUX_OR_APPARMOR_ENABLED=true
        else
            echo "Failed to activate AppArmor. Please check your system configuration."
            exit 1
        fi
    fi
fi
if ! $SELINUX_OR_APPARMOR_ENABLED; then
    echo "No security mechanisms (SELinux or AppArmor) are enabled on this system."
    exit 1
fi
echo "Security mechanism is enabled. Proceeding with the script..."

# Function to wait for pods to be in a running state
wait_for_pods_running() {
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

echo "KubeArmor Successfully Installed."

echo "Labeling all pods with appliedsecuritypolicy for security policy selectors..."
kubectl label pods --all appliedsecuritypolicy=true --overwrite -n ricinfra || true
kubectl label pods --all appliedsecuritypolicy=true --overwrite -n ricplt || true
kubectl label pods --all appliedsecuritypolicy=true --overwrite -n ricxapp || true

KUBEARMOR_DIR="$HOME/.kube/kubearmor_configs"
mkdir -p "$KUBEARMOR_DIR"

cat <<EOF >"$KUBEARMOR_DIR/block-pkg-mgmt-tools-exec.yaml"
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata:
  name: block-pkg-mgmt-tools-exec
spec:
  selector:
    matchLabels:
      appliedsecuritypolicy: "true"
  process:
    matchPaths:
    - path: /usr/bin/apt
    - path: /usr/bin/apt-get
  action:
    Block
EOF
kubectl apply -f "$KUBEARMOR_DIR/block-pkg-mgmt-tools-exec.yaml"

cat <<EOF >"$KUBEARMOR_DIR/block-service-access-token-access.yaml"
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata:
  name: block-service-access-token-access
spec:
  selector:
    matchLabels:
      appliedsecuritypolicy: "true"
  file:
    matchDirectories:
    - dir: /run/secrets/kubernetes.io/serviceaccount/
      recursive: true
  action:
    Block
EOF
kubectl apply -f "$KUBEARMOR_DIR/block-service-access-token-access.yaml"

cat <<EOF >"$KUBEARMOR_DIR/block-all-other-network-traffic.yaml"
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata:
  name: block-all-other-network-traffic
spec:
  selector:
    matchLabels:
      appliedsecuritypolicy: "true"
  network:
    matchProtocols:
    - protocol: ICMP
    - protocol: TCP
    - protocol: UDP
  action:
    Block
EOF
kubectl apply -f "$KUBEARMOR_DIR/block-all-other-network-traffic.yaml"

echo "Waiting for KubeArmor (apparmor-containerd, controller, operator, and relay) to initialize..."
wait_for_pods_running 4 kubearmor

karmor probe

echo
echo "List of applied policies:"
kubectl get kubearmorpolicies -A
echo

if echo "$(karmor probe)" | grep -q "Container Security:\s*true"; then
    echo "Successfully enabled container security."
else
    echo "ERROR: Container security is not enabled."
    exit 1
fi

# Retrieve the current AppArmor profile status of the init process
# CURRENT_PROFILE=$(cat /proc/1/attr/current)
# if [[ "$CURRENT_PROFILE" == "unconfined" ]]; then
#     echo "ERROR: The process is unconfined, so no AppArmor profile is active."
#     exit 1
# else
#     echo "The process is confined under the profile: $CURRENT_PROFILE"
# fi

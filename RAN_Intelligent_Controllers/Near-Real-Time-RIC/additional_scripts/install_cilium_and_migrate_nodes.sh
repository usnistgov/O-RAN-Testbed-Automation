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

ENABLE_HUBBLE_LOGGING="true"

DRAIN_NODES="false"

echo "Hubble enabled: $ENABLE_HUBBLE_LOGGING"
echo "Drain nodes:    $DRAIN_NODES"
echo
echo "This script will install Cilium and migrate all nodes to Cilium for network policy enforcement (replacing the existing network plugin, e.g., Flannel)."
echo "Since this is a disruptive operation, it is recommended to back up your Kubernetes cluster before proceeding."
read -p "Would you like to proceed? (y/n): " -r REPLY

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting script."
    exit 1
fi

sudo ls &>/dev/null

if cilium status &>/dev/null; then
    echo "Cilium is already installed. Uninstalling Cilium first..."
    cilium uninstall
fi

CILIUM_CLI_VERSION="latest" # "v0.16.19"
if [ "$CILIUM_CLI_VERSION" = "latest" ]; then
    CILIUM_CLI_VERSION=$(curl -s https://api.github.com/repos/cilium/cilium-cli/releases/latest | grep tag_name | cut -d '"' -f 4)
fi
CILIUM_MIGRATION_VALUES_FILE="$HOME/.kube/cilium-values-migration.yaml"
CILIUM_INITIAL_VALUES_FILE="$HOME/.kube/cilium-values-initial.yaml"
CILIUM_FINAL_VALUES_FILE="$HOME/.kube/cilium-values-final.yaml"
if ! command -v cilium &>/dev/null; then
    echo "Installing Cilium CLI version ${CILIUM_CLI_VERSION}..."
    CLI_ARCH="amd64"
    if [ "$(uname -m)" = "aarch64" ]; then
        CLI_ARCH="arm64"
    fi
    DOWNLOAD_URL="https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
    echo "Cilium CLI Download URL: ${DOWNLOAD_URL}"
    curl -L --fail --remote-name "${DOWNLOAD_URL}"
    curl -L --fail --remote-name "${DOWNLOAD_URL}.sha256sum"
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
fi

cat <<EOF | sudo tee $CILIUM_MIGRATION_VALUES_FILE
operator:
  unmanagedPodWatcher:
    restart: false # Migration: Don't restart unmigrated pods
routingMode: tunnel # Migration: Optional: default is tunneling, configure as needed
tunnelProtocol: vxlan # Migration: Optional: default is VXLAN, configure as needed
tunnelPort: 8473 # Migration: Optional, change only if both networks use the same port by default
cni:
  customConf: true # Migration: Don't install a CNI configuration file
  uninstall: false # Migration: Don't remove CNI configuration on shutdown
ipam:
  mode: "cluster-pool"
  operator:
    clusterPoolIPv4PodCIDRList: ["10.245.0.0/16"] # Migration: Ensure this is distinct and unused
policyEnforcementMode: "never" # Migration: Disable policy enforcement
bpf:
  hostLegacyRouting: true # Migration: Allow for routing between Cilium and the existing overlay
sctp:
  enabled: true # It is important to  enable SCTP support for gNodeB to connect
EOF

echo
echo "Generating initial Cilium Helm values..."
cilium install --values $CILIUM_MIGRATION_VALUES_FILE --dry-run-helm-values >$CILIUM_INITIAL_VALUES_FILE

if ! helm repo list | grep -q "cilium"; then
    echo "Adding Cilium Helm repository..."
    helm repo add cilium https://helm.cilium.io
    helm repo update
fi

if ! cilium status &>/dev/null; then
    CILIUM_HELM_VERSION=$(helm search repo cilium --versions | grep "^cilium/cilium\\s" | head -1 | awk '{print $2}')
    echo "Using Cilium Helm version ${CILIUM_HELM_VERSION} for installation..."

    cilium install --version ${CILIUM_HELM_VERSION} --namespace kube-system --values $CILIUM_INITIAL_VALUES_FILE
fi

until cilium status --wait; do
    echo "Continuing to wait for Cilium to be ready..."
    sleep 5
done

echo
echo "Creating a per-node config to instruct Cilium to take over CNI networking on the node..."
cat <<EOF | kubectl apply --server-side -f -
apiVersion: cilium.io/v2
kind: CiliumNodeConfig
metadata:
  namespace: kube-system
  name: cilium-default
spec:
  nodeSelector:
    matchLabels:
      io.cilium.migration/cilium-default: "true"
  defaults:
    write-cni-conf-when-ready: /host/etc/cni/net.d/05-cilium.conflist
    custom-cni-conf: "false"
    cni-chaining-mode: "none"
    cni-exclusive: "true"
EOF

for NODE in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "Cordoning node $NODE (i.e., marking node as unschedulable)..."
    kubectl cordon $NODE

    if [ "$DRAIN_NODES" = "true" ]; then
        echo "Draining node $NODE..."
        kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data # --force --skip-wait-for-delete-timeout 60
    fi

    echo "Labeling node $NODE for migration..."
    kubectl label node $NODE --overwrite "io.cilium.migration/cilium-default=true"

    echo "Restarting Cilium DaemonSet..."
    kubectl -n kube-system delete pod --field-selector spec.nodeName=$NODE -l k8s-app=cilium
    kubectl -n kube-system rollout status ds/cilium -w --timeout=3600s

    echo "Validating that the node has been successfully migrated..."
    until cilium status --wait; do
        echo "Continuing to wait for Cilium to be ready..."
        sleep 5
    done
    kubectl get -o wide node $NODE
    kubectl -n kube-system run --attach --rm --restart=Never verify-network \
        --overrides='{"spec": {"nodeName": "'$NODE'", "tolerations": [{"operator": "Exists"}]}}' \
        --image ghcr.io/nicolaka/netshoot:v0.8 -- /bin/bash -c 'ip -br addr && curl -s -k https://$KUBERNETES_SERVICE_HOST/healthz && echo'

    echo "Uncordoning node $NODE..."
    kubectl uncordon $NODE
done

until cilium status --wait; do
    echo "Continuing to wait for Cilium to be ready..."
    sleep 5
done

HUBBLE_PARAMETERS=""
if [ "$ENABLE_HUBBLE_LOGGING" = "true" ]; then
    HUBBLE_PARAMETERS+="--set hubble.enabled=true"
    # HUBBLE_PARAMETERS+=" --set hubble.ui.enabled=false"
    # HUBBLE_PARAMETERS+=" --set hubble.export.static.enabled=true"
    # HUBBLE_PARAMETERS+=" --set hubble.export.static.filePath=\"/var/run/cilium/hubble/events.log\""
    # HUBBLE_PARAMETERS+=" --set hubble.export.static.fileMaxSizeMb=10"
    # HUBBLE_PARAMETERS+=" --set hubble.export.static.fileMaxBackups=10"
    # HUBBLE_PARAMETERS+=" --set hubble.export.static.fileCompress=false"
fi

cilium install --values $CILIUM_INITIAL_VALUES_FILE --dry-run-helm-values --set operator.unmanagedPodWatcher.restart=true --set cni.customConf=false --set policyEnforcementMode=default --set bpf.hostLegacyRouting=false $HUBBLE_PARAMETERS >$CILIUM_FINAL_VALUES_FILE

echo
echo "Diffing initial and final Cilium Helm values..."
diff $CILIUM_INITIAL_VALUES_FILE $CILIUM_FINAL_VALUES_FILE || true

echo
echo "Upgrading Cilium with final Helm values..."
cilium upgrade --namespace kube-system cilium cilium/cilium --values $CILIUM_FINAL_VALUES_FILE

kubectl -n kube-system rollout restart daemonset cilium
until cilium status --wait; do
    echo "Continuing to wait for Cilium to be ready..."
    sleep 5
done

if [ "$ENABLE_HUBBLE_LOGGING" = "true" ]; then
    # If command hubble doesn't exist, install hubble
    if ! command -v hubble &>/dev/null; then
        echo "Hubble command not found. Installing hubble..."
        HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
        HUBBLE_ARCH=amd64
        if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
        curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
        sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
        rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
    fi
    echo "Enabling hubble..."
    cilium hubble enable
fi

echo
echo "Deleting the per-node configuration..."
kubectl delete -n kube-system ciliumnodeconfig cilium-default

echo
echo "Migration complete. Removing previous network plugin..."

# Check for and remove conflicting VXLAN configurations
if ip link show type vxlan | grep -q "flannel.1"; then
    echo "Removing conflicting VXLAN configuration..."
    kubectl delete daemonset kube-flannel-ds -n kube-flannel
    sudo ip link delete flannel.1
    if [ -f /etc/cni/net.d/10-flannel.conflist ]; then
        sudo rm -f /etc/cni/net.d/10-flannel.conflist
    fi
    if [ -f /etc/cni/net.d/10-flannel.conf ]; then
        sudo rm -f /etc/cni/net.d/10-flannel.conf
    fi
    if [ -f /etc/cni/net.d/10-flannel.conflist.cilium_bak ]; then
        sudo rm -f /etc/cni/net.d/10-flannel.conflist.cilium_bak
    fi
    if kubectl get ds -n kube-system cilium &>/dev/null; then
        echo "Restarting Cilium DaemonSet..."
        kubectl rollout restart daemonset cilium -n kube-system
    fi
    kubectl rollout restart deployment coredns -n kube-system
fi
echo
echo "Successfully installed Cilium and migrated node to Cilium."

echo "Ensuring permissions for $USER in ~/.kube directory..."
sudo chown --recursive $USER:$USER ~/.kube

echo
echo "Deleting all existing CiliumNetworkPolicies..."
kubectl delete cnp --all-namespaces --all || true

# -----------------------------------------------------------------------------
# Applying Cilium Policy for RIC Pods
# -----------------------------------------------------------------------------

echo
echo "Writing Cilium NetworkPolicy to $CILIUM_POLICY_FILE..."
CILIUM_POLICY_FILE="$HOME/.kube/cilium-policy.yaml"
cat <<EOF | sudo tee $CILIUM_POLICY_FILE
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: isolate-xapp-communication
  namespace: ricxapp
spec:
  endpointSelector:
    matchLabels:
      "k8s:io.kubernetes.pod.namespace": ricxapp
  ingress:
    - fromEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": kube-system
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricxapp
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricplt
  egress:
    - toEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": kube-system
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricxapp
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricplt
---
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: isolate-ric-communication
  namespace: ricplt
spec:
  endpointSelector:
    matchLabels:
      "k8s:io.kubernetes.pod.namespace": ricplt
  ingress:
    - fromEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": kube-system
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricplt
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricxapp
  egress:
    - toEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": kube-system
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricplt
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": ricxapp
EOF

echo
echo "Applying Cilium NetworkPolicy..."
if ! kubectl apply -f $CILIUM_POLICY_FILE; then
    echo "Error: Failed to apply Cilium NetworkPolicy. Please check the Cilium logs for errors."
    exit 1
fi

# Prevent xApps from making modifications such as changing their labels to bypass enforcement
# If the ricxapp namespace exists, create a Role for xApp read restriction, and a RoleBinding for the default ServiceAccount
XAPP_READ_RESTRICTION_FILE="$HOME/.kube/xapp-read-restriction.yaml"
XAPP_ROLE_BINDING_FILE="$HOME/.kube/xapp-role-binding.yaml"
NAMESPACE="ricxapp"
SERVICE_ACCOUNT="default"
if kubectl get ns $NAMESPACE >/dev/null 2>&1; then
    # Create the Role if it doesn't exist
    if [ ! -f "$XAPP_READ_RESTRICTION_FILE" ]; then
        echo
        echo "Creating xApp read restriction Role file..."
        cat <<EOF | sudo tee $XAPP_READ_RESTRICTION_FILE
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: xapp-read-restriction
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF
        echo
        echo "Applying xApp read restriction Role..."
        if ! kubectl apply -f $XAPP_READ_RESTRICTION_FILE; then
            echo "Error: Failed to apply xApp read restriction Role. Check permissions and Kubernetes API connectivity."
            rm -f $XAPP_READ_RESTRICTION_FILE
            exit 1
        else
            echo "xApp read restriction Role successfully applied."
        fi
    else
        echo "xApp read restriction Role file already exists. No changes made."
    fi
    # Create the RoleBinding if it doesn't exist
    if [ ! -f "$XAPP_ROLE_BINDING_FILE" ]; then
        echo
        echo "Creating xApp RoleBinding file..."
        cat <<EOF | sudo tee $XAPP_ROLE_BINDING_FILE
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: xapp-read-restriction-binding
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: xapp-read-restriction
  apiGroup: rbac.authorization.k8s.io
EOF
        echo
        echo "Applying xApp RoleBinding..."
        if ! kubectl apply -f $XAPP_ROLE_BINDING_FILE; then
            echo "Error: Failed to apply xApp RoleBinding. Check permissions and Kubernetes API connectivity."
            rm -f $XAPP_ROLE_BINDING_FILE
            exit 1
        else
            echo "xApp RoleBinding successfully applied."
        fi
    else
        echo "xApp RoleBinding file already exists. No changes made."
    fi
else
    echo "Namespace '$NAMESPACE' does not exist, skipping Role and RoleBinding creation."
fi

if [ "$DRAIN_NODES" != "true" ]; then
    echo "Restarting deployments to apply Cilium enforcement..."
    NAMESPACES=$(kubectl get ns --no-headers | awk '{print $1}')
    # Iterate through each namespace and restart its deployments
    for NAMESPACE in $NAMESPACES; do
        DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers | awk '{print $1}')
        if [ -z "$DEPLOYMENTS" ]; then
            echo "No deployments found in namespace $NAMESPACE."
        else
            # Restart each deployment
            for DEPLOYMENT in $DEPLOYMENTS; do
                echo "Restarting deployment $DEPLOYMENT in namespace $NAMESPACE..."
                kubectl rollout restart deployment "$DEPLOYMENT" -n "$NAMESPACE"
            done
        fi
    done
else
    echo "Restarting kubelet service..."
    sudo systemctl restart kubelet
fi

until cilium status --wait; do
    echo "Continuing to wait for Cilium to be ready..."
    sleep 5
done

echo
echo
echo "################################################################################"
echo "# Successfully installed, configured, and enabled Cilium pod enforcement.      #"
echo "# If not all pods are managed by Cilium in 'cilium status' then please wait    #"
echo "# for the pods to be running, then reboot the system and check again.          #"
echo "################################################################################"

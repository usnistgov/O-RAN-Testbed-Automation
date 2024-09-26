#!/bin/bash
#
################################################################################
#   Copyright (c) 2019 AT&T Intellectual Property.                             #
#   Copyright (c) 2022 Nokia.                                                  #
#   Copyright (c) 2024 National Institute of Standards and Technology.         #
#                                                                              #
#   Licensed under the Apache License, Version 2.0 (the "License");            #
#   you may not use this file except in compliance with the License.           #
#   You may obtain a copy of the License at                                    #
#                                                                              #
#       http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                              #
#   Unless required by applicable law or agreed to in writing, software        #
#   distributed under the License is distributed on an "AS IS" BASIS,          #
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
#   See the License for the specific language governing permissions and        #
#   limitations under the License.                                             #
################################################################################

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Exit immediately if a command fails
set -e

usage() {
    echo "Usage: $0 [ -k <k8s version> -d <docker version> -e <helm version> -c <cni-version> --no-sctp-support ]" 1>&2;
    echo "Options:" 1>&2;
    echo " -k <k8s version>     Kubernetes version" 1>&2;
    echo " -c <cni version>     Kubernetes CNI version" 1>&2;
    echo " -d <docker version>  Docker version" 1>&2;
    echo " -e <helm version>    Helm version" 1>&2;
    echo " --swap-sctp-config   Tries the other syntax for SCTPSupport in the 'kubeadm init' configuration" 1>&2;
    exit 1;
}

get_latest_package_version() {
    PACKAGE_NAME=$1
    VERSION_PREFIX=$2
    # Fetch the version including the patch number (e.g., 20.10.21-0ubuntu4)
    LATEST_VERSION=$(apt-cache madison $PACKAGE_NAME | grep "$VERSION_PREFIX" | head -1 | awk '{print $3}')
    echo $LATEST_VERSION
}

get_latest_package_version_without_suffix() {
    PACKAGE_NAME=$1
    VERSION_PREFIX=$2
    FULL_VERSION=$(get_latest_package_version $PACKAGE_NAME $VERSION_PREFIX)
    # Strip off the suffix after the dash, e.g., 1.28.14-2.1 --> 1.28.14
    VERSION_WITHOUT_SUFFIX=$(echo $FULL_VERSION | cut -d'-' -f1)
    echo $VERSION_WITHOUT_SUFFIX
}

get_latest_docker_version() {
    VERSION_PREFIX=$1
    # Get the full Docker version, falling back to any available version if needed
    LATEST_VERSION=$(apt-cache madison docker.io | grep "$VERSION_PREFIX" | head -1 | awk '{print $3}')
    
    # Fallback if no version is found
    if [[ -z "$LATEST_VERSION" ]]; then
        LATEST_VERSION=$(apt-cache madison docker.io | head -1 | awk '{print $3}')
    fi
    echo $LATEST_VERSION
}

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

        echo "Currently, $ACTUAL_COUNT/$EXPECTED_COUNT pods are in the desired state in namespace '$NAMESPACE'."
        
        if [[ "$ACTUAL_COUNT" -ge "$EXPECTED_COUNT" ]]; then
            echo "Required pod count reached in namespace '$NAMESPACE'."
            break
        fi

        sleep 5
    done
}

start_ipv6_if () {
    IPv6IF="$1"
    if ip addr show "$IPv6IF" &> /dev/null; then
        # Ensure the directory exists
        mkdir -p /etc/network/interfaces.d
        # Check if the interface is already configured
        if ! grep -q "${IPv6IF}" /etc/network/interfaces.d/50-cloud-init.cfg; then
            echo "" >> /etc/network/interfaces.d/50-cloud-init.cfg
            echo "allow-hotplug ${IPv6IF}" >> /etc/network/interfaces.d/50-cloud-init.cfg
            echo "iface ${IPv6IF} inet6 auto" >> /etc/network/interfaces.d/50-cloud-init.cfg
        fi
        ip link set "${IPv6IF}" up
    fi
}


# -----------------------------------------------------------------------------
# Installation of prerequisites
# -----------------------------------------------------------------------------
echo "Installing prerequisites..."
apt-get update
apt-get install -y curl wget gnupg2 software-properties-common lsb-release net-tools iproute2 iputils-ping
# Install 'modprobe' if not present (usually part of 'kmod')
apt-get install -y kmod
apt-get install -y gawk sed
apt-get install -y iptables
apt-get install -y socat
apt-get install -y libsctp1 lksctp-tools

#KUBEV="1.28.11"
#KUBECNIV="0.7.5"
#HELMV="3.14.4"
#DOCKERV="20.10.21"

# The version will be dynamically completed rather than hardcoding in the version
KUBEV="1.28"
KUBECNIV="0.7"
HELMV="3.14"
DOCKERV="20.10"

# Fetch the Ubuntu release version regardless of the derivative distro
if [ -f /etc/upstream-release/lsb-release ]; then
    UBUNTU_RELEASE=$(cat /etc/upstream-release/lsb-release | grep 'DISTRIB_RELEASE' | sed 's/.*=\s*//')
else
    UBUNTU_RELEASE=$(lsb_release -sr)
fi

# Set the default DOCKERV for Ubuntu 24.*
if [[ ${UBUNTU_RELEASE} == 24.* ]]; then
    DOCKERV="24.0"
fi

# Parsing command-line options
SWAP_SCTP_CONFIG="false"
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -k) KUBEV="$2"; shift ;;
        -d) DOCKERV="$2"; shift ;;
        -e) HELMV="$2"; shift ;;
        -c) KUBECNIV="$2"; shift ;;
        --swap-sctp-config)
            SWAP_SCTP_CONFIG="true"
            echo "Found --swap-sctp-config: Trying other syntax for SCTPSupport."
            ;;
        *) usage ;;
    esac
    shift
done

if [[ ${HELMV} == 2.* ]]; then
    echo "helm 2 ("${HELMV}") not supported anymore"
    exit -1
fi

set -x
export DEBIAN_FRONTEND=noninteractive
# Add hostname to /etc/hosts if not already present
HOST_ENTRY="$(hostname -I | awk '{print $1}') $(hostname)"
if ! grep -q "$(hostname)" /etc/hosts; then
    echo "$HOST_ENTRY" >> /etc/hosts
fi

printenv

IPV6IF=""

# Check for internet connectivity
if ping -c 1 8.8.8.8 &> /dev/null; then
    PUBLIC_IP=$(curl -s ifconfig.co)
else
    echo "No internet connectivity detected. Cannot retrieve public IP."
    PUBLIC_IP="0.0.0.0"
fi

rm -rf /opt/config
mkdir -p /opt/config
echo "" > /opt/config/docker_version.txt
echo "1.16.0" > /opt/config/k8s_version.txt
echo "0.7.5" > /opt/config/k8s_cni_version.txt
echo "3.14.4" > /opt/config/helm_version.txt
echo "$(hostname -I)" > /opt/config/host_private_ip_addr.txt
echo "$PUBLIC_IP" > /opt/config/k8s_mst_floating_ip_addr.txt
echo "$(hostname -I)" > /opt/config/k8s_mst_private_ip_addr.txt
echo "__mtu__" > /opt/config/mtu.txt
echo "__cinder_volume_id__" > /opt/config/cinder_volume_id.txt
echo "$(hostname)" > /opt/config/stack_name.txt

ISAUX='false'
if [[ $(cat /opt/config/stack_name.txt) == *aux* ]]; then
    ISAUX='true'
fi

# Load IP Virtual Server (IPVS) modules
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh

# Load SCTP module
modprobe sctp

# Conditional loading of connection tracking modules based on kernel version
KERNEL_VERSION=$(uname -r)
if [[ "$KERNEL_VERSION" < "5.0" ]]; then
    # For older kernels (before version 5), load IPv4 and IPv6 specific modules
    modprobe nf_conntrack_ipv4
    modprobe nf_conntrack_ipv6
    modprobe nf_conntrack_proto_sctp
else
    # For newer kernels (version 5 and later), use the unified nf_conntrack module
    modprobe nf_conntrack
fi

if [ ! -z "$IPV6IF" ]; then
    start_ipv6_if "$IPV6IF"
fi

# Kubelet does not support swap. Disable traditional swap entries in /etc/fstab:
echo "Checking for traditional swap in /etc/fstab..."
SWAPFILES=$(grep swap /etc/fstab | sed '/^[ \t]*#/ d' | sed 's/[\t ]/ /g' | tr -s " " | cut -f1 -d' ')
if [ ! -z "$SWAPFILES" ]; then
    for SWAPFILE in $SWAPFILES
    do
        if [ ! -z "$SWAPFILE" ]; then
            echo "Disabling swap file $SWAPFILE"
            if [[ $SWAPFILE == UUID* ]]; then
                UUID=$(echo "$SWAPFILE" | cut -f2 -d'=')
                swapoff -U "$UUID"
            else
                swapoff "$SWAPFILE"
            fi
            sed -i "\%$SWAPFILE%d" /etc/fstab
        fi
    done
else
    echo "No traditional swap entries found in /etc/fstab."
fi

# Disable zram swap
echo "Checking for zram swap devices..."
ZRAM_DEVICES=$(swapon --show=NAME,TYPE | grep partition | grep zram | cut -d' ' -f1)
if [ ! -z "$ZRAM_DEVICES" ]; then
    for ZRAM in $ZRAM_DEVICES
    do
        # Handle case where device path might already include '/dev/'
        ZRAM_DEVICE_PATH=$(echo "$ZRAM" | grep -q "^/dev/" && echo "$ZRAM" || echo "/dev/$ZRAM")
        echo "Disabling zram device $ZRAM_DEVICE_PATH"
        swapoff "$ZRAM_DEVICE_PATH"
    done
    # Disable zram services if they exist
    systemctl list-units --type=service | grep zram | cut -d' ' -f1 | while read -r service; do
        echo "Disabling zram service $service"
        systemctl disable --now "$service"
    done
else
    echo "No zram devices currently active."
fi
# Running this should now return nothing: swapon --show


echo "### Docker version  = "${DOCKERV}
echo "### k8s version     = "${KUBEV}
echo "### helm version    = "${HELMV}
echo "### k8s cni version = "${KUBECNIV}

echo
echo "Updating Kubernetes keyring..."
mkdir -p /etc/apt/keyrings
KUBE_REPO_VERSION="1.28"  # Modify this as necessary
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_REPO_VERSION}/deb/Release.key | gpg --dearmor | tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_REPO_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

echo
echo "Updating Helm keyring..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /etc/apt/keyrings/helm-apt-keyring.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/helm-apt-keyring.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

# If this errors then remove Kubernetes with: sudo rm /etc/apt/sources.list.d/kubernetes.list
# If this errors then remove Helm with: sudo rm /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update

# Dynamically fetch the latest versions based on the available packages
DOCKERVERSION=$(get_latest_docker_version "${DOCKERV}")
KUBEVERSION=$(get_latest_package_version "kubeadm" "${KUBEV}")
CNIVERSION=$(get_latest_package_version "kubernetes-cni" "${KUBECNIV}")
HELMVERSION=$(get_latest_package_version "helm" "${HELMV}")

if [ -z "${DOCKERVERSION}" ]; then
    echo "No Docker version found, exiting..."
    exit 1
fi
if [ -z "${KUBEVERSION}" ]; then
    echo "No Kubernetes version found for prefix ${KUBEV}. Trying latest available version."
    KUBEVERSION=$(apt-cache madison kubeadm | head -1 | awk '{print $3}')
fi
if [ -z "${CNIVERSION}" ]; then
    echo "No Kubernetes CNI version found for prefix ${KUBECNIV}. Trying latest available version."
    CNIVERSION=$(apt-cache madison kubernetes-cni | head -1 | awk '{print $3}')
fi
if [ -z "${HELMVERSION}" ]; then
    echo "No Helm version found for prefix ${HELMV}. Trying latest available version."
    HELMVERSION=$(apt-cache madison helm | head -1 | awk '{print $3}')
fi

echo
echo
echo "Docker version: ${DOCKERVERSION}"
echo "Kubernetes version: ${KUBEVERSION}"
echo "Helm version: ${HELMVERSION}"
echo "Kubernetes CNI version: ${CNIVERSION}"
echo
echo

mkdir -p /etc/apt/apt.conf.d
echo "APT::Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries

# Wait for dpkg lock to be released by directly checking in the loop
until dpkg --configure -a > /dev/null 2>&1; do
    echo "Waiting for other software managers to release the dpkg lock..."
    sleep 5
done

apt-get update
apt-get install -y curl jq netcat-openbsd make ipset moreutils

APTOPTS="--allow-downgrades --allow-change-held-packages --allow-unauthenticated --ignore-hold "


# -----------------------------------------------------------------------------
# Docker uninstallation then clean installation
# -----------------------------------------------------------------------------

echo
echo
echo "Stopping and removing existing Docker installations, then installing Docker $DOCKERVERSION..."
if systemctl is-active --quiet docker.socket; then
    systemctl stop docker.socket
fi
if systemctl is-active --quiet docker.service; then
    systemctl stop docker.service
fi
if systemctl is-enabled --quiet docker.socket; then
    systemctl disable docker.socket
fi
if systemctl is-enabled --quiet docker.service; then
    systemctl disable docker.service
fi

# Uninstall Docker packages and clean up
apt-get purge -y --allow-change-held-packages docker docker-engine docker.io containerd runc || true
rm -rf /var/lib/docker /etc/docker
apt-get autoremove -y

# Install Docker with the specified or latest available version
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    apt-get install -y $APTOPTS "docker.io=$DOCKERVERSION"
fi

# Configure Docker daemon
echo "Configuring Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Validate Docker configuration (skip validation if dockerd does not support it)
if dockerd --help | grep --quiet -- "--validate"; then
    if ! dockerd --config-file=/etc/docker/daemon.json --validate; then
        echo "Invalid Docker configuration detected."
        exit 1
    else
        echo "Docker configuration is valid."
    fi
else
    echo "Skipping Docker configuration validation (unsupported flag)."
fi

# Enable and attempt to start Docker service with retries
echo "Enabling and starting Docker service..."
systemctl daemon-reload
systemctl enable docker
ATTEMPT=0
MAX_ATTEMPTS=5
while ! systemctl restart docker && [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Docker failed to start. Attempt $((ATTEMPT+1))/$MAX_ATTEMPTS..."
    echo "Checking service status..."
    systemctl status docker.service | grep -A 2 "Active:"
    echo "Reviewing recent logs..."
    journalctl -xeu docker.service | tail -20
    sleep 10
    ((ATTEMPT++))
done

if ! systemctl is-active --quiet docker; then
    echo "Failed to start Docker after $MAX_ATTEMPTS attempts."
    exit 1
else
    echo "Docker started successfully."
fi


# -----------------------------------------------------------------------------
# Kubernetes uninstallation then clean installation
# -----------------------------------------------------------------------------

echo
echo
echo "Stopping and removing existing Kubernetes installations..."

# Stop all Docker containers if Docker is installed
if command -v docker &> /dev/null; then
    echo "Removing existing Docker containers..."
    docker ps -aq | xargs -r docker stop
    docker ps -aq | xargs -r docker rm
fi

# Stop kubelet service if it's running
if systemctl is-active --quiet kubelet; then
    echo "Stopping kubelet service..."
    systemctl stop kubelet
    systemctl disable kubelet
    echo "kubelet service stopped and disabled."
fi

# Free ports 6443, 10250, 10257, 10259, 2379, 2380, 6443 (identify the process with sudo ss -tulpn | grep :PORTNUMBER)
# systemctl stop kube-apiserver kube-controller-manager kube-scheduler etcd || true
echo "y" | kubeadm reset || true
if [ ! -z "$(docker ps -a -q)" ]; then
    docker stop $(docker ps -a -q)
    docker rm $(docker ps -a -q)
fi
pkill -9 kubelet || true
pkill -9 kube-control || true
pkill -9 kube-schedul || true
pkill -9 kube-apiserver || true
pkill -9 etcd || true
pkill -9 etcd || true
pkill -9 etcd || true


# Reset Kubernetes using kubeadm if kubeadm is installed
if command -v kubeadm &> /dev/null; then
    # Reset Kubernetes using kubeadm
    echo "Resetting Kubernetes..."
    kubeadm reset -f --ignore-preflight-errors=all
    echo "Kubernetes reset successfully."
fi

# Clean up Kubernetes directories
rm -rf /etc/cni/net.d /etc/kubernetes/ /root/.kube/ /var/lib/etcd /var/lib/kubelet

# Remove all Kubernetes-related Docker or containerd images
if command -v docker &> /dev/null; then
    echo "Removing all Docker images..."
    docker rmi $(docker images -q) 2>/dev/null || true
fi

# Reset iptables
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
iptables -t nat -X
iptables -t mangle -X
echo "System cleaned up."


echo "Reinstalling Kubernetes..."
KUBEVERSIONWITHOUTSUFFIX=$(get_latest_package_version_without_suffix "kubeadm" "${KUBEV}")
echo "Kubernetes version without suffix: $KUBEVERSIONWITHOUTSUFFIX"

# Install Kubernetes components
if [ -z "${CNIVERSION}" ]; then
    apt-get install -y kubernetes-cni
else
    apt-get install -y kubernetes-cni=${CNIVERSION}
fi

if [ -z "${KUBEVERSION}" ]; then
    apt-get install -y kubeadm kubelet kubectl
else
    apt-get install -y kubeadm=${KUBEVERSION} kubelet=${KUBEVERSION} kubectl=${KUBEVERSION}
fi

apt-mark hold docker.io kubernetes-cni kubelet kubeadm kubectl

# Enable kubelet without starting it immediately
systemctl enable kubelet

# Pull required images for Kubernetes
kubeadm config images pull --kubernetes-version=${KUBEVERSIONWITHOUTSUFFIX}

echo "Kubernetes components reinstalled and ready for initialization."

SCTP_SUPPORT_1="apiServer:
  extraArgs:
    feature-gates: SCTPSupport=true"
SCTP_SUPPORT_2="apiServerExtraArgs:
  feature-gates: SCTPSupport=true"

# Swap the two syntax styles
if [ "${SWAP_SCTP_CONFIG}" = "true" ]; then
    TEMP="$SCTP_SUPPORT_1"
    SCTP_SUPPORT_1="$SCTP_SUPPORT_2"
    SCTP_SUPPORT_2="$TEMP"
fi

NODETYPE="master"
if [ "$NODETYPE" == "master" ]; then # MASTER_NODE_COND

if [[ ${KUBEVERSION} == 1.13.* ]]; then
    cat <<EOF > /root/config.yaml
apiVersion: kubeadm.k8s.io/v1alpha3
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
$SCTP_SUPPORT_1
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
    elif [[ ${KUBEVERSION} == 1.14.* ]]; then
    cat <<EOF > /root/config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
$SCTP_SUPPORT_1
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
    elif [[ ${KUBEVERSION} == 1.15.* ]] || [[ ${KUBEVERSION} == 1.16.* ]] || [[ ${KUBEVERSION} == 1.18.* ]]; then
    cat <<EOF > /root/config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
$SCTP_SUPPORT_2
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
    
    elif [[ ${KUBEVERSION} == 1.28.* ]] ; then
    cat <<EOF > /root/config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
$SCTP_SUPPORT_2
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
else
    echo "Unsupported Kubernetes version requested ($KUBEVERSION).  Bail."
    exit 1
fi
# Address 10.244.0.0/16 is the same one Flannel uses

echo "Configuring Flannel CNI configurations..."
mkdir -p /etc/cni/net.d
cat <<EOF > /etc/cni/net.d/10-flannel.conflist
{
    "cniVersion": "0.4.0",
    "name": "flannel",
    "plugins": [
        {
            "type": "flannel",
            "delegate": {
                "hairpinMode": true,
                "isDefaultGateway": true
            }
        },
        {
            "type": "portmap",
            "capabilities": {
                "portMappings": true
            }
        }
    ]
}
EOF


echo "Configuring RBAC for Helm (Tiller)..."
cat <<EOF > /root/rbac-config.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: kube-system
EOF

echo "Configuring Kube-Proxy ClusterRoleBinding..."
cat <<EOF > /root/kube-proxy-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-proxy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:node-proxier
subjects:
- kind: ServiceAccount
  name: kube-proxy
  namespace: kube-system
EOF

# Ensure configurations are set for containerd
mkdir -p /etc/containerd
cat <<EOF > /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
  [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]
    PodSandboxImage = "registry.k8s.io/pause:3.9"
EOF
systemctl restart containerd

kubeadm init --config /root/config.yaml --v=5

# Set KUBECONFIG
export KUBECONFIG=/etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/environment

mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config


# Wait for kube-apiserver to be ready
sleep 1
until kubectl get pods --all-namespaces; do
    echo "Waiting for API server to be available..."
    sudo crictl ps -a
    sleep 8
done

kubectl get pods --all-namespaces || true

echo "Applying Flannel CNI..."
if [[ ${KUBEVERSION} == 1.28.* ]]; then
    # Apply the latest Flannel configuration for Kubernetes version 1.28 and above
    if ! kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"; then
        echo "Failed to apply Flannel configuration."
        exit 1
    fi
else
    # Use a specific Flannel version for other Kubernetes versions, refer to version 0.18.1
    # We refer to version 0.18.1 because later versions use namespace kube-flannel instead of kube-system TODO
    if ! kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/v0.18.1/Documentation/kube-flannel.yml"; then
        echo "Failed to apply Flannel configuration."
        exit 1
    fi
fi

if ! kubectl apply -f "/root/rbac-config.yaml"; then
    echo "Failed to apply RBAC for Helm (Tiller), skipping."
fi

if ! kubectl apply -f "/root/kube-proxy-rbac.yaml"; then
    echo "Failed to apply Kube-Proxy ClusterRoleBinding, skipping."
fi

# Resource metrics enable commands like: kubectl top pod [pod_name] -n [namespace]
if ! kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"; then
    echo "Failed to apply optional resource metrics, skipping."
fi

# Create local-storage storage class
cat <<EOF > /root/local-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
echo "Local storage class configuration file created."

# Apply the local-storage storage class
if ! kubectl apply -f "/root/local-storage-class.yaml"; then
    echo "Failed to apply local storage class, skipping."
fi

# Check for node readiness for conditional taint removal
echo "Waiting for essential system pods to be ready..."
if [[ ${KUBEVERSION} == 1.28.* ]]; then
    wait_for_pods_running 7 kube-system
    wait_for_pods_running 1 kube-flannel
    echo "Removing taints from control-plane..."
    kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule- node-role.kubernetes.io/control-plane:NoSchedule- || echo "Taint node-role.kubernetes.io/control-plane:NoSchedule not found."
else
    wait_for_pods_running 8 kube-system
    echo "Removing taints from master..."
    kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule- node-role.kubernetes.io/master- || echo "Taint node-role.kubernetes.io/master not found."
fi

echo "Kubernetes installed successfully."


# -----------------------------------------------------------------------------
# Helm installation
# -----------------------------------------------------------------------------

HELMVERSIONWITHOUTSUFFIX=$(get_latest_package_version_without_suffix "helm" "${HELMV}")

echo
echo
echo "Installing Helm ${HELMVERSIONWITHOUTSUFFIX}..."

# Create a temporary directory for the Helm installation process
TEMP_DIR=$(mktemp -d)

# Download the Helm tarball if not already present
if [ ! -e "${TEMP_DIR}/helm-v${HELMVERSIONWITHOUTSUFFIX}-linux-amd64.tar.gz" ]; then
    wget -P "${TEMP_DIR}" "https://get.helm.sh/helm-v${HELMVERSIONWITHOUTSUFFIX}-linux-amd64.tar.gz"
fi

# Extract Helm and move it to /usr/local/bin
tar -xvf "${TEMP_DIR}/helm-v${HELMVERSIONWITHOUTSUFFIX}-linux-amd64.tar.gz" -C "${TEMP_DIR}"
mv "${TEMP_DIR}/linux-amd64/helm" /usr/local/bin/helm
chmod +x /usr/local/bin/helm

# Clean up temporary directory
rm -rf "${TEMP_DIR}"

# Remove any old Helm configurations
rm -rf "$HOME/.helm"

while ! helm version; do
    echo "Waiting for Helm to be ready"
    sleep 15
done

echo "Preparing a master node (lower ID) for using local FS for PV"

if [[ ${KUBEVERSION} == 1.28.* ]]; then
    # Use 'control-plane' for Kubernetes version 1.28 and above
    PV_NODE_NAME=$(kubectl get nodes --selector='node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
else
    # Use 'master' for older Kubernetes versions
    PV_NODE_NAME=$(kubectl get nodes | grep master | awk '{print $1}' | sort | head -1)
fi

# Check if the PV_NODE_NAME is set to avoid errors
if [ -z "$PV_NODE_NAME" ]; then
    echo "Error: Unable to determine the node name."
    exit 1
fi

kubectl label --overwrite nodes "$PV_NODE_NAME" local-storage=enable

if [ "$PV_NODE_NAME" == "$(hostname)" ]; then
    mkdir -p /opt/data/dashboard-data
    chmod -R 755 /opt/data/dashboard-data
fi

echo "Done with master node setup"
fi # MASTER_NODE_COND

# If HELM_REPO_HOST is set, add it to /etc/hosts
HELM_REPO_HOST="helm.ricinfra.local"

if [[ ! -z "$HELM_REPO_HOST" ]]; then
    if ! grep -q "$HELM_REPO_HOST" /etc/hosts; then
        echo "127.0.0.1 $HELM_REPO_HOST" >> /etc/hosts
    fi
fi

echo "Script completed successfully."

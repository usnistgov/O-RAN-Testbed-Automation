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

# Echo every command as it is ran
set -x

usage() {
    echo "Usage: $0 [ -k <k8s version> -d <docker version> -e <helm version> -c <cni-version> --no-sctp-support ]" 1>&2;
    echo "Options:" 1>&2;
    echo " -k <k8s version>     Kubernetes version" 1>&2;
    echo " -c <cni version>     Kubernetes CNI version" 1>&2;
    echo " -d <docker version>  Docker version" 1>&2;
    echo " -e <helm version>    Helm version" 1>&2;
    exit 1;
}

MAIN_DIR=$(pwd)
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}')
IP_ADDRESS=$(ip -f inet addr show $PRIMARY_INTERFACE | grep -Po 'inet \K[\d.]+')
HOSTNAME=$(hostname)

get_latest_package_version() {
    PACKAGE_NAME=$1
    VERSION_PREFIX=$2
    # Fetch the version including the patch number (e.g., 20.10.21-0ubuntu4)
    LATEST_VERSION=$(apt-cache madison $PACKAGE_NAME | grep "$VERSION_PREFIX" | head -1 | awk '{print $3}')
    echo $LATEST_VERSION
}

remove_version_suffix() {
    FULL_VERSION=$1
    # Strip off the suffix after the dash, e.g., 1.28.14-2.1 --> 1.28.14
    VERSION_WITHOUT_SUFFIX=$(echo $FULL_VERSION | cut -d'-' -f1)
    echo $VERSION_WITHOUT_SUFFIX
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

        echo "Currently, $ACTUAL_COUNT/$EXPECTED_COUNT pods are in the desired state in namespace $NAMESPACE."

        if [[ "$ACTUAL_COUNT" -ge "$EXPECTED_COUNT" ]]; then
            echo "Required pod count reached in namespace '$NAMESPACE'."
            break
        fi

        sleep 5
    done
}

# -----------------------------------------------------------------------------
# Installation of prerequisites
# -----------------------------------------------------------------------------
sudo mkdir -p /etc/apt/apt.conf.d
echo "APT::Acquire::Retries \"3\";" | sudo tee /etc/apt/apt.conf.d/80-retries > /dev/null

# Wait for dpkg lock to be released by directly checking in the loop
until sudo dpkg --configure -a > /dev/null 2>&1; do
    echo "Waiting for other software managers to release the dpkg lock..."
    sleep 5
done

echo "Installing prerequisites..."
sudo apt-get update || true
sudo apt-get install -y curl wget gnupg2 software-properties-common lsb-release net-tools iproute2 iputils-ping
sudo apt-get install -y kmod # Part of 'kmod'
sudo apt-get install -y gawk sed
sudo apt-get install -y iptables
sudo apt-get install -y ipvsadm
sudo apt-get install -y socat
sudo apt-get install -y libsctp1 lksctp-tools

# Previous versions from original script (HELMV 3.14.X causes continuous APIServer crashing on Ubuntu 22):
#KUBEV="1.28" #.11"
#KUBECNIV="0.7" #.5"
#HELMV="3.14" #.4"
#DOCKERV="20.10" #.21"

# The version will be dynamically completed rather than hardcoding in the version
KUBEV="1.29"
KUBECNIV="0.7"
HELMV="3.5"
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
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -k) KUBEV="$2"; shift ;;
        -d) DOCKERV="$2"; shift ;;
        -e) HELMV="$2"; shift ;;
        -c) KUBECNIV="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

if [[ ${HELMV} == 2.* ]]; then
    echo "helm 2 ("${HELMV}") not supported anymore"
    exit -1
fi

export DEBIAN_FRONTEND=noninteractive

# Update /etc/hosts to include the user's IP address
# Check if the IP address and hostname are not empty
if [ -z "$IP_ADDRESS" ] || [ -z "$HOSTNAME" ]; then
    echo "Error: IP address or hostname is empty. Exiting script."
    exit 1
fi
# Remove existing entries for the hostname from /etc/hosts
sudo sed -i "/$HOSTNAME/d" /etc/hosts
# Add the new entry to /etc/hosts
echo "$IP_ADDRESS $HOSTNAME" | sudo tee -a /etc/hosts

#printenv

echo "### Docker version  = "${DOCKERV}
echo "### k8s version     = "${KUBEV}
echo "### helm version    = "${HELMV}
echo "### k8s cni version = "${KUBECNIV}

echo
echo "Updating Kubernetes keyring..."
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBEV}/deb/Release.key | gpg --dearmor | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg > /dev/null
sudo echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBEV}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo
echo "Updating Helm keyring..."
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/helm-apt-keyring.gpg > /dev/null
sudo echo "deb [signed-by=/etc/apt/keyrings/helm-apt-keyring.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# If this errors you can remove Kubernetes with: sudo rm /etc/apt/sources.list.d/kubernetes.list
# If this errors you can remove Helm with: sudo rm /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update

APTOPTS="--allow-downgrades --allow-change-held-packages --allow-unauthenticated --ignore-hold "

# Dynamically fetch the latest versions based on the available packages
DOCKERVERSION=$(get_latest_package_version "docker.io" "${DOCKERV}")
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

DOCKERVERSIONWITHOUTSUFFIX=$(remove_version_suffix "${DOCKERVERSION}")
KUBEVERSIONWITHOUTSUFFIX=$(remove_version_suffix "${KUBEVERSION}")
CNIVERSIONWITHOUTSUFFIX=$(remove_version_suffix "${CNIVERSION}")
HELMVERSIONWITHOUTSUFFIX=$(remove_version_suffix "${HELMVERSION}")

echo
echo
echo "Docker version: ${DOCKERVERSION}"
echo "Kubernetes version: ${KUBEVERSION}"
echo "Helm version: ${HELMVERSION}"
echo "Kubernetes CNI version: ${CNIVERSION}"
echo
echo "Docker version without suffix: ${DOCKERVERSIONWITHOUTSUFFIX}"
echo "Kubernetes version without suffix: ${KUBEVERSIONWITHOUTSUFFIX}"
echo "Helm version without suffix: ${HELMVERSIONWITHOUTSUFFIX}"
echo "Kubernetes CNI version without suffix: ${CNIVERSIONWITHOUTSUFFIX}"
echo
echo

# Check for internet connectivity
if ping -c 1 8.8.8.8 &> /dev/null; then
    PUBLIC_IP=$(curl -s ifconfig.co)
else
    echo "No internet connectivity detected. Cannot retrieve public IP."
    PUBLIC_IP="0.0.0.0"
fi

sudo rm -rf /opt/config
sudo mkdir -p /opt/config
sudo chown $USER:$USER /opt/config
sudo chmod 755 /opt/config
echo "$DOCKERVERSIONWITHOUTSUFFIX" > /opt/config/docker_version.txt
echo "$KUBEVERSIONWITHOUTSUFFIX" > /opt/config/k8s_version.txt
echo "$CNIVERSIONWITHOUTSUFFIX" > /opt/config/k8s_cni_version.txt
echo "$HELMVERSIONWITHOUTSUFFIX" > /opt/config/helm_version.txt
echo "$IP_ADDRESS" > /opt/config/host_private_ip_addr.txt
echo "$PUBLIC_IP" > /opt/config/k8s_mst_floating_ip_addr.txt
echo "$HOSTNAME" > /opt/config/k8s_mst_private_ip_addr.txt
echo "__mtu__" > /opt/config/mtu.txt
echo "__cinder_volume_id__" > /opt/config/cinder_volume_id.txt
echo "$HOSTNAME" > /opt/config/stack_name.txt

ISAUX='false'
if [[ $(cat /opt/config/stack_name.txt) == *aux* ]]; then
    ISAUX='true'
fi

# Load necessary kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Load IP Virtual Server (IPVS) modules
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh

# Load SCTP module
sudo modprobe sctp

# Get the kernel major version
KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
MAJOR_VERSION=$(echo $KERNEL_VERSION | cut -d'.' -f1)

# Conditional loading of connection tracking modules based on kernel version
if [ "$MAJOR_VERSION" -lt 5 ]; then
    # For older kernels (before version 5), load IPv4 and IPv6 specific modules
    sudo modprobe nf_conntrack_ipv4
    sudo modprobe nf_conntrack_ipv6
    sudo modprobe nf_conntrack_proto_sctp
else
    # For newer kernels (version 5 and later), use the unified nf_conntrack module
    sudo modprobe nf_conntrack
fi

# Ensure modules are loaded on boot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
sctp
EOF

# Add connection tracking modules to /etc/modules-load.d/k8s.conf based on kernel version
if [ "$MAJOR_VERSION" -lt 5 ]; then
    cat <<EOF | sudo tee -a /etc/modules-load.d/k8s.conf
nf_conntrack_ipv4
nf_conntrack_ipv6
nf_conntrack_proto_sctp
EOF
else
    echo "nf_conntrack" | sudo tee -a /etc/modules-load.d/k8s.conf
fi

# Set required sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

cat <<EOF | sudo tee /etc/sysctl.d/ipvs.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
EOF

# Apply sysctl parameters
sudo sysctl --system

# Kubelet does not support swap. Disable traditional swap entries in /etc/fstab:
echo "Checking for traditional swap in /etc/fstab..."
SWAPFILES=$(grep swap /etc/fstab | sed '/^[ \t]*#/ d' | sed 's/[\t ]/ /g' | tr -s " " | cut -f1 -d' ')
if [ ! -z "$SWAPFILES" ]; then
    for SWAPFILE in $SWAPFILES; do
        if [ ! -z "$SWAPFILE" ]; then
            echo "Disabling swap file $SWAPFILE"
            if [[ $SWAPFILE == UUID* ]]; then
                UUID=$(echo "$SWAPFILE" | cut -f2 -d'=')
                sudo swapoff -U "$UUID"
            else
                sudo swapoff "$SWAPFILE"
            fi
            sudo sed -i "\%$SWAPFILE%d" /etc/fstab
        fi
    done
else
    echo "No traditional swap entries found in /etc/fstab."
fi
# Disable zram swap
echo "Checking for zram swap devices..."
ZRAM_DEVICES=$(sudo swapon --show=NAME,TYPE | grep partition | grep zram | cut -d' ' -f1)
if [ ! -z "$ZRAM_DEVICES" ]; then
    for ZRAM in $ZRAM_DEVICES; do
        # Handle case where device path might already include '/dev/'
        ZRAM_DEVICE_PATH=$(echo "$ZRAM" | grep -q "^/dev/" && echo "$ZRAM" || echo "/dev/$ZRAM")
        echo "Disabling zram device $ZRAM_DEVICE_PATH"
        sudo swapoff "$ZRAM_DEVICE_PATH"
    done
    # Disable zram services if they exist
    systemctl list-units --type=service | grep zram | cut -d' ' -f1 | while read -r service; do
        echo "Disabling zram service $service"
        sudo systemctl disable --now "$service"
    done
else
    echo "No zram devices currently active."
fi

echo "Verifying swap is disabled..."
if sudo swapon --show | grep -q 'swap'; then
    echo "Warning: Swap is still active."
    sudo swapon --show
else
    echo "All swap has been successfully disabled."
fi

sudo apt-get update
sudo apt-get install -y curl jq netcat-openbsd make ipset moreutils

# -----------------------------------------------------------------------------
# Docker uninstallation then clean installation
# -----------------------------------------------------------------------------

echo
echo
echo "Stopping and removing existing Docker installations, then installing Docker $DOCKERVERSION..."
if sudo systemctl is-active --quiet docker.socket; then
    sudo systemctl stop docker.socket
fi
if sudo systemctl is-active --quiet docker.service; then
    sudo systemctl stop docker.service
fi
if sudo systemctl is-enabled --quiet docker.socket; then
    sudo systemctl disable docker.socket
fi
if sudo systemctl is-enabled --quiet docker.service; then
    sudo systemctl disable docker.service
fi

# Uninstall Docker packages and clean up
sudo apt-get purge -y --allow-change-held-packages docker docker-engine docker.io containerd runc || true
sudo rm -rf /var/lib/docker /etc/docker
sudo apt-get autoremove -y

# Install Docker with the specified or latest available version
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    sudo apt-get install -y $APTOPTS "docker.io=$DOCKERVERSION"
fi

# Configure Docker daemon
echo "Configuring Docker daemon..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
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
    if ! sudo dockerd --config-file=/etc/docker/daemon.json --validate; then
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
sudo systemctl daemon-reload
sudo systemctl enable docker
ATTEMPT=0
MAX_ATTEMPTS=5
while ! sudo systemctl restart docker && [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Docker failed to start. Attempt $((ATTEMPT+1))/$MAX_ATTEMPTS..."
    echo "Checking service status..."
    sudo systemctl status docker.service | grep -A 2 "Active:"
    echo "Reviewing recent logs..."
    journalctl -xeu docker.service | tail -20
    sleep 10
    ((ATTEMPT++))
done

if ! sudo systemctl is-active --quiet docker; then
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

# Stop and remove all Docker containers if Docker is installed
if command -v docker &> /dev/null; then
    echo "Stopping and removing existing Docker containers..."
    if [ "$(sudo docker ps -aq)" ]; then
        sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
        sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
    else
        echo "No Docker containers to stop or remove."
    fi
fi

# Stop, disable, and mask kubelet service if it's running
if sudo systemctl is-active --quiet kubelet; then
    echo "Stopping, disabling, and masking kubelet service..."
    sudo systemctl stop kubelet
    sudo systemctl disable kubelet
    sudo systemctl mask kubelet
    echo "kubelet service stopped, disabled, and masked."
fi

# Reset Kubernetes using kubeadm if kubeadm is installed
if command -v kubeadm &> /dev/null; then
    echo "Resetting Kubernetes..."
    echo "y" | sudo kubeadm reset -f
    echo "Kubernetes reset successfully."
fi

# Stop Kubernetes services using systemd
services=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "Stopping $service..."
        sudo systemctl stop $service || true
    else
        echo "$service is not active."
    fi
done

# Stop and remove Docker containers if Docker is used
if [ ! -z "$(sudo docker ps -a -q)" ]; then
    sudo docker stop $(sudo docker ps -a -q) || true
    sudo docker rm $(sudo docker ps -a -q) || true
fi

# Kill stubborn Kubernetes processes more carefully
processes=("kubelet" "kube-control" "kube-schedul" "kube-apiserver" "etcd")
for process in "${processes[@]}"; do
    while pgrep $process > /dev/null; do
        echo "Terminating $process..."
        sudo pkill -9 $process || true
        sleep 1
    done
done

# Check and free ports, check which process is using a port with: ss -tulpn | grep :PORTNUMBER
ports=(6443 10250 10257 10259 2379 2380)
for port in "${ports[@]}"; do
    if sudo ss -tulpn | grep ":$port" > /dev/null; then
        echo "Freeing port $port..."
        sudo fuser -k $port/tcp || true
    fi
done

# Clean up Kubernetes directories
sudo find /var/lib/kubelet -type d -exec umount {} \; 2>/dev/null || true
sudo ipvsadm --clear || true
sudo rm -rf /etc/cni/net.d || true
sudo rm -rf /etc/kubernetes/ || true
sudo rm -rf /var/lib/etcd || true
sudo rm -rf /var/lib/kubelet || true
sudo rm -rf /var/lib/dockershim || true
sudo rm -rf /var/run/kubernetes || true
sudo rm -rf /var/lib/cni/ || true
sudo rm -rf /root/.kube/ || true
sudo rm -rf $HOME/.kube/ || true

# Remove all Kubernetes-related Docker or containerd images
if command -v docker &> /dev/null; then
    echo "Removing all Docker images..."
    if [ "$(sudo docker images -q)" ]; then
        sudo docker rmi $(sudo docker images -q) 2>/dev/null || true
    else
        echo "No Docker images to remove."
    fi
fi

# Remove containerd containers and images if crictl is installed
if command -v crictl &> /dev/null; then
    echo "Removing all containerd containers and images..."
    sudo crictl stopp $(sudo crictl pods -q 2>/dev/null || true) || true
    sudo crictl rmp $(sudo crictl pods -q 2>/dev/null || true) || true
    sudo crictl rm $(sudo crictl ps -a -q 2>/dev/null || true) || true
    sudo crictl rmi $(sudo crictl images -q 2>/dev/null || true) || true
else
    echo "crictl not found; skipping containerd cleanup."
fi

# Reset iptables
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
sudo iptables -t nat -X
sudo iptables -t mangle -X
echo "Removing CNI network interfaces..."
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete weave 2>/dev/null || true
echo "Kubernetes is cleaned up."

echo
echo
echo "Installing Kubernetes..."
echo "Kubernetes version without suffix: $KUBEVERSIONWITHOUTSUFFIX"

# Install Kubernetes components
if [ -z "${CNIVERSION}" ]; then
    sudo apt-get install -y kubernetes-cni
else
    sudo apt-get install -y $APTOPTS kubernetes-cni=${CNIVERSION}
fi

if [ -z "${KUBEVERSION}" ]; then
    sudo apt-get install -y kubeadm kubelet kubectl
else
    sudo apt-get install -y $APTOPTS kubeadm=${KUBEVERSION} kubelet=${KUBEVERSION} kubectl=${KUBEVERSION}
fi

sudo apt-mark hold docker.io kubernetes-cni kubelet kubeadm kubectl

# Unmask and enable kubelet service without starting it
sudo systemctl unmask kubelet
sudo systemctl enable kubelet
sudo systemctl daemon-reload

# Ensure configurations are set for containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo chmod 644 /etc/containerd/config.toml
# Set SystemdCgroup = true
if ! sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml; then
    echo "Using backup containerd configuration with SystemdCgroup = true."
    cat <<EOF | sudo tee /etc/containerd/config.toml > /dev/null
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"
  [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]
    SystemdCgroup = true
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      PodSandboxImage = "registry.k8s.io/pause:3.9"
EOF
fi
# Restart containerd
if ! sudo systemctl restart containerd; then
    echo "Failed to restart containerd."
    exit 1
fi

# Restart kubelet to pick up new containerd configuration
sudo systemctl restart kubelet

# Configure crictl to not give endpoint warnings when running: sudo crictl ps -a
cat <<EOF | sudo tee /etc/crictl.yaml > /dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
sudo chmod 644 /etc/crictl.yaml

# Pull required images for Kubernetes
echo "Pulling kube-apiserver, kube-controller-manager, kube-scheduler, kube-proxy, pause, etcd, and coredns..."
sudo kubeadm config images pull --kubernetes-version=${KUBEVERSIONWITHOUTSUFFIX}

echo "Kubernetes components reinstalled and ready for initialization."

mkdir -p $HOME/.kube
sudo chown -R $USER:$USER $HOME/.kube/

NODETYPE="master"
if [ "$NODETYPE" == "master" ]; then # MASTER_NODE_COND

if [[ ${KUBEVERSIONWITHOUTSUFFIX} == 1.13.* ]]; then
    cat <<EOF | tee $HOME/.kube/kube-config.yaml > /dev/null
apiVersion: kubeadm.k8s.io/v1alpha3
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
apiServer:
  certSANs:
    - 'localhost'
    - '127.0.0.1'
    - ${HOSTNAME}
    - ${IP_ADDRESS}
apiServerExtraArgs:
  feature-gates: "SCTPSupport=true"
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF

    elif [[ ${KUBEVERSIONWITHOUTSUFFIX} == 1.14.* ]]; then
    cat <<EOF | tee $HOME/.kube/kube-config.yaml > /dev/null
apiVersion: kubeadm.k8s.io/v1beta1
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
apiServer:
  certSANs:
    - 'localhost'
    - '127.0.0.1'
    - ${HOSTNAME}
    - ${IP_ADDRESS}
apiServerExtraArgs:
  feature-gates: "SCTPSupport=true"
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF

    elif [[ ${KUBEVERSIONWITHOUTSUFFIX} == 1.1[5-9].* ]]; then
    cat <<EOF | tee $HOME/.kube/kube-config.yaml > /dev/null
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
apiServer:
  certSANs:
    - 'localhost'
    - '127.0.0.1'
    - ${HOSTNAME}
    - ${IP_ADDRESS}
  extraArgs:
    feature-gates: "SCTPSupport=true"
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
    # In Kubernetes v1.20, the SCTPSupport feature gate reached General Availability (GA) and no longer needs to be specified.
    # Despite this, specifying apiServerExtraArgs still allows kubeadm to initialize and acts as a backup
    cat <<EOF | tee $HOME/.kube/kube-config.yaml > /dev/null
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: v${KUBEVERSIONWITHOUTSUFFIX}
kind: ClusterConfiguration
apiServer:
  certSANs:
    - 'localhost'
    - '127.0.0.1'
    - ${HOSTNAME}
    - ${IP_ADDRESS}
apiServerExtraArgs:
  feature-gates: "SCTPSupport=true"
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
fi
# Consider adding the following before apiServerExtraArgs:
# extraArgs:
#   feature-gates: "APIPriorityAndFairness=true"
#   enable-aggregator-routing: "true"

# echo "Configuring Flannel CNI configurations..."
# sudo mkdir -p /etc/cni/net.d
# cat <<EOF | sudo tee /etc/cni/net.d/10-flannel.conflist > /dev/null
# {
#     "cniVersion": "0.4.0",
#     "name": "flannel",
#     "plugins": [
#         {
#             "type": "flannel",
#             "delegate": {
#                 "hairpinMode": true,
#                 "isDefaultGateway": true
#             }
#         },
#         {
#             "type": "portmap",
#             "capabilities": {
#                 "portMappings": true
#             }
#         }
#     ]
# }
# EOF
if [ -f /etc/cni/net.d/10-flannel.conflist ]; then
    echo "Removing outdated  Flannel CNI configuration..."
    sudo rm -rf /etc/cni/net.d/10-flannel.conflist
fi

echo "Configuring Kube-Proxy ClusterRoleBinding..."
cat <<EOF | tee $HOME/.kube/kube-proxy-rbac.yaml > /dev/null
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

ATTEMPT=0
MAX_ATTEMPTS=5
until (( ATTEMPT++ == MAX_ATTEMPTS )); do
    if [[ $ATTEMPT -eq $MAX_ATTEMPTS ]]; then
        echo "Kubernetes Initialization: Making final attempt with verbose logging enabled..."
        if sudo kubeadm init --config $HOME/.kube/kube-config.yaml --v=5; then
            break
        fi
    else
        echo "Kubernetes Initialization: Attempt $ATTEMPT failed; trying again in 10 seconds..."
        if sudo kubeadm init --config $HOME/.kube/kube-config.yaml; then
            break
        fi
        sleep 10
    fi
done
if [[ $ATTEMPT -gt $MAX_ATTEMPTS ]]; then
    echo "Kubernetes Initialization: All attempts at \"kubeadm init\" failed. Exiting..."
    exit 1
else
    echo "Kubernetes initialized successfully."
    # Set the KUBECONFIG variable to the config file's location
    mkdir -p $HOME/.kube
    export KUBECONFIG=$HOME/.kube/config
    sudo cp -f /etc/kubernetes/admin.conf $KUBECONFIG
    sudo chown $(id -u):$(id -g) $KUBECONFIG
    sudo sed -i '/KUBECONFIG/d' /etc/environment
    echo "KUBECONFIG=$KUBECONFIG" | sudo tee -a /etc/environment > /dev/null
    source /etc/environment
fi

# Wait for kube-apiserver to be ready
sleep 1
until kubectl get pods --all-namespaces; do
    echo "Waiting for API server to be available..."
    sudo crictl ps -a
    sleep 8
done

echo "Applying Flannel CNI (Kube version $KUBEVERSION)..."
KUBE_MAJOR=$(echo $KUBEVERSION | cut -d '.' -f1)
KUBE_MINOR=$(echo $KUBEVERSION | cut -d '.' -f2)
if [[ $KUBE_MAJOR -eq 1 && $KUBE_MINOR -ge 28 ]]; then
    # Apply the latest Flannel configuration for Kubernetes version 1.28 and above
    if ! kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"; then
        echo "Failed to apply Flannel configuration."
        exit 1
    fi
else
    # Use a specific Flannel version that does not include deprecated PSP for other Kubernetes versions
    echo "Removing PSP from Flannel Configuration..."
    mkdir -p configs_flannel_18.01
    wget -O configs_flannel_18.01/kube-flannel.yml https://raw.githubusercontent.com/flannel-io/flannel/v0.18.1/Documentation/kube-flannel.yml
    # Use sed to remove the PodSecurityPolicy section safely
    sed -i '/apiVersion: policy\/v1beta1/,/---/d' configs_flannel_18.01/kube-flannel.yml
    # Remove RBAC permissions related to PodSecurityPolicy
    sed -i '/- apiGroups: \['\''extensions'\''\]/,+4d' configs_flannel_18.01/kube-flannel.yml
    if ! kubectl apply -f "configs_flannel_18.01/kube-flannel.yml"; then
        echo "Failed to apply Flannel configuration."
        exit 1
    fi
fi

if ! kubectl apply -f "$HOME/.kube/kube-proxy-rbac.yaml"; then
    echo "Failed to apply Kube-Proxy ClusterRoleBinding, skipping."
fi

# echo "Configuring RBAC for metrics-server..."
# cat <<EOF > $HOME/.kube/metrics-server-rbac.yaml
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRole
# metadata:
#   name: system:metrics-server
# rules:
# - apiGroups:
#   - ""
#   resources:
#   - pods
#   - nodes
#   - nodes/stats
#   - namespaces
#   - configmaps
#   verbs:
#   - get
#   - list
#   - watch
# ---
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: system:metrics-server
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: system:metrics-server
# subjects:
# - kind: ServiceAccount
#   name: metrics-server
#   namespace: kube-system
# EOF

# # Apply RBAC for metrics-server
# if ! kubectl apply -f "$HOME/.kube/metrics-server-rbac.yaml"; then
#     echo "Failed to apply RBAC for metrics-server, skipping."
# fi

# # Resource metrics enable commands like: kubectl top pod [pod_name] -n [namespace]
# if ! kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"; then
#     echo "Failed to apply resource metrics, skipping."
# fi

# Create local-storage storage class
cat <<EOF > $HOME/.kube/local-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
echo "Local storage class configuration file created."

# Apply the local-storage storage class
if ! kubectl apply -f "$HOME/.kube/local-storage-class.yaml"; then
    echo "Failed to apply local storage class, skipping."
fi

# Check for node readiness for conditional taint removal
echo "Waiting for essential system pods to be ready..."
if [[ $KUBE_MAJOR -eq 1 && $KUBE_MINOR -ge 28 ]]; then
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
sudo mv "${TEMP_DIR}/linux-amd64/helm" /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm

# Clean up temporary directory
rm -rf "${TEMP_DIR}"

# Remove any old Helm configurations
rm -rf "$HOME/.helm"

while ! helm version; do
    echo "Waiting for Helm to be ready"
    sleep 15
done

echo "Helm installed successfully."

# -----------------------------------------------------------------------------
# Kubernetes configuration for local storage and Helm repo
# -----------------------------------------------------------------------------

echo "Preparing a master node (lower ID) for using local FS for PV"

if [[ $KUBE_MAJOR -eq 1 && $KUBE_MINOR -ge 28 ]]; then
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

if [ "$PV_NODE_NAME" == "$HOSTNAME" ]; then
    sudo mkdir -p /opt/data/dashboard-data
    sudo chmod -R 755 /opt/data/dashboard-data
fi

kubectl label --overwrite nodes "$PV_NODE_NAME" local-storage=enable

echo "Done with master node setup"
fi # MASTER_NODE_COND

# If HELM_REPO_HOST is set, add it to /etc/hosts
HELM_REPO_HOST="helm.ricinfra.local"

# Remove existing entries for the hostname from /etc/hosts
sudo sed -i "/$HELM_REPO_HOST/d" /etc/hosts
# Add the new entry to /etc/hosts
echo "127.0.0.1 $HELM_REPO_HOST" | sudo tee -a /etc/hosts

echo "Script completed successfully."

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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ "$1" != "bypass_confirmation" ]; then
    clear
    echo "This script will remove Docker and Kubernetes from the system."
    echo "This is a destructive operation and may result in data loss."
    echo "Please ensure you have backed up any necessary data before proceeding."
    echo
    echo "Do you want to proceed? (yes/no)"
    read -r PROCEED
    if [ "$PROCEED" != "yes" ]; then
        echo "Exiting script."
        exit 0
    fi
fi

echo "Uninstalling Near Real-Time RAN Intelligent Controller..."
export DEBIAN_FRONTEND=noninteractive
# Modifies the needrestart configuration to suppress interactive prompts
if [ -f "/etc/needrestart/needrestart.conf" ]; then
    if ! grep -q "^\$nrconf{restart} = 'a';$" "/etc/needrestart/needrestart.conf"; then
        sudo sed -i "/\$nrconf{restart} = /c\$nrconf{restart} = 'a';" "/etc/needrestart/needrestart.conf"
        echo "Modified needrestart configuration to auto-restart services."
    fi
fi
export NEEDRESTART_SUSPEND=1

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if systemctl is-active --quiet unattended-upgrades; then
    sudo systemctl stop unattended-upgrades &>/dev/null && echo "Successfully stopped unattended-upgrades service."
    sudo systemctl disable unattended-upgrades &>/dev/null && echo "Successfully disabled unattended-upgrades service."
fi
if systemctl is-active --quiet apt-daily.timer; then
    sudo systemctl stop apt-daily.timer &>/dev/null && echo "Successfully stopped apt-daily.timer service."
    sudo systemctl disable apt-daily.timer &>/dev/null && echo "Successfully disabled apt-daily.timer service."
fi
if systemctl is-active --quiet apt-daily-upgrade.timer; then
    sudo systemctl stop apt-daily-upgrade.timer &>/dev/null && echo "Successfully stopped apt-daily-upgrade.timer service."
    sudo systemctl disable apt-daily-upgrade.timer &>/dev/null && echo "Successfully disabled apt-daily-upgrade.timer service."
fi

# Ensure time synchronization is enabled using chrony
if ! dpkg -s chrony &>/dev/null; then
    sudo apt-get install -y chrony
fi
if ! systemctl is-enabled --quiet chrony; then
    sudo systemctl enable chrony && echo "Chrony service enabled."
fi
if ! systemctl is-active --quiet chrony; then
    sudo systemctl start chrony && echo "Chrony service started."
fi

./install_scripts/stop_e2sim.sh

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
sudo apt-get purge -y --allow-change-held-packages docker docker-engine docker-ce docker.io containerd runc || true
sudo rm -rf /var/lib/docker /etc/docker
sudo apt-get autoremove -y

echo
echo
echo "Stopping and removing existing Kubernetes installations..."

# Stop and remove all Docker containers if Docker is installed
if command -v docker &>/dev/null; then
    echo "Stopping and removing existing Docker containers..."
    if [ "$(sudo docker ps -aq)" ]; then
        sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
        sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
    else
        echo "No Docker containers to stop or remove."
    fi
fi

if sudo systemctl is-active --quiet containerd; then
    echo "Stopping containerd..."
    sudo systemctl stop containerd
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
if command -v kubeadm &>/dev/null; then
    echo "Unmounting /var/lib/kubelet mounts..."
    mount | grep '/var/lib/kubelet' | awk '{print $3}' | xargs -r sudo umount -f
    echo "Resetting Kubernetes..."
    echo "y" | sudo kubeadm reset -f -v5
    echo "Kubernetes reset successfully."
fi

# Stop Kubernetes services using systemd
SERVICES=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd")
for SERVICE in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $SERVICE; then
        echo "Stopping $SERVICE..."
        sudo systemctl stop $SERVICE || true
    else
        echo "$SERVICE is not active."
    fi
done

# Stop and remove Docker containers if Docker is used
if [ ! -z "$(sudo docker ps -a -q)" ]; then
    sudo docker stop $(sudo docker ps -a -q) || true
    sudo docker rm $(sudo docker ps -a -q) || true
fi

# Kill stubborn Kubernetes processes more carefully
PROCESSES=("kubelet" "kube-control" "kube-schedul" "kube-apiserver" "etcd")
for PROCESS in "${PROCESSES[@]}"; do
    while pgrep "$PROCESS" >/dev/null; do
        echo "Terminating $PROCESS..."
        sudo pkill -9 "$PROCESS" || true
        sleep 1
    done
done

# Check and free ports, check which process is using a port with: ss -tulpn | grep :PORTNUMBER
PORTS=(6443 10250 10257 10259 2379 2380)
for PORT in "${PORTS[@]}"; do
    if sudo ss -tulpn | grep ":$PORT" >/dev/null; then
        echo "Freeing port $PORT..."
        sudo fuser -k $PORT/tcp || true
    fi
done

# Uninstall Kubernetes packages
if command -v kubernetes-cni &>/dev/null; then
    echo "Uninstalling kubernetes-cni..."
    sudo apt-mark unhold kubernetes-cni
    sudo apt-get purge -y kubernetes-cni
    sudo rm -f $(which kubernetes-cni)
fi
if command -v kubeadm &>/dev/null; then
    echo "Uninstalling kubeadm..."
    sudo apt-mark unhold kubeadm
    sudo apt-get purge -y kubeadm
    sudo rm -f $(which kubeadm)
fi
if command -v kubelet &>/dev/null; then
    echo "Uninstalling kubelet..."
    sudo apt-mark unhold kubelet
    sudo apt-get purge -y kubelet
    sudo rm -f $(which kubelet)
fi
if command -v kubectl &>/dev/null; then
    echo "Uninstalling kubectl..."
    sudo apt-mark unhold kubectl
    sudo apt-get purge -y kubectl
    sudo rm -f $(which kubectl)
fi

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
if command -v docker &>/dev/null; then
    echo "Removing all Docker images..."
    if [ "$(sudo docker images -q)" ]; then
        sudo docker rmi $(sudo docker images -q) 2>/dev/null || true
    else
        echo "No Docker images to remove."
    fi
fi

# Remove containerd containers and images if crictl is installed
if command -v crictl &>/dev/null; then
    echo "Removing all containerd containers and images..."
    sudo crictl stop $(sudo crictl pods -q 2>/dev/null || true) || true
    sudo crictl rmp $(sudo crictl pods -q 2>/dev/null || true) || true
    sudo crictl rm $(sudo crictl ps -a -q 2>/dev/null || true) || true
    sudo crictl rmi $(sudo crictl images -q 2>/dev/null || true) || true
else
    echo "crictl not found; skipping containerd cleanup."
fi

if command -v k9s &>/dev/null; then
    echo "Uninstalling k9s..."
    sudo rm -f /usr/local/bin/k9s
    echo "Successfully uninstalled k9s."
else
    echo "k9s is not installed, nothing to uninstall."
fi
if [ -d "$HOME/k9s-installation" ]; then
    echo "Removing k9s temporary installation directory..."
    rm -rf "$HOME/k9s-installation"
fi
rm -rf ~/.config/k9s

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

sudo rm -rf ~/.kube
echo
echo "Kubernetes is cleaned up."

echo "Performing general system cleanup..."
sudo apt-get autoremove -y
sudo apt-get autoclean

cd "$SCRIPT_DIR"
sudo rm -rf additional_scripts/pod_pcaps
sudo rm -rf appmgr
sudo rm -rf charts
sudo rm -rf e2-interface
sudo rm -rf influxdb
sudo rm -rf influxdb_auth_token.json
sudo rm -rf install_time.txt
sudo rm -rf logs/
sudo rm -rf ric-dep
sudo rm -rf xApps

echo
echo
echo "################################################################################"
echo "# Successfully uninstalled the Near-Real Time RAN Intelligent Controller       #"
echo "################################################################################"

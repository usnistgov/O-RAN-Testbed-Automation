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

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo "Installing Non-Real-Time RAN Intelligent Controller..."
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

# Get the start timestamp in seconds
INSTALL_START_TIME=$(date +%s)

sudo rm -rf logs/

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
    echo "Chrony is not installed, installing..."
    sudo apt-get update
    sudo apt-get install -y chrony || true
fi
if ! systemctl is-enabled --quiet chrony; then
    echo "Enabling Chrony service..."
    sudo systemctl enable chrony || true
fi
if ! systemctl is-active --quiet chrony; then
    echo "Starting Chrony service..."
    sudo systemctl start chrony || true
fi

# Instructions are from: https://lf-o-ran-sc.atlassian.net/wiki/spaces/RICNR/pages/86802787/Release+K+-+Run+in+Kubernetes
if [ ! -d dep ]; then
    echo
    echo "Cloning Non-RT RIC dependencies..."
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/it/dep.git
    cd dep # Ensure that the components are cloned
    git restore --source=HEAD :/
    cd ..
fi

if [ ! -d "rappmanager" ]; then
    cd "$SCRIPT_DIR"
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/nonrtric/plt/rappmanager.git rappmanager
fi

cd "$SCRIPT_DIR/dep/"

if [ ! -d ranpm ] || [ -z "$(ls -A ranpm)" ]; then
    [ -d ranpm ] && rm -rf ranpm # Remove the directory if it is empty
    echo
    echo "Cloning selected release of dep/ranpm..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm.git ranpm
fi
if [ ! -d ric-dep ] || [ -z "$(ls -A ric-dep)" ]; then
    [ -d ric-dep ] && rm -rf ric-dep # Remove the directory if it is empty
    echo
    echo "Cloning selected release of dep/ric-dep..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git ric-dep
fi
if [ ! -d smo-install/multicloud-k8s ] || [ -z "$(ls -A smo-install/multicloud-k8s)" ]; then
    [ -d smo-install/multicloud-k8s ] && rm -rf smo-install/multicloud-k8s # Remove the directory if it is empty
    echo
    echo "Cloning dep/smo-install/multicloud-k8s..."
    ./../install_scripts/git_clone.sh https://github.com/onap/multicloud-k8s.git smo-install/multicloud-k8s
fi
if [ ! -d smo-install/onap_oom ] || [ -z "$(ls -A smo-install/onap_oom)" ]; then
    [ -d smo-install/onap_oom ] && rm -rf smo-install/onap_oom # Remove the directory if it is empty
    echo
    echo "Cloning dep/smo-install/onap_oom..."
    ./../install_scripts/git_clone.sh https://gerrit.onap.org/r/oom.git smo-install/onap_oom
fi

echo
echo "Installing Docker, Kubernetes, and Helm..."
# Determine if Kubernetes should be reset
SHOULD_RESET_KUBE=false
if ! helm version &>/dev/null; then
    SHOULD_RESET_KUBE=true
fi
echo "Checking if any of the kube-system pods are not running..."
if [ "$SHOULD_RESET_KUBE" = false ]; then
    POD_NAMES=("coredns" "etcd" "kube-apiserver" "kube-controller" "kube-proxy" "kube-scheduler")
    ALL_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null) || true
    for POD_NAME in "${POD_NAMES[@]}"; do
        # Check for at least one pod with the part of the name matching and in 'RUNNING' or 'COMPLETED' status
        if ! echo "$ALL_PODS" | grep -e "$POD_NAME" | awk '{print $3}' | grep -q -e "Running" -e "Completed"; then
            SHOULD_RESET_KUBE=true
            echo "    $POD_NAME is not running."
        else
            echo "    $POD_NAME is running."
        fi
    done
fi

cd "$SCRIPT_DIR/dep/"
if [ "$SHOULD_RESET_KUBE" = false ]; then
    echo "All kube-system pods are already running, skipping."
    echo
else
    echo "At least one kube-system pod is not running, resetting Kubernetes..."

    # Download ric-dep from gerrit
    if [ ! -f "ric-dep/bin/install_k8s_and_helm.sh" ]; then
        sudo rm -rf ric-dep
        ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git ric-dep
    fi
    # Patch the install script and save a backup of the original
    if [ ! -f "ric-dep/bin/install_k8s_and_helm.previous.sh" ]; then
        cp ric-dep/bin/install_k8s_and_helm.sh ric-dep/bin/install_k8s_and_helm.previous.sh
    fi
    cp "$SCRIPT_DIR/install_patch_files/dep/ric-dep/bin/install_k8s_and_helm.sh" ric-dep/bin/install_k8s_and_helm.sh

    cd "$SCRIPT_DIR/dep/ric-dep/bin/"

    # Remove any expired keys from apt-get update
    sudo "$SCRIPT_DIR/install_scripts/./remove_expired_apt_keys.sh"

    # Increase the file descriptor limits of the system
    sudo "$SCRIPT_DIR/install_scripts/./set_file_descriptor_limits.sh"

    if ! ./install_k8s_and_helm.sh; then
        echo "An error occured when running $(pwd)/install_k8s_and_helm.sh."
        exit 1
    fi

    echo
    echo
    echo "Installing Helm Chart and Museum..."
    cd "$SCRIPT_DIR/dep/ric-dep/bin/"
    sudo ./install_common_templates_to_helm.sh
fi

cd "$SCRIPT_DIR"

echo
echo "Installing k9s..."
if ! sudo ./install_scripts/install_k9s.sh; then
    echo "Could not install k9s at the moment, skipping."
fi

# Check if istioctl exists and is a broken link
if command -v istioctl &>/dev/null; then
    ISTIOCTL_PATH=$(command -v istioctl)
    if [ ! -e "$ISTIOCTL_PATH" ]; then
        sudo rm "$ISTIOCTL_PATH"
        hash -d istioctl 2>/dev/null || true
    fi
fi
if ! command -v istioctl &>/dev/null; then
    echo "Downloading and Installing Istio..."
    mkdir -p istio
    cd istio
    ISTIO_DIR=$(find . -maxdepth 1 -type d -name "istio-*" | sort -V | tail -n1)
    if [ -z "$ISTIO_DIR" ]; then
        echo "Downloading Istio..."
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$(curl -sL https://api.github.com/repos/istio/istio/releases/latest | grep -Po '"tag_name": "\K.*?(?=")') sh -
        ISTIO_DIR=$(find . -maxdepth 1 -type d -name "istio-*" | sort -V | tail -n1)
    fi
    if [ -d "$ISTIO_DIR" ]; then
        cd "$ISTIO_DIR"
    else
        echo "The Istio directory was not found."
        exit 1
    fi
    if [ -f bin/istioctl ]; then
        sudo rm -f /usr/local/bin/istioctl
        sudo ln -sf "$(pwd)/bin/istioctl" /usr/local/bin/istioctl
        echo "Successfully installed Istio."
    else
        echo "Binary for istioctl not found."
        exit 1
    fi
    cd "$SCRIPT_DIR"
fi

if ! kubectl get pods -n istio-system | grep -q 'istiod-'; then
    if kubectl taint nodes --all node-role.kubernetes.io/control-plane- &>/dev/null; then
        echo "Successfully removed taint from control-plane."
    fi
    if kubectl taint nodes --all node-role.kubernetes.io/master- &>/dev/null; then
        echo "Successfully removed taint removed from master."
    fi
    echo "Installing Istio to the cluster..."
    istioctl install -y
fi

if ! kubectl get namespace nonrtric &>/dev/null; then
    echo "Creating namespace nonrtric..."
    kubectl create namespace nonrtric
fi

# Enable Istio sidecar injection on the namespace
kubectl label namespace nonrtric istio-injection=enabled --overwrite

cd "$SCRIPT_DIR"

# Check if docker is accessible from the current user, and if not, repair its permissions
if [ -z "$FIXED_DOCKER_PERMS" ]; then
    if ! output=$(docker info 2>&1); then
        if echo "$output" | grep -qiE 'permission denied|cannot connect to the docker daemon'; then
            echo "Docker permissions will repair on reboot."
            sudo groupadd -f docker
            if [ -n "$SUDO_USER" ]; then
                sudo usermod -aG docker "$SUDO_USER"
            else
                sudo usermod -aG docker "$USER"
            fi
            # Rather than requiring a reboot to apply docker permissions, set the docker group and re-run the parent script
            export FIXED_DOCKER_PERMS=1
            if ! command -v sg &>/dev/null; then
                echo
                echo "WARNING: Could not find set group (sg) command, docker may fail without sudo until the system reboots."
                echo
            else
                exec sg docker "$CURRENT_DIR/$0" "$@"
            fi
        fi
    fi
fi

# Ensure docker is configured properly
sudo ./install_scripts/enable_docker_build_kit.sh
if ! command -v docker-compose &>/dev/null; then
    ./install_scripts/install_docker_compose.sh
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    sudo apt-get install -y jq
fi

if ! command -v envsubst &>/dev/null; then
    echo "Installing envsubst..."
    # Code from (https://github.com/a8m/envsubst):
    curl -L https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst-$(uname -s)-$(uname -m) -o envsubst
    chmod +x envsubst
    sudo mv envsubst /usr/local/bin
fi

if ! command -v keytool &>/dev/null; then
    echo "Installing openjdk-11-jre-headless..."
    sudo add-apt-repository -y ppa:openjdk-r/ppa
    sudo apt-get update
    sudo apt-get install -y openjdk-11-jre-headless
fi

echo
echo "Installing Non-Real-Time RAN Intelligent Controller..."
# Determine if RAN Intelligent Controller pods should be reset by checking if any of the nonrtric pods are not running
echo "Checking if any of the nonrtric pods are not running..."
SHOULD_RESET_NONRTRIC=false
if [ "$SHOULD_RESET_NONRTRIC" = false ]; then
    POD_NAMES=("a1-sim-osc" "a1-sim-std" "a1-sim-std2" "a1controller" "capifcore" "db" "dmaapadapterservice" "dmaapmediatorservice" "helmmanager" "orufhrecovery" "policymanagementservice" "ransliceassurance" "rappcatalogueenhancedservice" "rappcatalogueservice" "rappmanager")
    ALL_PODS=$(kubectl get pods -n nonrtric --no-headers 2>/dev/null) || true

    for POD_NAME in "${POD_NAMES[@]}"; do
        # Check for at least one pod with the part of the name matching and in 'RUNNING' or 'COMPLETED' status
        if ! echo "$ALL_PODS" | grep -e "^$POD_NAME" | awk '{print $3}' | grep -q -e "Running" -e "Completed"; then
            SHOULD_RESET_NONRTRIC=true
            echo "    $POD_NAME is not running."
        else
            echo "    $POD_NAME is running."
        fi
    done
fi

if [ "$SHOULD_RESET_NONRTRIC" = false ]; then
    echo "All nonrtric pods are already running, skipping."
    echo
else
    echo "At least one nonrtric pod is not running, resetting Non-RT RIC pods..."
    cd "$SCRIPT_DIR"

    echo "Revising the YAML file for the Non-RT RIC pods..."
    RIC_YAML_FILE_PATH="dep/RECIPE_EXAMPLE/NONRTRIC/example_recipe.yaml"
    RIC_YAML_FILE_PATH_UPDATED="dep/RECIPE_EXAMPLE/NONRTRIC/example_recipe_updated.yaml"
    sudo chown $USER:$USER $RIC_YAML_FILE_PATH
    sudo cp $RIC_YAML_FILE_PATH $RIC_YAML_FILE_PATH_UPDATED
    sudo chown $USER:$USER $RIC_YAML_FILE_PATH_UPDATED
    sudo "$SCRIPT_DIR/install_scripts/./revise_example_recipe_yaml.sh" "$RIC_YAML_FILE_PATH_UPDATED"

    echo "Setting default storage class for Kong..."
    KONG_YAML_FILE_PATH="dep/nonrtric/helm/kongstorage/kongvalues.yaml"
    KONG_YAML_FILE_PATH_BACKUP="dep/nonrtric/helm/kongstorage/kongvalues.original.yaml"
    sudo chown $USER:$USER $KONG_YAML_FILE_PATH
    if [ ! -f "$KONG_YAML_FILE_PATH_BACKUP" ]; then
        sudo cp $KONG_YAML_FILE_PATH $KONG_YAML_FILE_PATH_BACKUP
        sudo chown $USER:$USER $KONG_YAML_FILE_PATH_BACKUP
    fi
    sudo "$SCRIPT_DIR/install_scripts/./ensure_kong_storage_class_set_yaml.sh" "$KONG_YAML_FILE_PATH"

    cd "$SCRIPT_DIR/dep/"

    echo "Deploying Non-RT RIC pods..."
    sudo ./bin/deploy-nonrtric -f ./RECIPE_EXAMPLE/NONRTRIC/example_recipe_updated.yaml

    echo "Successfully installed Non-RT RIC pods."
fi

cd "$SCRIPT_DIR"
sudo ./install_scripts/wait_for_kubectl.sh
kubectl get pods -A || true
echo
echo "Attempting to remove any remaining taints from control-plane/master..."
# Remaining taints prevent the RIC components from initializing
# Check for remaining taints with: kubectl describe nodes | grep Taints
if kubectl taint nodes --all node-role.kubernetes.io/control-plane- &>/dev/null; then
    echo "Successfully removed taint from control-plane."
fi
if kubectl taint nodes --all node-role.kubernetes.io/master- &>/dev/null; then
    echo "Successfully removed taint removed from master."
fi

echo
echo "Waiting for Non-RT RIC pods..."
sudo ./install_scripts/wait_for_nonrtric_pods.sh

cd "$SCRIPT_DIR"

echo
echo "Installing and running the control panel..."
./run_control_panel.sh

echo
echo "Ensuring the Non-RT RIC pods are still ready..."
sudo ./install_scripts/wait_for_nonrtric_pods.sh

echo
echo "Generating sample rApps..."
./install_scripts/generate_sample_rapps.sh

echo
echo "Testing the Non-RT RIC functionality..."
if ! ./run_tests.sh; then
    echo "Some of the Non-RT RIC tests failed. Waiting for pods, then retrying..."
    sleep 30
    sudo ./install_scripts/wait_for_nonrtric_pods.sh
    ./run_tests.sh
else
    echo "Successfully passed the tests; the Non-RT RIC is functional."
fi
echo

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

# Calculate how long the script took to run
INSTALL_END_TIME=$(date +%s)
if [ -n "$INSTALL_START_TIME" ]; then
    DURATION=$((INSTALL_END_TIME - INSTALL_START_TIME))
    DURATION_MINUTES=$(echo "scale=5; $DURATION/ 60" | bc)
    echo "The RIC installation process took $DURATION_MINUTES minutes to complete."
    mkdir -p logs
    echo "$DURATION_MINUTES minutes" >>install_time.txt
fi

echo
echo
echo "################################################################################"
echo "# Successfully installed the Non-Real-Time RAN Intelligent Controller          #"
echo "################################################################################"

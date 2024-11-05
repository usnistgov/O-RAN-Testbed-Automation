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

echo "Installing Non-RT RIC..."

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
    sudo apt-get install -y chrony
fi
if ! systemctl is-enabled --quiet chrony; then
    sudo systemctl enable chrony && echo "Chrony service enabled."
fi
if ! systemctl is-active --quiet chrony; then
    sudo systemctl start chrony && echo "Chrony service started."
fi

# Instructions are from: https://lf-o-ran-sc.atlassian.net/wiki/spaces/RICNR/pages/15075609/Release+J+-+Run+in+Kubernetes
if [ ! -d dep ]; then
    echo
    echo "Cloning Non-RT RIC dependencies..."
    git clone https://gerrit.o-ran-sc.org/r/it/dep
fi

cd "$SCRIPT_DIR/dep/"

# if [ ! -d nonrtric_j_release ] || [ -z "$(ls -A nonrtric_j_release)" ]; then
#     [ -d nonrtric_j_release ] && rm -rf nonrtric_j_release # Remove the directory if it is empty
#     echo
#     echo "Cloning J-release: dep/nonrtric_j_release..."
#     git clone https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm -b j-release nonrtric_j_release
# fi
if [ ! -d ranpm ] || [ -z "$(ls -A ranpm)" ]; then
    [ -d ranpm ] && rm -rf ranpm # Remove the directory if it is empty
    echo
    echo "Cloning J-release of dep/ranpm..."
    git clone https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm -b j-release ranpm
fi
if [ ! -d ric-dep ] || [ -z "$(ls -A ric-dep)" ]; then
    [ -d ric-dep ] && rm -rf ric-dep # Remove the directory if it is empty
    echo
    echo "Cloning J-release of dep/ric-dep..."
    git clone https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep -b j-release ric-dep
fi
if [ ! -d smo-install/multicloud-k8s ] || [ -z "$(ls -A smo-install/multicloud-k8s)" ]; then
    [ -d smo-install/multicloud-k8s ] && rm -rf smo-install/multicloud-k8s # Remove the directory if it is empty
    echo
    echo "Cloning dep/smo-install/multicloud-k8s..."
    git clone https://github.com/onap/multicloud-k8s.git smo-install/multicloud-k8s
fi
if [ ! -d smo-install/onap_oom ] || [ -z "$(ls -A smo-install/onap_oom)" ]; then
    [ -d smo-install/onap_oom ] && rm -rf smo-install/onap_oom # Remove the directory if it is empty
    echo
    echo "Cloning dep/smo-install/onap_oom..."
    git clone https://gerrit.onap.org/r/oom smo-install/onap_oom
fi

echo
echo "Installing Docker, Kubernetes, and Helm..."
# Determine if Kubernetes should be reset
SHOULD_RESET_KUBE=false
if ! helm version &>/dev/null; then
    SHOULD_RESET_KUBE=true
fi
# Check if any of the kube-system pods are not running
if [ "$SHOULD_RESET_KUBE" = false ]; then
    POD_NAMES=("coredns" "etcd" "kube-apiserver" "kube-controller" "kube-proxy" "kube-scheduler")
    ALL_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null) || true
    for POD_NAME in "${POD_NAMES[@]}"; do
        # Check for at least one pod with the part of the name matching and in 'RUNNING' or 'COMPLETED' status
        if ! echo "$ALL_PODS" | grep -e "$POD_NAME" | awk '{print $3}' | grep -q -e "Running" -e "Completed"; then
            SHOULD_RESET_KUBE=true
            echo "Reset required: No $POD_NAME pod in RUNNING or COMPLETED state."
        fi
    done
fi

cd "$SCRIPT_DIR/dep/"
if [ "$SHOULD_RESET_KUBE" = false ]; then
    echo "All kube-system pods are already running, skipping."
    echo
else
    # Download ric-dep from gerrit
    if [ ! -d "ric-dep" ]; then
        git clone https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep -b j-release
    fi
    # Patch the install script and save a backup of the original
    if [ ! -f "ric-dep/bin/install_k8s_and_helm.previous.sh" ]; then
        cp ric-dep/bin/install_k8s_and_helm.sh ric-dep/bin/install_k8s_and_helm.previous.sh
    fi
    cp "$SCRIPT_DIR/install_patch_files/ric-dep/bin/install_k8s_and_helm.sh" ric-dep/bin/install_k8s_and_helm.sh

    cd "$SCRIPT_DIR/dep/ric-dep/bin/"

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

# Optionally, install kubecolor for a formatted kubectl output
sudo ./install_scripts/wait_for_kubectl.sh
if ! command -v kubecolor &>/dev/null; then
    sudo apt update || true
    echo "Installing kubecolor..."
    if sudo apt-get install -y kubecolor; then
        command -v kubecolor >/dev/null 2>&1 && alias kubectl="kubecolor"
    else
        echo "Failed to install kubecolor, skipping."
    fi
fi

echo
echo "Installing Non-Real-Time RAN Intelligent Controller..."
# Determine if RAN Intelligent Controller pods should be reset by checking if any of the nonrtric pods are not running
SHOULD_RESET_NONRTRIC=false
if [ "$SHOULD_RESET_NONRTRIC" = false ]; then
    POD_NAMES=("a1-sim-osc" "a1-sim-std" "a1-sim-std2" "a1controller" "capifcore" "db" "dmaapadapterservice" "dmaapmediatorservice" "helmmanager" "informationservice" "orufhrecovery" "policymanagementservice" "ransliceassurance" "rappcatalogueenhancedservice" "rappcatalogueservice" "rappmanager" "servicemanager")
    ALL_PODS=$(kubectl get pods -n nonrtric --no-headers)
    for POD_NAME in "${POD_NAMES[@]}"; do
        # Check for at least one pod with the part of the name matching and in 'RUNNING' or 'COMPLETED' status
        if ! echo "$ALL_PODS" | grep -e "^$POD_NAME" | awk '{print $3}' | grep -q -e "Running" -e "Completed"; then
            SHOULD_RESET_NONRTRIC=true
            echo "Reset required: No $POD_NAME pod in RUNNING or COMPLETED state."
        fi
    done
fi

if [ "$SHOULD_RESET_NONRTRIC" = false ]; then
    echo "All nonrtric pods are already running, skipping."
    echo
else
    echo "Revising Non-RT RIC Installation YAML File..."
    cd "$SCRIPT_DIR"
    RIC_YAML_FILE_PATH="dep/RECIPE_EXAMPLE/NONRTRIC/example_recipe.yaml"
    RIC_YAML_FILE_PATH_MODIFIED="dep/RECIPE_EXAMPLE/NONRTRIC/example_recipe_MODIFIED.yaml"
    sudo chown $USER:$USER $RIC_YAML_FILE_PATH
    sudo cp $RIC_YAML_FILE_PATH $RIC_YAML_FILE_PATH_MODIFIED
    sudo chown $USER:$USER $RIC_YAML_FILE_PATH_MODIFIED
    sudo "$SCRIPT_DIR/install_scripts/./revise_example_recipe_yaml.sh" "$RIC_YAML_FILE_PATH_MODIFIED"

    cd "$SCRIPT_DIR/dep/"
    sudo ./bin/deploy-nonrtric -f ./RECIPE_EXAMPLE/NONRTRIC/example_recipe_MODIFIED.yaml
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

# echo "Installing the control panel..."
# cd "$SCRIPT_DIR/dep/nonrtric_j_release/test/auto-test"
# https://docs.o-ran-sc.org/projects/o-ran-sc-portal-nonrtric-controlpanel/en/latest/developer-guide.html

cd "$SCRIPT_DIR"
./start_control_panel.sh onlyinstall

echo
echo "Waiting for Non-RT RIC pods before installing control panel..."
sudo ./install_scripts/wait_for_nonrtric_pods.sh
./start_control_panel.sh

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

echo "The Non-Real-Time RAN Intelligent Controller installation completed successfully."

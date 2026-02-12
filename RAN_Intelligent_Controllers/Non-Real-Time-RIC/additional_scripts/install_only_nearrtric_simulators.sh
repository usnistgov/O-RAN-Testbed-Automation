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

# This script installs only the A1 simulator which enables simulated Near-RT RICs

# Exit immediately if a command fails
set -e

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

echo "Installing A1 Simulators..."
# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

# Run a sudo command every minute to ensure script execution without user interaction
./install_scripts/start_sudo_refresh.sh

# Detect if systemctl is available
USE_SYSTEMCTL=false
if command -v systemctl >/dev/null 2>&1; then
    if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        OUTPUT="$(systemctl 2>&1 || true)"
        if echo "$OUTPUT" | grep -qiE 'not supported|System has not been booted with systemd'; then
            echo "Detected systemctl is not supported. Using background processes instead."
        elif systemctl list-units >/dev/null 2>&1 || systemctl is-system-running --quiet >/dev/null 2>&1; then
            USE_SYSTEMCTL=true
        fi
    fi
fi

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if [[ "$USE_SYSTEMCTL" == "true" ]]; then
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
        sudo env $APTVARS apt-get install -y chrony || true
    fi
    if ! systemctl is-enabled --quiet chrony; then
        echo "Enabling Chrony service..."
        sudo systemctl enable chrony || true
    fi
    if ! systemctl is-active --quiet chrony; then
        echo "Starting Chrony service..."
        sudo systemctl start chrony || true
    fi
fi

# Instructions are from: https://lf-o-ran-sc.atlassian.net/wiki/spaces/RICNR/pages/679903652/Release+M+-+Run+in+Kubernetes
if [ ! -d dep ]; then
    echo
    echo "Cloning A1 dependencies..."
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/it/dep.git
    cd dep # Ensure that the components are cloned
    git restore --source=HEAD :/
    cd ..
fi

cd "$PARENT_DIR/dep/"

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

cd "$PARENT_DIR/dep/"
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
    cp "$PARENT_DIR/install_patch_files/dep/ric-dep/bin/install_k8s_and_helm.sh" ric-dep/bin/install_k8s_and_helm.sh

    cd "$PARENT_DIR/dep/ric-dep/bin/"

    # Remove any expired keys from apt-get update
    sudo "$PARENT_DIR/install_scripts/./remove_expired_apt_keys.sh"

    # Increase the file descriptor limits of the system
    sudo "$PARENT_DIR/install_scripts/./set_file_descriptor_limits.sh"

    if ! ./install_k8s_and_helm.sh; then
        echo "An error occured when running $(pwd)/install_k8s_and_helm.sh."
        exit 1
    fi

    echo
    echo
    echo "Installing Helm Chart and Museum..."
    cd "$PARENT_DIR/dep/ric-dep/bin/"
    if helm plugin list | grep -q servecm; then
        echo "servecm plugin already installed, removing..."
        helm plugin remove servecm
    fi
    sudo ./install_common_templates_to_helm.sh
fi

cd "$PARENT_DIR"

echo
echo "Installing k9s..."
if ! sudo ./install_scripts/install_k9s.sh; then
    echo "Could not install k9s at the moment, skipping."
fi

cd "$PARENT_DIR"

# Check if docker is accessible from the current user, and if not, repair its permissions
if [ -z "$FIXED_DOCKER_PERMS" ]; then
    if ! OUTPUT=$(docker info 2>&1); then
        if echo "$OUTPUT" | grep -qiE 'permission denied|cannot connect to the docker daemon'; then
            echo "Docker permissions will repair on reboot."
            sudo groupadd -f docker
            if [ -n "$SUDO_USER" ]; then
                sudo usermod -aG docker "${SUDO_USER:-root}"
            else
                sudo usermod -aG docker "${USER:-root}"
            fi
            # Rather than requiring a reboot to apply docker permissions, set the docker group and re-run the parent script
            export FIXED_DOCKER_PERMS=1
            if ! command -v sg &>/dev/null; then
                echo
                echo "WARNING: Could not find set group (sg) command, docker may fail without sudo until the system reboots."
                echo
            else
                exec sg docker -c "$(printf '%q ' "$CURRENT_DIR/$0" "$@")"
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
    sudo env $APTVARS apt-get install -y jq
fi

echo
echo "Installing A1 Simulators                           ..."
# Determine if RAN Intelligent Controller pods should be reset by checking if any of the nonrtric pods are not running
echo "Checking if any of the nonrtric pods are not running..."
SHOULD_RESET_NONRTRIC=false
if [ "$SHOULD_RESET_NONRTRIC" = false ]; then
    POD_NAMES=("a1-sim-osc" "a1-sim-std" "a1-sim-std2")
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
    echo "At least one nonrtric pod is not running, resetting A1 pods..."
    cd "$PARENT_DIR"

    echo "Revising the YAML file for the A1 pods..."
    RIC_YAML_FILE_PATH="dep/RECIPE_EXAMPLE/NONRTRIC/example_recipe.yaml"
    RIC_YAML_FILE_PATH_UPDATED="dep/RECIPE_EXAMPLE/NONRTRIC/example_recipe_updated.yaml"
    sudo chown "$USER" $RIC_YAML_FILE_PATH
    sudo cp $RIC_YAML_FILE_PATH $RIC_YAML_FILE_PATH_UPDATED
    sudo chown "$USER" $RIC_YAML_FILE_PATH_UPDATED

    # Function to update YAML configuration files
    update_yaml() {
        local FILE_PATH=$1
        local PROPERTY=$2
        local VALUE=$3
        echo "Updating $FILE_PATH: setting $PROPERTY to $VALUE"
        if [[ "$VALUE" == "true" || "$VALUE" == "false" ]]; then
            yq e "$PROPERTY = $VALUE" -i $FILE_PATH
        else
            yq e "$PROPERTY = \"$VALUE\"" -i $FILE_PATH
        fi
    }

    # First, replace all true to false using sed
    sed -i 's/true/false/g' "$RIC_YAML_FILE_PATH_UPDATED"

    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installPms' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installA1controller' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installA1simulator' 'true'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installControlpanel' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installInformationservice' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installRappcatalogueservice' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installRappcatalogueenhancedservice' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installNonrtricgateway' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installKong' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installDmaapadapterservice' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installDmaapmediatorservice' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installHelmmanager' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installOrufhrecovery' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installRansliceassurance' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installCapifcore' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installServicemanager' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installRanpm' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installrAppmanager' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.installDmeParticipant' 'false'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume1.size' '2Gi'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume1.storageClassName' 'pms-storage'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume1.hostPath' '/var/nonrtric/pms-storage'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume2.size' '2Gi'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume2.storageClassName' 'ics-storage'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume2.hostPath' '/var/nonrtric/ics-storage'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume3.size' '1Gi'
    update_yaml $RIC_YAML_FILE_PATH_UPDATED '.nonrtric.volume3.storageClassName' 'helmmanager-storage'

    cd "$PARENT_DIR/dep/"

    echo "Deploying A1 pods..."
    sudo ./bin/deploy-nonrtric -f ./RECIPE_EXAMPLE/NONRTRIC/example_recipe_updated.yaml

    echo "Successfully installed A1 pods."
fi

cd "$PARENT_DIR"
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
echo "Waiting for A1 pods..."
sudo ./install_scripts/wait_for_nonrtric_pods.sh

cd "$PARENT_DIR"

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh

echo
echo
echo "################################################################################"
echo "# Successfully installed the A1 Simulators                                     #"
echo "################################################################################"

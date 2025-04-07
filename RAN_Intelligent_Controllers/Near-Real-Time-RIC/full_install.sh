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

echo "Installing Near Real-Time RAN Intelligent Controller..."
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
    sudo apt-get install -y chrony
fi
if ! systemctl is-enabled --quiet chrony; then
    sudo systemctl enable chrony && echo "Chrony service enabled."
fi
if ! systemctl is-active --quiet chrony; then
    sudo systemctl start chrony && echo "Chrony service started."
fi

echo
echo "Installing Docker, Kubernetes, and Helm..."
# Determine if Kubernetes should be reset
SHOULD_RESET_KUBE=false
if [ ! -d "ric-dep" ] && [ ! -d "../Non-Real-Time-RIC/dep/ric-dep" ]; then
    SHOULD_RESET_KUBE=true
fi
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

if [ "$SHOULD_RESET_KUBE" = false ]; then
    echo "All kube-system pods are already running, skipping."
    echo
else
    cd "$SCRIPT_DIR"
    echo "At least one kube-system pod is not running, resetting Kubernetes..."

    # Download ric-dep from gerrit
    if [ ! -d "ric-dep" ]; then
        ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git ric-dep
    fi
    # Patch the install script and save a backup of the original
    if [ ! -f "ric-dep/bin/install_k8s_and_helm.previous.sh" ]; then
        cp ric-dep/bin/install_k8s_and_helm.sh ric-dep/bin/install_k8s_and_helm.previous.sh
    fi
    cp "$SCRIPT_DIR/install_patch_files/ric-dep/bin/install_k8s_and_helm.sh" ric-dep/bin/install_k8s_and_helm.sh

    cd "$SCRIPT_DIR/ric-dep/bin/"

    # Remove any expired keys from apt-get update
    sudo "$SCRIPT_DIR/install_scripts/./remove_expired_apt_keys.sh"

    # Increase the file descriptor limits of the system
    sudo "$SCRIPT_DIR/install_scripts/./set_file_descriptor_limits.sh"

    if ! ./install_k8s_and_helm.sh; then
        echo "An error occured when running $SCRIPT_DIR/install_k8s_and_helm.sh."
        exit 1
    fi

    # Check if the YAML editor is installed, and install it if not
    if ! command -v yq &>/dev/null; then
        sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
    fi

    # If kong gives troubles in Release I or Release J then it can be disabled with the following code.
    # cd "$SCRIPT_DIR/ric-dep"
    # CURRENT_RIC_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    # if [ "$CURRENT_RIC_BRANCH" = "i-release" ] || [ "$CURRENT_RIC_BRANCH" = "j-release" ]; then
    #     echo "Disabling Kong Pod and Removing Ingress Files..."
    #     cd "$SCRIPT_DIR/ric-dep/helm/infrastructure"
    #     yq '.kong.enabled = false' -i values.yaml
    #     yq '.kong.enabled' values.yaml
    #     # Removing Ingress files
    #     cd "$SCRIPT_DIR/ric-dep/helm/appmgr/templates"
    #     rm -rf ingress-appmgr.yaml
    #     cd "$SCRIPT_DIR/ric-dep/helm/e2mgr/templates"
    #     rm -rf ingress-e2mgr.yaml
    #     cd "$SCRIPT_DIR/ric-dep/helm/a1mediator/templates"
    #     rm -rf ingress-a1mediator.yaml
    # fi

    echo
    echo
    echo "Installing Helm Chart and Museum..."
    cd "$SCRIPT_DIR/ric-dep/bin"
    sudo ./install_common_templates_to_helm.sh
fi

cd "$SCRIPT_DIR"

# Ensure docker is configured properly
sudo ./install_scripts/enable_docker_build_kit.sh

echo
echo "Installing Near-Real Time RAN Intelligent Controller..."

# Determine if RAN Intelligent Controller pods should be reset
SHOULD_RESET_RIC=false
if [ ! -d "ric-dep" ]; then
    SHOULD_RESET_RIC=true
fi
echo "Checking if any of the ricplt pods are not running..."
if [ "$SHOULD_RESET_RIC" = false ]; then
    POD_NAMES=("ricplt-a1mediator" "ricplt-alarmmanager" "ricplt-appmgr" "ricplt-e2mgr" "ricplt-e2term" "ricplt-o1mediator" "ricplt-rtmgr" "ricplt-submgr" "ricplt-vespamgr" "r4-infrastructure-prometheus-alertmanager" "r4-infrastructure-prometheus-server")
    ALL_PODS=$(kubectl get pods -n ricplt --no-headers 2>/dev/null) || true
    for POD_NAME in "${POD_NAMES[@]}"; do
        # Check for at least one pod with the part of the name matching and in 'RUNNING' or 'COMPLETED' status
        if ! echo "$ALL_PODS" | grep -e "$POD_NAME" | awk '{print $3}' | grep -q -e "Running" -e "Completed"; then
            SHOULD_RESET_RIC=true
            echo "    $POD_NAME is not running."
        else
            echo "    $POD_NAME is running."
        fi
    done
fi

if [ "$SHOULD_RESET_RIC" = false ]; then
    echo "All ricplt pods are already running, skipping."
    echo
else
    echo "At least one ricplt pod is not running, resetting Near-RT RIC pods..."
    sudo ./install_scripts/delete_namespace.sh ricinfra ricplt || true

    echo "Revising RIC Installation YAML File..."
    RIC_YAML_FILE_NAME="example_recipe_oran_k_release.yaml"
    RIC_YAML_FILE_NAME_UPDATED="example_recipe_oran_k_release_updated.yaml"

    sudo chown $USER:$USER "ric-dep/RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME"
    sudo cp "ric-dep/RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME" "ric-dep/RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME_UPDATED"
    sudo chown $USER:$USER "ric-dep/RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME_UPDATED"
    sudo ./install_scripts/revise_example_recipe_yaml.sh "ric-dep/RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME_UPDATED"

    # Wait for kube-apiserver to be ready before installing Near-RT RIC
    echo "Waiting for the Kubernetes API server to become ready before installing Near-RT RIC..."
    sudo ./install_scripts/wait_for_kubectl.sh

    # Run the installation command
    mkdir -p "$SCRIPT_DIR/logs"

    SUCCESS="false"
    while [ "$SUCCESS" != "true" ]; do
        RIC_INSTALLATION_STDOUT="$SCRIPT_DIR/logs/ric_installation_stdout.txt"
        RIC_INSTALLATION_LOG_JSON="$SCRIPT_DIR/logs/ric_installation_stdout_parsed.json"

        echo
        echo
        echo "Installing Near-RT RIC..."
        cd ric-dep/bin/
        sudo ./install -f "../RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME_UPDATED" 2>&1 | tee -a "$RIC_INSTALLATION_STDOUT"
        cd "$SCRIPT_DIR"
        echo "Parsing output to check for successful Near-RT RIC installation..."
        ./install_scripts/parse_ric_installation_output.sh

        # The $RIC_INSTALLATION_LOG_JSON file should have the following output:
        # {
        #   "r4-a1mediator": "deployed",
        #   "r4-vespamgr": "deployed",
        #   "r4-o1mediator": "deployed",
        #   "r4-rtmgr": "deployed",
        #   "r4-infrastructure": "deployed",
        #   "r4-submgr": "deployed",
        #   "r4-alarmmanager": "deployed",
        #   "r4-appmgr": "deployed",
        #   "r4-e2term": "deployed",
        #   "r4-e2mgr": "deployed",
        #   "r4-dbaas": "deployed"
        # }

        # Extract the list of components to deploy from the installation stdout log
        COMPONENT_LINE=$(grep "Deploying RIC infra components" "$RIC_INSTALLATION_STDOUT")
        # Check if the component line was found
        if [ -z "$COMPONENT_LINE" ]; then
            echo "Error: The array of components could not be extracted from $RIC_INSTALLATION_STDOUT"
            exit 1
        fi
        # Parse the component names into an array
        COMPONENTS_ARRAY=($(echo $COMPONENT_LINE | sed -n 's/.*\[\(.*\)\].*/\1/p' | tr ' ' '\n'))
        # Generate a jq filter string that checks these components are all "deployed"
        JQ_FILTER='['
        for COMPONENT in "${COMPONENTS_ARRAY[@]}"; do
            JQ_FILTER+="\"r4-$COMPONENT\","
        done
        JQ_FILTER="${JQ_FILTER%,}]" # Remove the trailing comma and close the array
        # Use jq to check that all specified components are deployed
        SUCCESS="$(jq --argjson COMPONENTS "$JQ_FILTER" '
            . as $DATA |
            $COMPONENTS | all(. as $COMPONENT | $DATA[$COMPONENT] == "deployed")
        ' "$RIC_INSTALLATION_LOG_JSON")"
        if [ "$SUCCESS" != "true" ]; then
            echo "Error: RIC installation was not successful. Waiting for API server to be available then retrying..."
            sudo ./install_scripts/wait_for_kubectl.sh
        fi
    done
fi

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

cd "$SCRIPT_DIR"

echo
echo "Installing k9s..."
if ! sudo ./install_scripts/install_k9s.sh; then
    echo "Could not install k9s at the moment, skipping."
fi

echo
echo "Building and Installing the E2 Simulator..."

# Check if the Docker container named 'oransim' exists (either running or stopped)
if [ "$(sudo docker ps -aq -f name=^/oransim$ | wc -l)" -ge 1 ] && [ -d "e2-interface" ]; then
    echo "The E2 Simulator is already installed, skipping."
    echo
else
    if [ ! -d "e2-interface" ]; then
        ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/sim/e2-interface.git
    fi
    sudo ./install_scripts/install_e2sim.sh
fi

echo
echo "Connecting the E2 Simulator to the RIC Cluster..."

./install_scripts/register_chart_museum_url.sh
sudo ./install_scripts/run_chart_museum.sh

echo
echo "Waiting for RIC pods before running e2sim..."
# Remove the unnecessary tiller-secret-generator pod if it has completed
CMD="kubectl get pods -n ricinfra --no-headers | grep 'tiller-secret-generator' | awk '{print \$1, \$3}'"
POD_INFO=$(eval $CMD)
POD_NAME=$(echo $POD_INFO | awk '{print $1}')
POD_STATUS=$(echo $POD_INFO | awk '{print $2}')
if [ "$POD_STATUS" == "Completed" ]; then
    echo "Cleaning up pod $POD_NAME..."
    kubectl delete pod $POD_NAME -n ricinfra
fi
sudo ./install_scripts/wait_for_ricplt_pods.sh

sudo ./install_scripts/run_e2sim_and_connect_to_ric.sh

echo "Restoring ownership of directories and files created while in root..."
sudo chown $USER:$USER logs/e2sim_output.txt
sudo chown -R $USER:$USER charts || true

echo
echo "Installing the xApp Onboarder (dms_cli)..."
# Download appmgr from gerrit
if [ ! -d "appmgr" ]; then
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-plt/appmgr.git
fi
sudo ./install_scripts/run_xapp_onboarder.sh

echo
mkdir -p xApps
cd xApps
if [ ! -d "hw-go" ]; then
    echo "Cloning Hello World Go (hw-go) xApp..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/hw-go.git
fi
if [ ! -d "hw-python" ]; then
    echo "Cloning the Hello World Python (hw-python) xApp..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/hw-python.git
fi
if [ ! -d "hw-rust" ]; then
    echo "Cloning the Hello World Rust (hw-rust) xApp..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/hw-rust.git
fi
if [ ! -d "kpimon-go" ]; then
    echo "Cloning KPI Monitor (kpimon) xApp..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/kpimon-go.git
fi
if [ ! -d "ad-cell" ]; then
    echo "Cloning 5G Cell Anamoly Detection (ad-cell) xApp..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/ad-cell.git
fi
if [ ! -d "ad" ]; then
    echo "Cloning Anamoly Detection (ad) xApp..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/ad.git
fi
if [ ! -d "qp" ]; then
    echo "Cloning Quality of Experience (QoE) Predictor (qp) xApp..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/qp.git
fi
if [ ! -d "rc" ]; then
    echo "Cloning RIC Control xApp (rc)..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/rc.git
fi
if [ ! -d "ts" ]; then
    echo "Cloning Traffic Steering xApp (trafficxapp)..."
    ./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/ts.git
fi
cd ..

echo "Building and Installing Hello World xApp..."
if [ -d "xApps/hw-go" ] && kubectl get pods -n ricxapp | grep -q "ricxapp-hw-go.*Running"; then
    echo "The Hello World xApp is already installed and running, skipping."
    echo
else
    sudo ./install_scripts/install_xapp_hw-go.sh
fi

# Wait until the xApp is successfully deployed
while true; do
    # Run the status check script
    OUTPUT=$(sudo ./install_scripts/check_xapp_deployment_status.sh)

    # Check for the deployment status or specific xApp status in the output
    if echo "$OUTPUT" | grep -q '"status": "deployed"'; then
        break # Exit the loop if deployed
    elif echo "$OUTPUT" | grep -q 'ricxapp-hw-go' && echo "$OUTPUT" | grep -q '1/1' && echo "$OUTPUT" | grep -q 'Running'; then
        echo "xApp ricxapp-hw-go is running and ready (1/1)."
        break # Exit the loop if xApp is running
    else
        echo "Deployment is not yet successful or ricxapp-hw-go is not running. Checking again in 3 seconds..."
        sleep 3
    fi

    # Check for disk-pressure taint on the node and warn the user if removing it fails
    if kubectl describe nodes | grep Taints | grep disk-pressure &>/dev/null; then
        if ! sudo ./install_scripts/handle_disk_pressure_taint.sh; then
            echo "Warning: Disk-pressure taint is preventing xApp deployment. Please ensure sufficient RAM and disk space is available."
            echo "Check the taints with: kubectl describe nodes | grep Taints"
            break
        fi
        echo "Disk-pressure taint handled, continuing to check deployment status..."
    fi
done

echo "Checking xApp deployment status..."
sudo ./install_scripts/check_xapp_deployment_status.sh

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

echo "The Near-Real Time RAN Intelligent Controller installation completed successfully."

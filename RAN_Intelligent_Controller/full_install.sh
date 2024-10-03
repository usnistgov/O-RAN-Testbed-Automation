#!/bin/bash

# Starts a script in background that calls `sudo -v` every minute to ensure that sudo stays active, ensuring the script runs without requiring user interaction
sudo ls
./install_scripts/start_sudo_refresh.sh 

# Get the start timestamp in seconds
ric_start_time=$(date +%s)

# Exit immediately if a command fails
set -e

BASE_DIR=$(pwd)
sudo rm -rf logs/

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if sudo systemctl stop unattended-upgrades &>/dev/null; then
  echo "Successfully stopped unattended-upgrades service."
fi
if sudo systemctl disable unattended-upgrades &>/dev/null; then
  echo "Successfully disabled unattended-upgrades service."
fi
if sudo systemctl stop apt-daily.timer &>/dev/null; then
  echo "Successfully stopped apt-daily.timer service."
fi
if sudo systemctl disable apt-daily.timer &>/dev/null; then
  echo "Successfully disabled apt-daily.timer service."
fi
if sudo systemctl stop apt-daily-upgrade.timer &>/dev/null; then
  echo "Successfully stopped apt-daily-upgrade.timer service."
fi
if sudo systemctl disable apt-daily-upgrade.timer &>/dev/null; then
  echo "Successfully disabled apt-daily-upgrade.timer service."
fi

# Ensure time synchronization is enabled using chrony
sudo apt-get install -y chrony
sudo systemctl enable chrony
sudo systemctl start chrony

echo "--- Installing RIC with J-release ---"

echo
echo
echo "Installing Docker, Kubernetes, and Helm..."
# Download ric-dep from gerrit
if [ ! -d "ric-dep" ]; then
    git clone "https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep" -b j-release
fi
# Patch the install script and save a backup of the original
if [ ! -f "ric-dep/bin/install_k8s_and_helm.backup.sh" ]; then
    cp ric-dep/bin/install_k8s_and_helm.sh ric-dep/bin/install_k8s_and_helm.backup.sh
fi
cp install_patch_files/ric-dep/bin/install_k8s_and_helm.sh ric-dep/bin/install_k8s_and_helm.sh

cd $BASE_DIR/ric-dep/bin/

if ! ./install_k8s_and_helm.sh; then
    echo "An error occured when running $(pwd)/install_k8s_and_helm.sh."
    echo "Please verify that 'kubeadm init' completed without errors."
    echo "If it did not, verify that SCTPSupport (in $HOME/config.yaml) is supported by your version of Kubernetes."
    exit 1
fi

# # If install_k8s_and_helm.sh was ran with sudo, then the following would be needed:
# sudo chown $USER:$USER /root/.kube/config
# mkdir -p $HOME/.kube
# sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $USER:$USER $HOME/.kube/config
# echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bashrc

echo "Disabling Kong Pod and Removing Ingress Files..."
# Check if yq is installed, and install it if not
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    YQ_PATH="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    sudo wget $YQ_PATH -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
    # Uninstall with: sudo rm -rf /usr/bin/yq
fi
# Disabling kong pod
cd $BASE_DIR/ric-dep/helm/infrastructure/
yq '.kong.enabled = false' -i values.yaml
yq '.kong.enabled' values.yaml
# Removing Ingress files
cd $BASE_DIR/ric-dep/helm/appmgr/templates
rm -rf ingress-appmgr.yaml
cd $BASE_DIR/ric-dep/helm/e2mgr/templates
rm -rf ingress-e2mgr.yaml
cd $BASE_DIR/ric-dep/helm/a1mediator/templates
rm -rf ingress-a1mediator.yaml

echo
echo
echo "Installing Helm Chart and Museum..."
cd $BASE_DIR/ric-dep/bin/
sudo ./install_common_templates_to_helm.sh

cd $BASE_DIR

echo "Revising RIC Installation YAML File..."
RIC_YAML_FILE_PATH="ric-dep/RECIPE_EXAMPLE/example_recipe_latest_stable_MODIFIED.yaml"
sudo chown $USER:$USER "ric-dep/RECIPE_EXAMPLE/example_recipe_latest_stable.yaml"
sudo cp ric-dep/RECIPE_EXAMPLE/example_recipe_latest_stable.yaml $RIC_YAML_FILE_PATH
sudo chown $USER:$USER $RIC_YAML_FILE_PATH
sudo ./install_scripts/revise_example_recipe_latest_stable.yaml.sh $RIC_YAML_FILE_PATH

# Wait for kube-apiserver to be ready, timeout of 30 minutes (1800 seconds) before restarting service
echo "Waiting for the Kubernetes API server to become ready before installing near RT-RIC..."
sudo ./install_scripts/wait_for_kubectl.sh

# Run the installation command
mkdir -p $BASE_DIR/logs

SUCCESS="false"
while [ "$SUCCESS" != "true" ]; do
    RIC_INSTALLATION_STDOUT="$(pwd)/logs/ric_installation_stdout.txt"
    RIC_INSTALLATION_LOG_JSON="$(pwd)/logs/ric_installation_stdout_parsed.json"
    
    echo
    echo
    echo "Installing near RT-RIC..."
    cd ric-dep/bin/
    sudo ./install -f ../RECIPE_EXAMPLE/example_recipe_latest_stable.yaml 2>&1 | tee -a "$RIC_INSTALLATION_STDOUT"
    cd $BASE_DIR
    echo "Parsing output to check for successful near RT-RIC installation..."
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
    for COMP in "${COMPONENTS_ARRAY[@]}"; do
        JQ_FILTER+="\"r4-$COMP\","
    done
    JQ_FILTER="${JQ_FILTER%,}]" # Remove the trailing comma and close the array
    # Use jq to check that all specified components are deployed
    SUCCESS="$(jq --argjson components "$JQ_FILTER" '
        . as $data |
        $components | all(. as $c | $data[$c] == "deployed")
    ' "$RIC_INSTALLATION_LOG_JSON")"
    if [ "$SUCCESS" != "true" ]; then
        echo "ERROR: RIC installation was not successful. Waiting for API server to be available then retrying..."
        sudo ./install_scripts/wait_for_kubectl.sh
    fi
done

sudo ./install_scripts/wait_for_kubectl.sh

kubectl get pods -A || true
# Remaining taints may prevent the RIC components from initializing
# Check for remaining taints with: kubectl describe nodes | grep Taints
echo
echo
echo "Attempting to remove any remaining taints from control-plane/master..."
if kubectl taint nodes --all node-role.kubernetes.io/control-plane- &> /dev/null; then
    echo "Successfully removed taint from control-plane"
fi
if kubectl taint nodes --all node-role.kubernetes.io/master- &> /dev/null; then
    echo "Successfully removed taint from master"
fi


cd $BASE_DIR

echo
echo
echo "Installing k9s..."
sudo ./install_scripts/install_k9s.sh

echo
echo
echo "Building and Installing the E2 Simulator..."
if [ ! -d "e2-interface" ]; then
    git clone https://gerrit.o-ran-sc.org/r/sim/e2-interface
fi
sudo ./install_scripts/install_e2sim.sh

echo
echo
echo "Connecting the E2 Simulator to the RIC Cluster..."

sudo ./install_scripts/register_chart_museum_url.sh && ./install_scripts/register_chart_museum_url.sh
sudo ./install_scripts/run_chart_museum.sh

echo
echo
echo "Waiting for RIC pods before running e2sim..."
sudo ./install_scripts/wait_for_ric_pods.sh

sudo ./install_scripts/run_e2sim_and_connect_to_ric.sh

echo "Restoring ownership of directories and files created while in root..."
sudo chown $USER:$USER logs/e2sim_output.txt
sudo chown -R $USER:$USER charts || true
sudo chown -R $USER:$USER logs || true

echo
echo
echo "Installing the xApp Onboarder (dms_cli)..."
# Download appmgr from gerrit
if [ ! -d "appmgr" ]; then
    git clone "https://gerrit.o-ran-sc.org/r/ric-plt/appmgr"
fi
sudo ./install_scripts/run_xapp_onboarder.sh

echo
echo
echo "Building and Installing Hello World xApp..."
mkdir -p xApps
cd xApps
if [ ! -d "hw-go" ]; then
    git clone https://gerrit.o-ran-sc.org/r/ric-app/hw-go
fi
cd ..

sudo ./install_scripts/install_xapp_hw-go.sh

# Wait until the xApp is successfully deployed
while true; do
    # Run the status check script
    output=$(sudo ./install_scripts/check_xapp_deployment_status.sh)
    
    # Check for the deployment status or specific xApp status in the output
    if echo "$output" | grep -q '"status": "deployed"'; then
        break # Exit the loop if deployed
    elif echo "$output" | grep -q 'ricxapp-hw-go' && echo "$output" | grep -q '1/1' && echo "$output" | grep -q 'Running'; then
        echo "xApp ricxapp-hw-go is running and ready (1/1)."
        break # Exit the loop if xApp is running and ready
    else
        echo "Deployment is not yet successful or ricxapp-hw-go is not running/ready. Checking again in 3 seconds..."
        sleep 3
    fi
done

sudo ./install_scripts/check_xapp_deployment_status.sh
echo
echo "The xApp has been successfully deployed."

# Stop the sudo timeout refresher, it is no longer necessary to run
./install_scripts/stop_sudo_refresh.sh 

# Calculate how long the script took to run
ric_end_time=$(date +%s)
if [ -n "$ric_start_time" ]; then
  duration=$((ric_end_time - ric_start_time))
  echo "The RIC installation process took $duration seconds to complete."
  echo "$duration seconds" > installation_time.txt
fi

echo "The RAN Intelligent Controller installation completed successfully."

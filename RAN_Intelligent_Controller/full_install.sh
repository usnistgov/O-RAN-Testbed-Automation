#!/bin/bash

# Starts a script in background that calls `sudo -v` every minute to ensure that sudo stays active, ensuring the script runs without requiring user interaction
sudo ls
./install_scripts/start_sudo_refresh.sh 

# Get the start timestamp in seconds
ric_start_time=$(date +%s)

# Exit immediately if a command fails
set -e

# Prevent the unattended-upgrades service from creating dpkg locks that would error the script
if sudo systemctl stop unattended-upgrades; then
  echo "Successfully stopped unattended-upgrades service."
fi
if sudo systemctl disable unattended-upgrades; then
  echo "Successfully disabled unattended-upgrades service."
fi

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

cd ric-dep/bin/
if ! sudo ./install_k8s_and_helm.sh; then
    echo
    echo
    echo "Failed to run $(pwd)/install_k8s_and_helm.sh, trying different SCTP support syntax..."
    if ! sudo ./install_k8s_and_helm.sh --swap-sctp-config; then
        echo "An error occured when running $(pwd)/install_k8s_and_helm.sh."
        exit 1
    fi
fi

# Ensure that kubectl is accessible in the current user as well
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo
echo
echo "Installing Helm Chart and Museum..."
sudo ./install_common_templates_to_helm.sh

cd ../../ # Main directory

echo
echo
echo "Building and Installing the E2 Simulator..."
if [ ! -d "e2-interface" ]; then
    git clone https://gerrit.o-ran-sc.org/r/sim/e2-interface
fi
sudo ./install_scripts/install_e2sim.sh

echo "Revising RIC Installation YAML File..."
RIC_YAML_FILE_PATH="ric-dep/RECIPE_EXAMPLE/example_recipe_latest_stable_MODIFIED.yaml"
sudo cp ric-dep/RECIPE_EXAMPLE/example_recipe_latest_stable.yaml $RIC_YAML_FILE_PATH
sudo ./install_scripts/revise_example_recipe_latest_stable.yaml.sh $RIC_YAML_FILE_PATH

# Wait for kube-apiserver to be ready, timeout of 30 minutes (1800 seconds) before restarting service
echo "Waiting for the Kubernetes API server to become ready before installing near RT-RIC..."
TIMEOUT=1800
ELAPSED_TIME=0
SLEEP_DURATION=5
while ! kubectl get --raw="/api/v1/namespaces/kube-system/pods" > /dev/null 2>&1; do
    if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
        echo "Timeout exceeded while waiting for the API server to respond."
        echo "Attempting to restart Kubernetes services..."
        # Restart Kubernetes services or any other commands to recover the situation
        sudo systemctl restart kubelet
        sleep $SLEEP_DURATION
        ELAPSED_TIME=$SLEEP_DURATION
        echo "Services restarted. Continuing to wait for API server readiness..."
    else
        echo "Waiting for API server to respond..."
        sudo kubectl get pods --namespace=kube-system
        sudo kubectl get nodes
        sleep $SLEEP_DURATION
        ELAPSED_TIME=$(($ELAPSED_TIME + $SLEEP_DURATION))
    fi
done
echo "API server is ready."

cd ric-dep/bin/

echo
echo
echo "Installing near RT-RIC..."
sudo ./install -f ../RECIPE_EXAMPLE/example_recipe_latest_stable.yaml

cd ../../ # Main directory

echo
echo
echo "Waiting for RIC pods..."
sudo ./install_scripts/wait_for_ric_pods.sh

echo
echo
echo "Connecting the E2 Simulator to the RIC Cluster..."

./install_scripts/register_chart_museum_url.sh
sudo ./install_scripts/register_chart_museum_url.sh

sudo ./install_scripts/run_chart_museum.sh

echo "Waiting once more to ensure that RIC pods are ready before running e2sim..."
sudo ./install_scripts/wait_for_ric_pods.sh

sudo ./install_scripts/run_e2sim_and_connect_to_ric.sh

echo "Restoring ownership of directories and files created while in root..."
sudo chown $USER:$USER logs/e2sim_output.txt
sudo chown -R $USER:$USER charts || true

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

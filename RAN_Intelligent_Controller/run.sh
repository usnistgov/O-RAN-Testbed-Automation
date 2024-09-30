#!/bin/bash

# Exit immediately if a command fails
set -e

echo "Updating etc/hosts in case of a changed local IP address..."
sudo ./install_scripts/update_host_address.sh

sudo systemctl restart kubelet

echo "Waiting for Kubernetes API server..."
sudo ./install_scripts/wait_for_kubectl.sh

echo
echo "Waiting for RIC pods..."
sudo ./install_scripts/wait_for_ric_pods.sh

echo
echo "Connecting the E2 Simulator to the RIC Cluster..."

./install_scripts/register_chart_museum_url.sh
sudo ./install_scripts/register_chart_museum_url.sh

sudo ./install_scripts/run_chart_museum.sh
sudo ./install_scripts/run_e2sim_and_connect_to_ric.sh

echo
echo "Running the xApp Onboarder (dms_cli)..."
sudo ./install_scripts/run_xapp_onboarder.sh

sudo ./install_scripts/check_xapp_deployment_status.sh

sudo ./start_k9s.sh

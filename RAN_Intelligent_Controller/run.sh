#!/bin/bash

# Exit immediately if a command fails
set -e

echo "--- Running RIC with J-release ---"

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
sudo ./install_scripts/run_e2sim_and_connect_to_ric.sh

echo
echo
echo "Running the xApp Onboarder (dms_cli)..."
sudo ./install_scripts/run_xapp_onboarder.sh

sudo ./install_scripts/check_xapp_deployment_status.sh





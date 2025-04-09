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

echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Check if the influxDB pod already exists: kubectl get pods -n ricplt | grep r4-influxdb-influxdb2
if kubectl get pods -n ricplt | grep r4-influxdb-influxdb2 &>/dev/null; then
    echo "The InfluxDB pod is already installed and running, skipping."
    exit 0
fi

# Wait for kube-apiserver to be ready before installing Near-RT RIC
echo "Waiting for the Kubernetes API server to become ready before installing Near-RT RIC..."
sudo ./install_scripts/wait_for_kubectl.sh

echo "Revising InfluxDB NFS Storage Class configuration..."
./install_scripts/revise_influxdb_values_yaml.sh

echo
echo
echo "Installing InfluxDB..."
cd ric-dep/bin/

RIC_YAML_FILE_NAME_UPDATED="example_recipe_latest_stable_updated.yaml"
if [ ! -f "../RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME_UPDATED" ]; then
    RIC_YAML_FILE_NAME_UPDATED="example_recipe_latest_stable.yaml"
fi
RIC_INSTALLATION_STDOUT="$SCRIPT_DIR/logs/ric_influxdb_installation_stdout.txt"

echo
echo
echo "Please ignore \"Error: INSTALLATION FAILED: cannot re-use a name that is still in use\" as these pods are already installed."
sudo ./install -f "../RECIPE_EXAMPLE/$RIC_YAML_FILE_NAME_UPDATED" -c "influxdb" 2>&1 | tee -a "$RIC_INSTALLATION_STDOUT" || true
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

echo "Waiting for all pods to be in the Running state before installation is complete..."
./install_scripts/wait_for_ricplt_pods.sh

echo
echo "Successfully installed InfluxDB into Near-RT RIC."

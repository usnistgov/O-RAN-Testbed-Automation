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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Get the file path from the command line argument
KONG_CONFIG_PATH=$1

# Check if the file path is provided
if [[ -z "$KONG_CONFIG_PATH" ]]; then
    echo "Error: No file path provided."
    echo "Usage: $0 <path_to_yaml_file>"
    exit 1
fi

# Check if the file exists and is readable
if [[ ! -f "$KONG_CONFIG_PATH" ]]; then
    echo "Error: File '$KONG_CONFIG_PATH' does not exist."
    exit 1
fi

if [[ ! -r "$KONG_CONFIG_PATH" ]]; then
    echo "Error: File '$KONG_CONFIG_PATH' is not readable."
    exit 1
fi

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo ./install_scripts/install_yq.sh
fi
# Check that the correct version of yq is installed
if ! yq --version 2>/dev/null | grep -q 'https://github\.com/mikefarah/yq'; then
    echo "ERROR: Detected an incompatible yq installation."
    echo "Please ensure the Python yq is uninstalled with \"pip uninstall -y yq\", then re-run this script."
    exit 1
fi

# The following snippet is from https://lf-o-ran-sc.atlassian.net/wiki/spaces/RICNR/pages/86802787/Release+K+-+Run+in+Kubernetes:
#     sed -i '/persistence:/,/existingClaim:/s/existingClaim: .*/enabled: false/' ./dep/nonrtric/helm/kongstorage/kongvalues.yaml && rm -rf ./dep/nonrtric/helm/kongstorage/templates
# Below are the equivalent yq commands:
echo "Removing existingClaim and setting persistence.enabled=false for Postgres..."
yq eval 'del(.postgresql.primary.persistence.existingClaim)' -i "$KONG_CONFIG_PATH"
yq eval '.postgresql.primary.persistence.enabled = false' -i "$KONG_CONFIG_PATH"
sudo rm -rf "$PARENT_DIR/dep/nonrtric/helm/kongstorage/templates"

# Disable volumePermissions for PostgreSQL since it is causing error "container's runAsUser breaks non-root policy":
yq eval '.postgresql.volumePermissions.enabled = false' -i "$KONG_CONFIG_PATH"

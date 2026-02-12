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

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"

# Get the file path from the command line argument
RECIPE_PATH=$1

# Check if the file path is provided
if [[ -z "$RECIPE_PATH" ]]; then
    echo "ERROR: No file path provided."
    echo "Usage: $0 <path_to_yaml_file>"
    exit 1
fi

# Check if the file exists and is readable
if [[ ! -f "$RECIPE_PATH" ]]; then
    echo "ERROR: File '$RECIPE_PATH' does not exist."
    exit 1
fi

if [[ ! -r "$RECIPE_PATH" ]]; then
    echo "ERROR: File '$RECIPE_PATH' is not readable."
    exit 1
fi

# Ensure the correct YAML editor is installed
sudo ./install_scripts/ensure_consistent_yq.sh

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

# Guide from the Non-RT RIC wiki:
# https://lf-o-ran-sc.atlassian.net/wiki/spaces/RICNR/pages/679903652/Release+M+-+Run+in+Kubernetes

update_yaml $RECIPE_PATH '.nonrtric.installPms' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installA1controller' 'false'
update_yaml $RECIPE_PATH '.nonrtric.installA1simulator' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installControlpanel' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installInformationservice' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installNonrtricgateway' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installKong' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installTopology' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installDmaapadapterservice' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installDmeparticipant' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installrAppmanager' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installCapifcore' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installServicemanager' 'true'
update_yaml $RECIPE_PATH '.nonrtric.installRanpm' 'true'

# Add Rics configuration to policymanagementservice
echo "Updating $RECIPE_PATH: configuring rics"
yq e '.policymanagementservice.application.app.filepath = "/var/policy-management-service/application_configuration.json"' -i "$RECIPE_PATH"
yq e '.policymanagementservice.config.config.controller = []' -i "$RECIPE_PATH"
yq e '.policymanagementservice.config.config.ric = [
  {"name": "ric1", "baseUrl": "http://a1-sim-osc-0.nonrtric:8085", "managedElementIds": ["kista_1", "kista_2"]},
  {"name": "ric2", "baseUrl": "http://a1-sim-osc-1.nonrtric:8085", "managedElementIds": ["kista_1", "kista_2"]},
  {"name": "ric3", "baseUrl": "http://a1-sim-std-0.nonrtric:8085", "managedElementIds": ["kista_1", "kista_2"]},
  {"name": "ric4", "baseUrl": "http://a1-sim-std-1.nonrtric:8085", "managedElementIds": ["kista_1", "kista_2"]},
  {"name": "ric5", "baseUrl": "http://a1-sim-std2-0.nonrtric:8085", "managedElementIds": ["kista_1", "kista_2"]},
  {"name": "ric6", "baseUrl": "http://a1-sim-std2-1.nonrtric:8085", "managedElementIds": ["kista_1", "kista_2"]}
]' -i "$RECIPE_PATH"

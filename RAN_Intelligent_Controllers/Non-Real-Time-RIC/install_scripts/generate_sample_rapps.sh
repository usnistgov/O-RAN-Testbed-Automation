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
# NIST-developed software is expressly provided 'AS IS.' NIST MAKES NO WARRANTY
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

# Exit immediately if a command fails
set -e

if [ ! -d "rappmanager" ]; then
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/nonrtric/plt/rappmanager.git rappmanager
fi

cd rappmanager/sample-rapp-generator
if [ ! -f generate.previous.sh ]; then
    mv generate.sh generate.previous.sh
fi
cp "$PARENT_DIR/install_patch_files/rappmanager/sample-rapp-generator/generate.sh" .

cd "$PARENT_DIR"
mkdir -p rApps

cd rappmanager/sample-rapp-generator

RAPPS=("rapp-hello-world" "rapp-hello-world-sme-invoker" "rapp-kserve" "rapp-sample-ics-consumer" "rapp-sample-ics-producer" "rapp-simple-ics-consumer" "rapp-simple-ics-producer" "rapp-simple-ics-consumer" "rapp-all")

INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
IP_ADDRESS=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

# Iterate over each rApp
for RAPP in "${RAPPS[@]}"; do
    if [ -d "$RAPP" ]; then
        echo
        echo "Configuring then generating ${RAPP} rApp binary (${RAPP}.csar)..."

        # Configure the rApp by setting the Chart Museum post charts URI
        ASD_YAML="$RAPP/Definitions/asd.yaml"
        if [ -f $ASD_YAML ]; then
            PRODUCER_URI_EXISTS=$(yq eval '.topology_template.node_templates.applicationServiceDescriptor.artifacts.producer.properties.target_server_uri' "$ASD_YAML")
            if [ "$PRODUCER_URI_EXISTS" != "null" ]; then
                yq eval ".topology_template.node_templates.applicationServiceDescriptor.artifacts.producer.properties.target_server_uri = \"http://$IP_ADDRESS:8879/charts/api/charts\"" -i "$ASD_YAML"
                echo "    Configured producer of rApp asd.yaml."
            fi

            CONSUMER_URI_EXISTS=$(yq eval '.topology_template.node_templates.applicationServiceDescriptor.artifacts.consumer.properties.target_server_uri' "$ASD_YAML")
            if [ "$CONSUMER_URI_EXISTS" != "null" ]; then
                yq eval ".topology_template.node_templates.applicationServiceDescriptor.artifacts.consumer.properties.target_server_uri = \"http://$IP_ADDRESS:8879/charts/api/charts\"" -i "$ASD_YAML"
                echo "    Configured consumer of rApp asd.yaml."
            fi

            # Check for any remaining variables to set
            if grep -q "UPDATE_THIS_CHART_MUSEUM_POST_CHARTS_URI" "$ASD_YAML"; then
                sed -i "s|UPDATE_THIS_CHART_MUSEUM_POST_CHARTS_URI|http://$IP_ADDRESS:8879/charts/api/charts|g" "$ASD_YAML"
                echo "    Configured remaining URIs of rApp asd.yaml."
            fi
        fi
        K8S_INSTANCE_JSON="$RAPP/Files/Acm/instances/k8s-instance.json"
        if [ -f $K8S_INSTANCE_JSON ]; then

            # Check for any variables to set
            if grep -q "UPDATE_THIS_CHART_MUSEUM_GET_CHARTS_URI" "$K8S_INSTANCE_JSON"; then
                sed -i "s|UPDATE_THIS_CHART_MUSEUM_GET_CHARTS_URI|http://$IP_ADDRESS:8879/charts/api/charts|g" "$K8S_INSTANCE_JSON"
                echo "    Configured URIs of rApp k8s-instance.json."
            fi
            if grep -q "UPDATE_THIS_MACHINE_IP" "$K8S_INSTANCE_JSON"; then
                sed -i "s|UPDATE_THIS_MACHINE_IP|$IP_ADDRESS|g" "$K8S_INSTANCE_JSON"
                echo "    Configured machine IP of rApp k8s-instance.json."
            fi
        fi

        ./generate.sh "$RAPP"
        echo "Moving rApp binary to rApps directory..."
        cp "${RAPP}.csar" "$PARENT_DIR/rApps"
    else
        echo "Could not find rappmanager/sample-rapp-generator/${RAPP}, skipping."
    fi
done

echo
echo "Successfully generated sample rApp binaries."

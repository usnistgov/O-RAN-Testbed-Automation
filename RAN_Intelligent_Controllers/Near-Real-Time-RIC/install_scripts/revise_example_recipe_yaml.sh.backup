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
cd "$(dirname "$SCRIPT_DIR")"

# Get the local IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Get the file path from the command line argument
RECIPE_PATH=$1

# Check if the file path is provided
if [[ -z "$RECIPE_PATH" ]]; then
    echo "Error: No file path provided."
    echo "Usage: $0 <path_to_yaml_file>"
    exit 1
fi

# Check if the file exists and is readable
if [[ ! -f "$RECIPE_PATH" ]]; then
    echo "Error: File '$RECIPE_PATH' does not exist."
    exit 1
fi

if [[ ! -r "$RECIPE_PATH" ]]; then
    echo "Error: File '$RECIPE_PATH' is not readable."
    exit 1
fi

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo ./install_scripts/install_yq.sh
fi

# Update IP addresses using yq
yq e -i ".extsvcplt.ricip = \"${IP_ADDRESS}\"" "$RECIPE_PATH"
yq e -i ".extsvcplt.auxip = \"${IP_ADDRESS}\"" "$RECIPE_PATH"
echo "IP addresses updated to: $IP_ADDRESS in the file $RECIPE_PATH"

# Update Prometheus URL using yq
PROMETHEUS_NEW_URL="http://r4-infrastructure-prometheus-server.ricinfra"
if yq e '.vespamgr.prometheusurl' "$RECIPE_PATH" >/dev/null; then
    yq e -i ".vespamgr.prometheusurl = \"${PROMETHEUS_NEW_URL}\"" "$RECIPE_PATH"
    echo "Prometheus URL updated to $PROMETHEUS_NEW_URL in the file $RECIPE_PATH"
else
    echo "No Prometheus URL found in the vespamgr section of $RECIPE_PATH"
fi

# Command template for liveness and readiness probes
PROBE_COMMAND="ip=\$(hostname -i); export RMR_SRC_ID=\$ip; /opt/e2/rmr_probe -h \$ip:38000"

# Update liveness probe
yq e -i "del(.e2term.alpha.livenessProbe)" "$RECIPE_PATH" # Clear existing probe if any
yq e -i ".e2term.alpha.livenessProbe.exec.command = [\"/bin/sh\", \"-c\", \"${PROBE_COMMAND}\"]" "$RECIPE_PATH"
yq e -i ".e2term.alpha.livenessProbe.timeoutSeconds = 5" "$RECIPE_PATH"
yq e -i ".e2term.alpha.livenessProbe.periodSeconds = 10" "$RECIPE_PATH"
yq e -i ".e2term.alpha.livenessProbe.successThreshold = 1" "$RECIPE_PATH"
yq e -i ".e2term.alpha.livenessProbe.failureThreshold = 3" "$RECIPE_PATH"

# Update readiness probe
yq e -i "del(.e2term.alpha.readinessProbe)" "$RECIPE_PATH" # Clear existing probe if any
yq e -i ".e2term.alpha.readinessProbe.exec.command = [\"/bin/sh\", \"-c\", \"${PROBE_COMMAND}\"]" "$RECIPE_PATH"
yq e -i ".e2term.alpha.readinessProbe.initialDelaySeconds = 120" "$RECIPE_PATH"
yq e -i ".e2term.alpha.readinessProbe.timeoutSeconds = 5" "$RECIPE_PATH"
yq e -i ".e2term.alpha.readinessProbe.periodSeconds = 60" "$RECIPE_PATH"
yq e -i ".e2term.alpha.readinessProbe.successThreshold = 1" "$RECIPE_PATH"
yq e -i ".e2term.alpha.readinessProbe.failureThreshold = 3" "$RECIPE_PATH"

echo "Probes updated in the file $RECIPE_PATH"

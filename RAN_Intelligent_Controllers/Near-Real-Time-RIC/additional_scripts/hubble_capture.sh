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

set -e

echo "# Script: $(realpath $0)..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

# If command hubble doesn't exist
if ! command -v hubble &>/dev/null; then
    echo "Hubble command not found. Installing hubble..."
    HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
    HUBBLE_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
    rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

    echo "Waiting for Cilium to be ready..."
    until cilium status --wait; do
        echo "Continuing to wait for Cilium to be ready..."
        sleep 5
    done
fi

LOG_PATH="$PARENT_DIR/logs/hubble_captured_flows.csv"
mkdir -p "$PARENT_DIR/logs"

if ! pgrep -f "cilium hubble port-forward" >/dev/null; then
    echo "Starting Hubble port-forward..."
    cilium hubble port-forward &
fi

if [ ! -f "$LOG_PATH" ]; then
    HEADER=""
    HEADER+="Timestamp (readable),"
    HEADER+="UNIX Epoch (seconds),"
    HEADER+="Summary,"
    HEADER+="Is Reply,"
    HEADER+="Source IP,"
    HEADER+="Destination IP,"
    HEADER+="Source Port,"
    HEADER+="Destination Port,"
    HEADER+="Source Pod,"
    HEADER+="Destination Pod,"
    HEADER+="Source Namespace,"
    HEADER+="Destination Namespace,"
    HEADER+="Protocol,"
    HEADER+="Layer 4,"
    echo "$HEADER" >"$LOG_PATH"
fi

echo
echo "Starting to Observe Flows (Output File: logs/hubble_captured_flows.csv)..."
#hubble observe --follow -o json | while read -r JSON; do
hubble observe --namespace ricxapp --follow -o json | while read -r JSON; do
    TIMESTAMP=$(echo "$JSON" | jq -r '.flow.time')
    SECONDS=$(date -d "${TIMESTAMP}" +"%s")
    FRACTION=$(echo "${TIMESTAMP}" | awk -F'[.Z]' '{print $2}')
    PROTOCOL=$(echo "$JSON" | jq -r '.flow.l4 | keys_unsorted[0]')
    LAYER4=$(echo "$JSON" | jq -cr ".flow.l4[\"$PROTOCOL\"]")

    LINE="\"$TIMESTAMP\","                                                           # Timestamp
    LINE+="$SECONDS.$FRACTION,"                                                      # UNIX Epoch (seconds)
    LINE+="\"$(echo "$JSON" | jq -cr '.flow.Summary' | sed 's/"/'"'"'/g')\","        # Summary
    LINE+="$(echo "$JSON" | jq -r '.flow.is_reply'),"                                # Is Reply
    LINE+="$(echo "$JSON" | jq -r '.flow.IP.source'),"                               # Source IP
    LINE+="$(echo "$JSON" | jq -r '.flow.IP.destination'),"                          # Destination IP
    LINE+="$(echo "$LAYER4" | jq -r '.source_port' | sed 's/null//g'),"              # Source Port
    LINE+="$(echo "$LAYER4" | jq -r '.destination_port' | sed 's/null//g'),"         # Destination Port
    LINE+="$(echo "$JSON" | jq -r '.flow.source.pod_name' | sed 's/null//g'),"       # Source Pod
    LINE+="$(echo "$JSON" | jq -r '.flow.destination.pod_name' | sed 's/null//g'),"  # Destination Pod
    LINE+="$(echo "$JSON" | jq -r '.flow.source.namespace' | sed 's/null//g'),"      # Source Namespace
    LINE+="$(echo "$JSON" | jq -r '.flow.destination.namespace' | sed 's/null//g')," # Destination Namespace
    LINE+="\"$PROTOCOL\","                                                           # Protocol
    LINE+="\"$(echo "$LAYER4" | sed 's/"/'"'"'/g')\""

    echo "$LINE" >>"$LOG_PATH"
    echo -n "."
done

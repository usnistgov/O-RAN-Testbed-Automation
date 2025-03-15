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

# Install Wireshark if not already installed
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

sudo ./install_and_configure_wireshark.sh

# Check if krew is installed
if ! kubectl krew >/dev/null 2>&1; then
    echo "Krew is not installed. Installing Krew..."
    (# Code from (https://krew.sigs.k8s.io/docs/user-guide/setup/install/#bash):
        set -x
        cd "$(mktemp -d)" &&
            OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
            ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
            KREW="krew-${OS}_${ARCH}" &&
            curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
            tar zxvf "${KREW}.tar.gz" &&
            ./"${KREW}" install krew
    )
    # Dynamically update the PATH for the current shell session
    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
    echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >>$HOME/.bashrc
    echo "Krew installation complete."
fi

# Check if kubectl-sniff plugin is installed
if ! kubectl krew list | grep -q 'sniff'; then
    echo "Installing kubectl-sniff plugin..."
    kubectl krew install sniff
    echo
fi
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

POD_INFO=($(kubectl get pods --all-namespaces --no-headers | awk '{print $1 ":" $2}'))
echo
echo "List of Kubernetes pods:"
for INDEX in "${!POD_INFO[@]}"; do
    echo -e "  [$((INDEX + 1))]\t${POD_INFO[$INDEX]}"
done
echo
read -p "Enter the pod number to capture packets from: " POD_CHOICE

if [[ ! "$POD_CHOICE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input: Please enter a numeric value."
    exit 1
fi
POD_CHOICE_INDEX=$((POD_CHOICE - 1))
if [ $POD_CHOICE_INDEX -lt 0 ] || [ $POD_CHOICE_INDEX -ge ${#POD_INFO[@]} ]; then
    echo "Invalid pod number: Please enter a number between 1 and ${#POD_INFO[@]}."
    exit 1
fi

# Fetch pod name and namespace from choice
POD_NAME=$(kubectl get pods --all-namespaces | awk 'NR>1 {print $2}' | sed -n "${POD_CHOICE}p")
NAMESPACE=$(kubectl get pods --all-namespaces | awk 'NR>1 {print $1}' | sed -n "${POD_CHOICE}p")

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PCAP_DIR="$SCRIPT_DIR/pod_pcaps"
mkdir -p "$PCAP_DIR"
OUTPUT_FILE="$PCAP_DIR/${POD_NAME}.pcap"

echo "Starting packet capture for pod $POD_NAME in namespace $NAMESPACE, output file: $OUTPUT_FILE..."
echo
kubectl sniff $POD_NAME -n $NAMESPACE -o $OUTPUT_FILE

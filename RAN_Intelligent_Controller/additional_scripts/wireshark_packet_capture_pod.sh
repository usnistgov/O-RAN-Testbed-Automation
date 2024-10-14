#!/bin/bash

# Install Wireshark if not already installed
if ! dpkg -s "wireshark" &> /dev/null; then
    echo "Installing Wireshark..."
    sudo apt update && sudo apt install -y wireshark
fi

# Add user to the Wireshark group if not already a member
if ! groups $USER | grep -q '\bwireshark\b'; then
    echo "Adding $USER to the Wireshark group..."
    sudo usermod -a -G wireshark $USER
fi

# Set permissions for dumpcap
if [[ $(getcap /usr/bin/dumpcap) != "/usr/bin/dumpcap cap_net_admin,cap_net_raw=eip" ]]; then
    echo "Setting permissions for dumpcap..."
    sudo chgrp wireshark /usr/bin/dumpcap
    sudo chmod 750 /usr/bin/dumpcap
    sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
fi

# Check if krew is installed
if ! kubectl krew > /dev/null 2>&1; then
    echo "Krew is not installed. Installing Krew..."
    (
      set -x; cd "$(mktemp -d)" &&
      OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
      ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
      KREW="krew-${OS}_${ARCH}" &&
      curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
      tar zxvf "${KREW}.tar.gz" &&
      ./"${KREW}" install krew
    )
    # Dynamically update the PATH for the current shell session
    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
    echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
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
for i in "${!POD_INFO[@]}"; do
    echo -e "  [$((i+1))]\t${POD_INFO[$i]}"
done
echo
read -p "Enter the pod number to capture packets from: " POD_CHOICE

if [[ ! "$POD_CHOICE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input: Please enter a numeric value."
    exit 1
fi
POD_CHOICE_INDEX=$((POD_CHOICE-1))
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

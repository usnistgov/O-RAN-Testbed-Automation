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

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

UE_NUMBER=$1

if [[ -z "$UE_NUMBER" ]]; then
    echo "ERROR: No UE number provided."
    echo "Usage: $0 <UE_NUMBER>"
    exit 1
fi
if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
    echo "ERROR: UE number must be a number."
    exit 1
fi

UE_NAMESPACE="ue$UE_NUMBER"

# Give the UE its own network namespace and configure it to access the host network
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Allocate a /29 (8 addresses) subnet per UE (e.g., UE 1 -> 10.201.0.8/29, Gateway .9, UE .10)
BASE_SUBNET="10.201.0.0/16"
SUBNET_SIZE=8

# Calculate IP offsets
SUBNET_OFFSET=$((UE_NUMBER * SUBNET_SIZE))
HOST_IP_OFFSET=$((SUBNET_OFFSET + 1)) # .5
UE_IP_OFFSET=$((SUBNET_OFFSET + 2))   # .6

# Fetch IPs from subnet using python script
UE_SUBNET_ID=$(python3 fetch_nth_ip.py "$BASE_SUBNET" $SUBNET_OFFSET)
UE_HOST_IP=$(python3 fetch_nth_ip.py "$BASE_SUBNET" $HOST_IP_OFFSET)
UE_NS_IP=$(python3 fetch_nth_ip.py "$BASE_SUBNET" $UE_IP_OFFSET)

# Clean up existing artifacts for this UE
sudo ip netns delete $UE_NAMESPACE || true
sudo ip link delete v-eth$UE_NUMBER || true

# Create namespace and veth pair
sudo ip netns add $UE_NAMESPACE
sudo ip link add v-eth$UE_NUMBER type veth peer name v-$UE_NAMESPACE
sudo ip link set v-$UE_NAMESPACE netns $UE_NAMESPACE

# Configure host side interface
sudo ip addr add $UE_HOST_IP/29 dev v-eth$UE_NUMBER
sudo ip link set v-eth$UE_NUMBER up

# Configure NAT to masquerade traffic and allow forwarding
sudo iptables -t nat -A POSTROUTING -s "$UE_SUBNET_ID/29" -o "$NETWORK_INTERFACE" -j MASQUERADE
sudo iptables -A FORWARD -i "$NETWORK_INTERFACE" -o v-eth$UE_NUMBER -j ACCEPT
sudo iptables -A FORWARD -o "$NETWORK_INTERFACE" -i v-eth$UE_NUMBER -j ACCEPT

# Configure namespace side interface
sudo ip netns exec $UE_NAMESPACE ip link set dev lo up
sudo ip netns exec $UE_NAMESPACE ip addr add $UE_NS_IP/29 dev v-$UE_NAMESPACE
sudo ip netns exec $UE_NAMESPACE ip link set v-$UE_NAMESPACE up

# Set default route in namespace to point to host gateway
sudo ip netns exec $UE_NAMESPACE ip route add default via $UE_HOST_IP

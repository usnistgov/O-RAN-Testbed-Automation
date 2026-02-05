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

DU_NUMBER=$1

if [[ -z "$DU_NUMBER" ]]; then
    echo "ERROR: No DU number provided."
    echo "Usage: $0 <DU_NUMBER>"
    exit 1
fi
if ! [[ $DU_NUMBER =~ ^[0-9]+$ ]]; then
    echo "ERROR: DU number must be a number."
    exit 1
fi

DU_NAMESPACE="du$DU_NUMBER"

# Give the DU its own network namespace and configure it to access the host network
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Allocate a /29 (8 addresses) subnet per DU (e.g., DU 1 -> 10.200.0.8/29, Gateway .9, DU .10)
BASE_SUBNET="10.200.0.0/16"
SUBNET_SIZE=8

# Calculate IP offsets
SUBNET_OFFSET=$((DU_NUMBER * SUBNET_SIZE))
HOST_IP_OFFSET=$((SUBNET_OFFSET + 1)) # .5
DU_IP_OFFSET=$((SUBNET_OFFSET + 2))   # .6

# Fetch IPs from subnet using python script
DU_SUBNET_ID=$(python3 fetch_nth_ip.py "$BASE_SUBNET" $SUBNET_OFFSET)
DU_HOST_IP=$(python3 fetch_nth_ip.py "$BASE_SUBNET" $HOST_IP_OFFSET)
DU_NS_IP=$(python3 fetch_nth_ip.py "$BASE_SUBNET" $DU_IP_OFFSET)

# Clean up existing artifacts for this DU
sudo ip netns delete $DU_NAMESPACE || true
sudo ip link delete v-eth-du$DU_NUMBER || true

# Create namespace and veth pair
sudo ip netns add $DU_NAMESPACE
sudo ip link add v-eth-du$DU_NUMBER type veth peer name v-$DU_NAMESPACE
sudo ip link set v-$DU_NAMESPACE netns $DU_NAMESPACE

# Configure host side interface
sudo ip addr add $DU_HOST_IP/29 dev v-eth-du$DU_NUMBER
sudo ip link set v-eth-du$DU_NUMBER up

# Configure NAT to masquerade traffic and allow forwarding
sudo iptables -t nat -A POSTROUTING -s "$DU_SUBNET_ID/29" -o "$NETWORK_INTERFACE" -j MASQUERADE
sudo iptables -A FORWARD -i "$NETWORK_INTERFACE" -o v-eth-du$DU_NUMBER -j ACCEPT
sudo iptables -A FORWARD -o "$NETWORK_INTERFACE" -i v-eth-du$DU_NUMBER -j ACCEPT

# Configure namespace side interface
sudo ip netns exec $DU_NAMESPACE ip link set dev lo up
sudo ip netns exec $DU_NAMESPACE ip addr add $DU_NS_IP/29 dev v-$DU_NAMESPACE
sudo ip netns exec $DU_NAMESPACE ip link set v-$DU_NAMESPACE up

# Set default route in namespace to point to host gateway
sudo ip netns exec $DU_NAMESPACE ip route add default via $DU_HOST_IP

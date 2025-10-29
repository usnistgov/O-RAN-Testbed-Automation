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

UE_DU_NS_SUBNET="10.200.0.0/16" # Must match setup_du_namespace.sh
UE_IP_OFFSET=256                # Must match revert_ue_namespace.sh

# Shared bridge (single L2 for all rf-sim instances)
BRIDGE_NAME="br-rfsim"
BRIDGE_GW_IP="10.200.0.1"
BRIDGE_CIDR="$BRIDGE_GW_IP/16"

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
UE_NS_IP=$(python3 fetch_nth_ip.py $UE_DU_NS_SUBNET $((UE_IP_OFFSET + UE_NUMBER)))

# Give the UE its own network namespace and configure it to access the host network
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Ensure shared bridge exists
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
if ! ip link show "$BRIDGE_NAME" >/dev/null 2>&1; then
    sudo ip link add "$BRIDGE_NAME" type bridge
    sudo ip addr add "$BRIDGE_CIDR" dev "$BRIDGE_NAME"
    sudo ip link set "$BRIDGE_NAME" up
fi
# Ensure single MASQUERADE from shared subnet
if ! sudo iptables -t nat -C POSTROUTING -s "$UE_DU_NS_SUBNET" -o "$NETWORK_INTERFACE" -j MASQUERADE 2>/dev/null; then
    sudo iptables -t nat -A POSTROUTING -s "$UE_DU_NS_SUBNET" -o "$NETWORK_INTERFACE" -j MASQUERADE
fi

# Code from (https://open-cells.com/index.php/2021/02/08/rf-simulator-1-enb-2-ues-all-in-one):
sudo ip netns delete $UE_NAMESPACE || true
sudo ip link delete v-eth$UE_NUMBER || true
sudo ip netns add $UE_NAMESPACE
sudo ip link add v-eth$UE_NUMBER type veth peer name v-$UE_NAMESPACE
sudo ip link set v-$UE_NAMESPACE netns $UE_NAMESPACE

# Attach host end to shared bridge (no IP on host veth)
sudo ip link set v-eth$UE_NUMBER master $BRIDGE_NAME
sudo ip link set v-eth$UE_NUMBER up

sudo ip netns exec $UE_NAMESPACE ip link set dev lo up
sudo ip netns exec $UE_NAMESPACE ip addr add $UE_NS_IP/16 dev v-$UE_NAMESPACE
sudo ip netns exec $UE_NAMESPACE ip link set v-$UE_NAMESPACE up
sudo ip netns exec $UE_NAMESPACE ip route add default via $BRIDGE_GW_IP

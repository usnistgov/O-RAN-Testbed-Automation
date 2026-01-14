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

UE_DU_NS_SUBNET="10.200.0.0/16" # Must match setup_ue_namespace.sh
DU_IP_OFFSET=10                 # Must match revert_du_namespace.sh

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
DU_NS_IP=$(python3 fetch_nth_ip.py $UE_DU_NS_SUBNET $((DU_IP_OFFSET + DU_NUMBER)))

# Give the DU its own network namespace and configure it to access the host network
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Use the host IP as the gateway for the DU namespace (e.g. 10.200.0.1)
DU_HOST_IP=$(python3 fetch_nth_ip.py $UE_DU_NS_SUBNET 1)

# Ensure single MASQUERADE from shared subnet
if ! sudo iptables -t nat -C POSTROUTING -s "$UE_DU_NS_SUBNET" -o "$NETWORK_INTERFACE" -j MASQUERADE 2>/dev/null; then
    sudo iptables -t nat -A POSTROUTING -s "$UE_DU_NS_SUBNET" -o "$NETWORK_INTERFACE" -j MASQUERADE
fi

# Allow forwarding between host primary interface and the DU veth
sudo iptables -A FORWARD -i $NETWORK_INTERFACE -o v-eth-du$DU_NUMBER -j ACCEPT || true
sudo iptables -A FORWARD -o $NETWORK_INTERFACE -i v-eth-du$DU_NUMBER -j ACCEPT || true

# Code from (https://open-cells.com/index.php/2021/02/08/rf-simulator-1-enb-2-ues-all-in-one):
sudo ip netns delete $DU_NAMESPACE || true
sudo ip link delete v-eth-du$DU_NUMBER || true
sudo ip netns add $DU_NAMESPACE
sudo ip link add v-eth-du$DU_NUMBER type veth peer name v-$DU_NAMESPACE
sudo ip link set v-$DU_NAMESPACE netns $DU_NAMESPACE

# Configure host side of veth
sudo ip addr add $DU_HOST_IP/16 dev v-eth-du$DU_NUMBER || true
sudo ip link set v-eth-du$DU_NUMBER up

sudo ip netns exec $DU_NAMESPACE ip link set dev lo up
sudo ip netns exec $DU_NAMESPACE ip addr add $DU_NS_IP/16 dev v-$DU_NAMESPACE
sudo ip netns exec $DU_NAMESPACE ip link set v-$DU_NAMESPACE up
sudo ip netns exec $DU_NAMESPACE ip route add default via $DU_HOST_IP

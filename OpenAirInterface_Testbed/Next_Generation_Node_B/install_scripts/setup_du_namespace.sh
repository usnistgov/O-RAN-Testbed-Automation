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
    echo "Error: No DU number provided."
    echo "Usage: $0 <DU_NUMBER>"
    exit 1
fi
if ! [[ $DU_NUMBER =~ ^[0-9]+$ ]]; then
    echo "Error: DU number must be a number."
    exit 1
fi

DU_NAMESPACE="du$DU_NUMBER"

# Give the DU its own network namespace and configure it to access the host network
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')
DU_INDEX=$((DU_NUMBER - 1))

# Fetch the base IP using the Python script
BASE_IP=$(python3 fetch_nth_ip.py 0.10.202.0/24 $DU_INDEX)
DU_SUBNET_FIRST_3_OCTETS=$(echo $BASE_IP | cut -d. -f2-4)
DU_HOST_IP=$DU_SUBNET_FIRST_3_OCTETS.1
DU_NS_IP=$DU_SUBNET_FIRST_3_OCTETS.2

echo "Subnet is $DU_SUBNET_FIRST_3_OCTETS.0/24"
echo "Host IP is $DU_HOST_IP"
echo "Namespace IP is $DU_NS_IP"
exit 0

# Code from (https://open-cells.com/index.php/2021/02/08/rf-simulator-1-enb-2-ues-all-in-one):
sudo ip netns delete $DU_NAMESPACE || true
sudo ip link delete v-eth-du$DU_NUMBER || true
sudo ip netns add $DU_NAMESPACE
sudo ip link add v-eth-du$DU_NUMBER type veth peer name v-$DU_NAMESPACE
sudo ip link set v-$DU_NAMESPACE netns $DU_NAMESPACE
sudo ip addr add $DU_HOST_IP/24 dev v-eth-du$DU_NUMBER
sudo ip link set v-eth-du$DU_NUMBER up
sudo iptables -t nat -A POSTROUTING -s $DU_SUBNET_FIRST_3_OCTETS.0/24 -o $NETWORK_INTERFACE -j MASQUERADE
# Allow forwarding between host primary interface and the DU veth
sudo iptables -A FORWARD -i $NETWORK_INTERFACE -o v-eth-du$DU_NUMBER -j ACCEPT
sudo iptables -A FORWARD -o $NETWORK_INTERFACE -i v-eth-du$DU_NUMBER -j ACCEPT

sudo ip netns exec $DU_NAMESPACE ip link set dev lo up
sudo ip netns exec $DU_NAMESPACE ip addr add $DU_NS_IP/24 dev v-$DU_NAMESPACE
sudo ip netns exec $DU_NAMESPACE ip link set v-$DU_NAMESPACE up
sudo ip netns exec $DU_NAMESPACE ip route add default via $DU_HOST_IP

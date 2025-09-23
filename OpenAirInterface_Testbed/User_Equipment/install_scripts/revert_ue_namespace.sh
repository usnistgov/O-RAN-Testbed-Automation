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

# Do not exit immediately if a command fails
set +e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

UE_NUMBER=$1

if [[ -z "$UE_NUMBER" ]]; then
    echo "Error: No UE number provided."
    echo "Usage: $0 <UE_NUMBER>"
    exit 1
fi
if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
    echo "Error: UE number must be a number."
    exit 1
fi

UE_NAMESPACE="ue$UE_NUMBER"

# Give the UE its own network namespace and configure it to access the host network
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')
# Fetch the base IP using the Python script
BASE_IP=$(python3 fetch_nth_ip.py 0.10.201.0/24 $((UE_NUMBER - 1)))
UE_SUBNET_FIRST_3_OCTETS=$(echo $BASE_IP | cut -d. -f2-4)
UE_HOST_IP=$UE_SUBNET_FIRST_3_OCTETS.1
UE_NS_IP=$UE_SUBNET_FIRST_3_OCTETS.2

echo "Removing IP routes and addresses inside the namespace..."
sudo ip netns exec $UE_NAMESPACE ip route del default via $UE_HOST_IP
sudo ip netns exec $UE_NAMESPACE ip addr del $UE_NS_IP/24 dev v-$UE_NAMESPACE
sudo ip netns exec $UE_NAMESPACE ip link set v-$UE_NAMESPACE down

echo "Removing iptables rules..."
sudo iptables -D FORWARD -o $NETWORK_INTERFACE -i v-eth$UE_NUMBER -j ACCEPT
sudo iptables -D FORWARD -i $NETWORK_INTERFACE -o v-eth$UE_NUMBER -j ACCEPT
sudo iptables -t nat -D POSTROUTING -s $UE_SUBNET_FIRST_3_OCTETS.0/24 -o $NETWORK_INTERFACE -j MASQUERADE

echo "Deleting the network devices..."
sudo ip link set v-eth$UE_NUMBER down
sudo ip link del v-eth$UE_NUMBER

echo "Deleting the network namespace..."
sudo ip netns del $UE_NAMESPACE

echo "Successfully reverted the UE $UE_NUMBER namespace."

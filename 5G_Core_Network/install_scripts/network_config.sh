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
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Check if the tun interface already exists, if not, add it
if ! ip link show ogstun >/dev/null 2>&1; then
    echo "Adding TUN interface ogstun..."
    sudo ip tuntap add name ogstun mode tun
fi
if ! ip link show ogstun2 >/dev/null 2>&1; then
    echo "Adding TUN interface ogstun2..."
    sudo ip tuntap add name ogstun2 mode tun
fi
if ! ip link show ogstun3 >/dev/null 2>&1; then
    echo "Adding TUN interface ogstun3..."
    sudo ip tuntap add name ogstun3 mode tun
fi

echo "Running Open5GS netconf.sh script..."
cd open5gs/misc
sudo ./netconf.sh
cd ..

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Check if the iptables MASQUERADE rule already exists, if not, add it
if ! sudo iptables --wait -t nat -C POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null; then
    echo "Adding iptables MASQUERADE rule for IPv4..."
    sudo iptables --wait -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
fi

# Check if the ip6tables MASQUERADE rule already exists, if not, add it
if ! sudo ip6tables --wait -t nat -C POSTROUTING -s cafe::/64 -o ogstun -j MASQUERADE 2>/dev/null; then
    echo "Adding ip6tables MASQUERADE rule for IPv6..."
    sudo ip6tables --wait -t nat -A POSTROUTING -s cafe::/64 -o ogstun -j MASQUERADE 2>/dev/null
fi

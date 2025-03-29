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

if [ ! -f options.yaml ]; then
    echo "File options.yaml does not exist. Please generate configurations first."
    exit 1
fi

default_ogstun_ipv4=10.45.0.0/16
default_ogstun_ipv6=2001:db8:cafe::/48
default_ogstun2_ipv4=10.46.0.0/16
default_ogstun2_ipv6=2001:db8:babe::/48
default_ogstun3_ipv4=10.47.0.0/16
default_ogstun3_ipv6=2001:db8:face::/48
ogstun_ipv4=$(yq eval '.ogstun_ipv4' options.yaml)
ogstun_ipv6=$(yq eval '.ogstun_ipv6' options.yaml)
ogstun2_ipv4=$(yq eval '.ogstun2_ipv4' options.yaml)
ogstun2_ipv6=$(yq eval '.ogstun2_ipv6' options.yaml)
ogstun3_ipv4=$(yq eval '.ogstun3_ipv4' options.yaml)
ogstun3_ipv6=$(yq eval '.ogstun3_ipv6' options.yaml)

# Extract the first IPv4 address from a CIDR block by replacing the last octet with '.1'
# For example, 10.45.0.0/16 --> 10.45.0.1/16
grab_first_ipv4_address() {
    local IP=$1
    echo ${IP%.*}.1/${IP#*/}
}

# Extract the first IPv6 address from a CIDR block by replacing the suffix with '::1'.
# For example, 2001:db8:cafe::/48 --> 2001:db8:cafe::1/48
grab_first_ipv6_address() {
    local IP=$1
    echo ${IP%::*}::1/${IP#*/}
}

# Extract the first IPv4 and IPv6 addresses from the CIDR blocks
default_ogstun_ipv4_1=$(grab_first_ipv4_address "$default_ogstun_ipv4")
default_ogstun_ipv6_1=$(grab_first_ipv6_address "$default_ogstun_ipv6")
default_ogstun2_ipv4_1=$(grab_first_ipv4_address "$default_ogstun2_ipv4")
default_ogstun2_ipv6_1=$(grab_first_ipv6_address "$default_ogstun2_ipv6")
default_ogstun3_ipv4_1=$(grab_first_ipv4_address "$default_ogstun3_ipv4")
default_ogstun3_ipv6_1=$(grab_first_ipv6_address "$default_ogstun3_ipv6")
ogstun_ipv4_1=$(grab_first_ipv4_address "$ogstun_ipv4")
ogstun_ipv6_1=$(grab_first_ipv6_address "$ogstun_ipv6")
ogstun2_ipv4_1=$(grab_first_ipv4_address "$ogstun2_ipv4")
ogstun2_ipv6_1=$(grab_first_ipv6_address "$ogstun2_ipv6")
ogstun3_ipv4_1=$(grab_first_ipv4_address "$ogstun3_ipv4")
ogstun3_ipv6_1=$(grab_first_ipv6_address "$ogstun3_ipv6")

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

echo "Checking and assigning IP addresses to TUN device..."
if ! ip addr show ogstun | grep -q "$default_ogstun_ipv4_1"; then
    sudo ip addr add $default_ogstun_ipv4_1 dev ogstun
else
    echo "IP address $default_ogstun_ipv4_1 already assigned to ogstun."
fi

if ! ip addr show ogstun | grep -q "$default_ogstun_ipv6_1"; then
    sudo ip addr add $default_ogstun_ipv6_1 dev ogstun
else
    echo "IPv6 address $default_ogstun_ipv6_1 already assigned to ogstun."
fi

if [ ! -f open5gs/misc/netconf.sh ]; then
    echo "File open5gs/misc/netconf.sh does not exist."
    exit 1
fi

# Escape periods in the IPv4 addresses for sed
default_ogstun_ipv4_esc=$(echo $default_ogstun_ipv4 | sed 's/\./\\./g')
default_ogstun2_ipv4_esc=$(echo $default_ogstun2_ipv4 | sed 's/\./\\./g')
default_ogstun3_ipv4_esc=$(echo $default_ogstun3_ipv4 | sed 's/\./\\./g')
ogstun_ipv4_esc=$(echo $ogstun_ipv4 | sed 's/\./\\./g')
ogstun2_ipv4_esc=$(echo $ogstun2_ipv4 | sed 's/\./\\./g')
ogstun3_ipv4_esc=$(echo $ogstun3_ipv4 | sed 's/\./\\./g')
default_ogstun_ipv4_1_esc=$(echo $default_ogstun_ipv4_1 | sed 's/\./\\./g')
default_ogstun2_ipv4_1_esc=$(echo $default_ogstun2_ipv4_1 | sed 's/\./\\./g')
default_ogstun3_ipv4_1_esc=$(echo $default_ogstun3_ipv4_1 | sed 's/\./\\./g')
ogstun_ipv4_1_esc=$(echo $ogstun_ipv4_1 | sed 's/\./\\./g')
ogstun2_ipv4_1_esc=$(echo $ogstun2_ipv4_1 | sed 's/\./\\./g')
ogstun3_ipv4_1_esc=$(echo $ogstun3_ipv4_1 | sed 's/\./\\./g')

if [ ! -f open5gs/misc/netconf.sh.previous ]; then
    # Backup the original netconf.sh script
    cp open5gs/misc/netconf.sh open5gs/misc/netconf.sh.previous
else
    # Restore the original netconf.sh script
    cp open5gs/misc/netconf.sh.previous open5gs/misc/netconf.sh
fi

sed -i "s|$default_ogstun_ipv4_esc|$ogstun_ipv4_esc|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun_ipv6|$ogstun_ipv6|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun2_ipv4_esc|$ogstun2_ipv4_esc|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun2_ipv6|$ogstun2_ipv6|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun3_ipv4_esc|$ogstun3_ipv4_esc|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun3_ipv6|$ogstun3_ipv6|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun_ipv4_1_esc|$ogstun_ipv4_1_esc|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun_ipv6_1|$ogstun_ipv6_1|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun2_ipv4_1_esc|$ogstun2_ipv4_1_esc|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun2_ipv6_1|$ogstun2_ipv6_1|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun3_ipv4_1_esc|$ogstun3_ipv4_1_esc|g" open5gs/misc/netconf.sh
sed -i "s|$default_ogstun3_ipv6_1|$ogstun3_ipv6_1|g" open5gs/misc/netconf.sh

echo "Running patched Open5GS netconf.sh script..."
cd open5gs/misc
sudo ./netconf.sh
cd ..

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Check if the iptables MASQUERADE rule already exists, if not, add it
if ! sudo iptables --wait -t nat -C POSTROUTING -s $default_ogstun_ipv4 ! -o ogstun -j MASQUERADE 2>/dev/null; then
    echo "Adding iptables MASQUERADE rule for IPv4..."
    sudo iptables --wait -t nat -A POSTROUTING -s $default_ogstun_ipv4 ! -o ogstun -j MASQUERADE
fi

# Check if the ip6tables MASQUERADE rule already exists, if not, add it
if ! sudo ip6tables --wait -t nat -C POSTROUTING -s $default_ogstun_ipv6 -o ogstun -j MASQUERADE 2>/dev/null; then
    echo "Adding ip6tables MASQUERADE rule for IPv6..."
    sudo ip6tables --wait -t nat -A POSTROUTING -s $default_ogstun_ipv6 -o ogstun -j MASQUERADE 2>/dev/null
fi

echo "Configured network settings for Open5GS."

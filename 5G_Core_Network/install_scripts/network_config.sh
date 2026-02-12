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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if [ ! -f options.yaml ]; then
    echo "File options.yaml does not exist. Please generate configurations first."
    exit 1
fi

DEFAULT_OGSTUN_IPV4=10.45.0.0/16
DEFAULT_OGSTUN_IPV6=2001:db8:cafe::/48
DEFAULT_OGSTUN2_IPV4=10.46.0.0/16
DEFAULT_OGSTUN2_IPV6=2001:db8:babe::/48
DEFAULT_OGSTUN3_IPV4=10.47.0.0/16
DEFAULT_OGSTUN3_IPV6=2001:db8:face::/48
OGSTUN_IPV4=$(yq eval '.ogstun_ipv4' options.yaml)
OGSTUN_IPV6=$(yq eval '.ogstun_ipv6' options.yaml)
OGSTUN2_IPV4=$(yq eval '.ogstun2_ipv4' options.yaml)
OGSTUN2_IPV6=$(yq eval '.ogstun2_ipv6' options.yaml)
OGSTUN3_IPV4=$(yq eval '.ogstun3_ipv4' options.yaml)
OGSTUN3_IPV6=$(yq eval '.ogstun3_ipv6' options.yaml)
if [[ "$OGSTUN_IPV4" == "null" || -z "$OGSTUN_IPV4" ]]; then
    echo "Missing parameter in options.yaml: ogstun_ipv4"
    exit 1
fi
if [[ "$OGSTUN_IPV6" == "null" || -z "$OGSTUN_IPV6" ]]; then
    echo "Missing parameter in options.yaml: ogstun_ipv6"
    exit 1
fi
if [[ "$OGSTUN2_IPV4" == "null" || -z "$OGSTUN2_IPV4" ]]; then
    echo "Missing parameter in options.yaml: ogstun2_ipv4"
    exit 1
fi
if [[ "$OGSTUN2_IPV6" == "null" || -z "$OGSTUN2_IPV6" ]]; then
    echo "Missing parameter in options.yaml: ogstun2_ipv6"
    exit 1
fi
if [[ "$OGSTUN3_IPV4" == "null" || -z "$OGSTUN3_IPV4" ]]; then
    echo "Missing parameter in options.yaml: ogstun3_ipv4"
    exit 1
fi
if [[ "$OGSTUN3_IPV6" == "null" || -z "$OGSTUN3_IPV6" ]]; then
    echo "Missing parameter in options.yaml: ogstun3_ipv6"
    exit 1
fi

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
DEFAULT_OGSTUN_IPV4_1=$(grab_first_ipv4_address "$DEFAULT_OGSTUN_IPV4")
DEFAULT_OGSTUN_IPV6_1=$(grab_first_ipv6_address "$DEFAULT_OGSTUN_IPV6")
DEFAULT_OGSTUN2_IPV4_1=$(grab_first_ipv4_address "$DEFAULT_OGSTUN2_IPV4")
DEFAULT_OGSTUN2_IPV6_1=$(grab_first_ipv6_address "$DEFAULT_OGSTUN2_IPV6")
DEFAULT_OGSTUN3_IPV4_1=$(grab_first_ipv4_address "$DEFAULT_OGSTUN3_IPV4")
DEFAULT_OGSTUN3_IPV6_1=$(grab_first_ipv6_address "$DEFAULT_OGSTUN3_IPV6")
OGSTUN_IPV4_1=$(grab_first_ipv4_address "$OGSTUN_IPV4")
OGSTUN_IPV6_1=$(grab_first_ipv6_address "$OGSTUN_IPV6")
OGSTUN2_IPV4_1=$(grab_first_ipv4_address "$OGSTUN2_IPV4")
OGSTUN2_IPV6_1=$(grab_first_ipv6_address "$OGSTUN2_IPV6")
OGSTUN3_IPV4_1=$(grab_first_ipv4_address "$OGSTUN3_IPV4")
OGSTUN3_IPV6_1=$(grab_first_ipv6_address "$OGSTUN3_IPV6")

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v ip &>/dev/null; then
    echo "Package \"iproute2\" not found, installing..."
    sudo env $APTVARS apt-get install -y iproute2
fi

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
if ! ip addr show ogstun | grep -q "$DEFAULT_OGSTUN_IPV4_1"; then
    sudo ip addr add $DEFAULT_OGSTUN_IPV4_1 dev ogstun
else
    echo "IP address $DEFAULT_OGSTUN_IPV4_1 already assigned to ogstun."
fi

if ! ip addr show ogstun | grep -q "$DEFAULT_OGSTUN_IPV6_1"; then
    sudo ip addr add $DEFAULT_OGSTUN_IPV6_1 dev ogstun
else
    echo "IPv6 address $DEFAULT_OGSTUN_IPV6_1 already assigned to ogstun."
fi

if [ ! -f open5gs/misc/netconf.sh ]; then
    echo "File open5gs/misc/netconf.sh does not exist."
    exit 1
fi

# Escape periods in the IPv4 addresses for sed
DEFAULT_OGSTUN_IPV4_ESC=$(echo $DEFAULT_OGSTUN_IPV4 | sed 's/\./\\./g')
DEFAULT_OGSTUN2_IPV4_ESC=$(echo $DEFAULT_OGSTUN2_IPV4 | sed 's/\./\\./g')
DEFAULT_OGSTUN3_IPV4_ESC=$(echo $DEFAULT_OGSTUN3_IPV4 | sed 's/\./\\./g')
OGSTUN_IPV4_ESC=$(echo $OGSTUN_IPV4 | sed 's/\./\\./g')
OGSTUN2_IPV4_ESC=$(echo $OGSTUN2_IPV4 | sed 's/\./\\./g')
OGSTUN3_IPV4_ESC=$(echo $OGSTUN3_IPV4 | sed 's/\./\\./g')
DEFAULT_OGSTUN_IPV4_1_ESC=$(echo $DEFAULT_OGSTUN_IPV4_1 | sed 's/\./\\./g')
DEFAULT_OGSTUN2_IPV4_1_ESC=$(echo $DEFAULT_OGSTUN2_IPV4_1 | sed 's/\./\\./g')
DEFAULT_OGSTUN3_IPV4_1_ESC=$(echo $DEFAULT_OGSTUN3_IPV4_1 | sed 's/\./\\./g')
OGSTUN_IPV4_1_ESC=$(echo $OGSTUN_IPV4_1 | sed 's/\./\\./g')
OGSTUN2_IPV4_1_ESC=$(echo $OGSTUN2_IPV4_1 | sed 's/\./\\./g')
OGSTUN3_IPV4_1_ESC=$(echo $OGSTUN3_IPV4_1 | sed 's/\./\\./g')

if [ ! -f open5gs/misc/netconf.sh.previous ]; then
    # Backup the original netconf.sh script
    cp open5gs/misc/netconf.sh open5gs/misc/netconf.sh.previous
else
    # Restore the original netconf.sh script
    cp open5gs/misc/netconf.sh.previous open5gs/misc/netconf.sh
fi

sed -i "s|$DEFAULT_OGSTUN_IPV4_ESC|$OGSTUN_IPV4_ESC|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN_IPV6|$OGSTUN_IPV6|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN2_IPV4_ESC|$OGSTUN2_IPV4_ESC|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN2_IPV6|$OGSTUN2_IPV6|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN3_IPV4_ESC|$OGSTUN3_IPV4_ESC|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN3_IPV6|$OGSTUN3_IPV6|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN_IPV4_1_ESC|$OGSTUN_IPV4_1_ESC|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN_IPV6_1|$OGSTUN_IPV6_1|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN2_IPV4_1_ESC|$OGSTUN2_IPV4_1_ESC|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN2_IPV6_1|$OGSTUN2_IPV6_1|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN3_IPV4_1_ESC|$OGSTUN3_IPV4_1_ESC|g" open5gs/misc/netconf.sh
sed -i "s|$DEFAULT_OGSTUN3_IPV6_1|$OGSTUN3_IPV6_1|g" open5gs/misc/netconf.sh

echo "Running patched Open5GS netconf.sh script..."
cd open5gs/misc
sudo ./netconf.sh
cd ..

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1 || true

# Check if the iptables MASQUERADE rule already exists, if not, add it
if ! sudo iptables --wait -t nat -C POSTROUTING -s $DEFAULT_OGSTUN_IPV4 ! -o ogstun -j MASQUERADE 2>/dev/null; then
    echo "Adding iptables MASQUERADE rule for IPv4..."
    sudo iptables --wait -t nat -A POSTROUTING -s $DEFAULT_OGSTUN_IPV4 ! -o ogstun -j MASQUERADE
fi

# Check if the ip6tables MASQUERADE rule already exists, if not, add it
if ! sudo ip6tables --wait -t nat -C POSTROUTING -s $DEFAULT_OGSTUN_IPV6 -o ogstun -j MASQUERADE 2>/dev/null; then
    echo "Adding ip6tables MASQUERADE rule for IPv6..."
    sudo ip6tables --wait -t nat -A POSTROUTING -s $DEFAULT_OGSTUN_IPV6 -o ogstun -j MASQUERADE 2>/dev/null
fi

echo "Configured network settings for Open5GS."

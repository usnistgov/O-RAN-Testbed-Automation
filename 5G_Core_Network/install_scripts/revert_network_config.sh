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

set -e

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

# Remove sysctl settings
if [ -f /etc/sysctl.d/30-open5gs.conf ]; then
    rm /etc/sysctl.d/30-open5gs.conf
    sysctl -p
fi

# Remove IPv4 and IPv6 addresses from the interfaces
for INTERFACE in ogstun ogstun2 ogstun3; do
    if ip link show $INTERFACE >/dev/null 2>&1; then
        sudo ip addr flush dev $INTERFACE
        ip link set $INTERFACE down
        ip link del $INTERFACE
    fi
done

# Remove iptables and ip6tables MASQUERADE rules
sudo iptables --wait -t nat -D POSTROUTING -s $DEFAULT_OGSTUN_IPV4 ! -o ogstun -j MASQUERADE 2>/dev/null || true
sudo ip6tables --wait -t nat -D POSTROUTING -s $DEFAULT_OGSTUN_IPV6 -o ogstun -j MASQUERADE 2>/dev/null || true
sudo iptables --wait -t nat -D POSTROUTING -s $DEFAULT_OGSTUN2_IPV4 ! -o ogstun2 -j MASQUERADE 2>/dev/null || true
sudo ip6tables --wait -t nat -D POSTROUTING -s $DEFAULT_OGSTUN2_IPV6 -o ogstun -j2 MASQUERADE 2>/dev/null || true
sudo iptables --wait -t nat -D POSTROUTING -s $DEFAULT_OGSTUN3_IPV4 ! -o ogstun -j MASQUERADE 2>/dev/null || true
sudo ip6tables --wait -t nat -D POSTROUTING -s $DEFAULT_OGSTUN3_IPV6 -o ogstun -j MASQUERADE 2>/dev/null || true
sudo iptables --wait -t nat -D POSTROUTING -s $OGSTUN_IPV4 ! -o ogstun -j MASQUERADE 2>/dev/null || true
sudo ip6tables --wait -t nat -D POSTROUTING -s $OGSTUN_IPV6 -o ogstun -j MASQUERADE 2>/dev/null || true
sudo iptables --wait -t nat -D POSTROUTING -s $OGSTUN2_IPV4 ! -o ogstun2 -j MASQUERADE 2>/dev/null || true
sudo ip6tables --wait -t nat -D POSTROUTING -s $OGSTUN2_IPV6 -o ogstun -j2 MASQUERADE 2>/dev/null || true
sudo iptables --wait -t nat -D POSTROUTING -s $OGSTUN3_IPV4 ! -o ogstun -j MASQUERADE 2>/dev/null || true
sudo ip6tables --wait -t nat -D POSTROUTING -s $OGSTUN3_IPV6 -o ogstun -j MASQUERADE 2>/dev/null || true

# Disable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
sudo sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null 2>&1 || true

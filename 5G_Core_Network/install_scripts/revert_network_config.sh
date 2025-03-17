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

SYSTEM=$(uname)

if [ "$SYSTEM" = "Linux" ]; then

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

elif [ "$SYSTEM" = "Darwin" ]; then
    # Remove all aliases from lo0
    for i in $(seq 2 20) $(seq 50 50) $(seq 200 202) $(seq 250 252); do
        ifconfig lo0 -alias 127.0.0.$i 2>/dev/null
        ifconfig lo0 -alias 127.0.1.$i 2>/dev/null
        ifconfig lo0 -alias 127.0.2.$i 2>/dev/null
        ifconfig lo0 -alias 127.0.3.$i 2>/dev/null
    done

    # Disable PF and remove any Open5GS specific anchors
    if [ -f /etc/pf.anchors/org.open5gs ]; then
        pfctl -d
        rm /etc/pf.anchors/org.open5gs
        # Reload the default PF configuration
        pfctl -f /etc/pf.conf
        pfctl -e
    fi
fi

# Remove iptables and ip6tables MASQUERADE rules
sudo iptables --wait -t nat -D POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null || true
sudo ip6tables --wait -t nat -D POSTROUTING -s cafe::/64 -o ogstun -j MASQUERADE 2>/dev/null || true

# Disable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
sudo sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null 2>&1

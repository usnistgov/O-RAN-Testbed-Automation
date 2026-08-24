#!/usr/bin/env python3
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

# Usage:
# 	 fetch_nth_ip.py <subnet> <offset>

# For example:
#   fetch_nth_ip.py 192.168.1.0/24 0 returns 192.168.1.1
#   fetch_nth_ip.py 2001:db8::/64 0 returns 2001:db8::1
#   fetch_nth_ip.py 192.168.1.0/24 10 returns 192.168.1.11
#   fetch_nth_ip.py 2001:db8::/64 10 returns 2001:db8::b

import sys
import argparse
import ipaddress


def fetch_nth_address(network_str, offset):
    net = ipaddress.ip_network(network_str, strict=False)
    assert offset >= 0, "Offset must be non-negative"

    if isinstance(net, ipaddress.IPv4Network):
        if net.prefixlen == 32:
            assert offset == 0, "Offset out of range for single-address subnet."
            return net.network_address
        if net.prefixlen == 31:
            assert offset < 2, "Offset out of range for two-address subnet."
            return ipaddress.ip_address(int(net.network_address) + offset)
        # Regular IPv4: skip network and broadcast
        usable = net.num_addresses - 2
        assert offset < usable, f"Offset out of range. Usable range: 0 to {usable-1}"
        return ipaddress.ip_address(int(net.network_address) + 1 + offset)

    if net.prefixlen == 128:  # IPv6
        assert offset == 0, "Offset out of range for single-address subnet."
        return net.network_address

    # Skip the base address by default
    usable = net.num_addresses - 1
    assert offset < usable, f"Offset out of range. Usable range: 0 to {usable-1}"
    return ipaddress.ip_address(int(net.network_address) + 1 + offset)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Return the Nth address from a network.")
    ap.add_argument(
        "subnet", help="Network in CIDR notation, e.g. 192.168.1.0/24 or 2001:db8::/64"
    )
    ap.add_argument("offset", type=int, help="Offset from the first address")
    args = ap.parse_args()
    try:
        ip = fetch_nth_address(args.subnet, args.offset)
        print(str(ip))
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

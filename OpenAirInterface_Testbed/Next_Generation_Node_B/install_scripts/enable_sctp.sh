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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! dpkg -s lksctp-tools >/dev/null 2>&1; then
    sudo apt-get update
    sudo env $APTVARS apt-get install -y lksctp-tools
fi
if ! dpkg -s libsctp1 >/dev/null 2>&1; then
    sudo apt-get update
    sudo env $APTVARS apt-get install -y libsctp1
fi
if ! dpkg -s libsctp-dev >/dev/null 2>&1; then
    sudo apt-get update
    sudo env $APTVARS apt-get install -y libsctp-dev
fi

# Load necessary kernel modules
sudo modprobe overlay || true
sudo modprobe br_netfilter || true

# Load SCTP module
sudo modprobe sctp

# Get the kernel major version
KERNEL_VERSION="$(uname -r | cut -d'-' -f1)"
MAJOR_VERSION="$(echo "$KERNEL_VERSION" | cut -d'.' -f1)"

# Conditional loading of connection tracking modules based on kernel version
if [ "$MAJOR_VERSION" -lt 5 ]; then
    # For older kernels (before version 5), load IPv4 and IPv6 specific modules
    sudo modprobe nf_conntrack_ipv4 || true
    sudo modprobe nf_conntrack_ipv6 || true
    sudo modprobe nf_conntrack_proto_sctp || true
else
    # For newer kernels (version 5 and later), use the unified nf_conntrack module
    sudo modprobe nf_conntrack || true
    sudo modprobe nf_conntrack_sctp || true
fi

echo "SCTP kernel module present:"
lsmod | grep -E '(^| )sctp( |$)' || echo "WARNING: sctp not loaded"

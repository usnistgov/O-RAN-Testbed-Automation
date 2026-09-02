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

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
DU_NAMESPACE_SUBNET="10.200.0.0/16"
NAMESPACE_PREFIX_LENGTH=30

if [ "$1" = "prefix" ] && [ $# -eq 1 ]; then
    echo "$NAMESPACE_PREFIX_LENGTH"
    exit 0
fi
if [ $# -ne 2 ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
    echo "Usage: $0 {prefix|subnet|host|du} [DU_NUMBER]"
    exit 1
fi

if [ "$1" = "subnet" ]; then
    OFFSET_ADDITION=-1
elif [ "$1" = "host" ]; then
    OFFSET_ADDITION=0
elif [ "$1" = "du" ]; then
    OFFSET_ADDITION=1
else
    echo "Usage: $0 {prefix|subnet|host|du} [DU_NUMBER]"
    exit 1
fi

IP_OFFSET=$(($2 * 4 + OFFSET_ADDITION))
python3 "$SCRIPT_DIR/fetch_nth_ip.py" "$DU_NAMESPACE_SUBNET" "$IP_OFFSET"

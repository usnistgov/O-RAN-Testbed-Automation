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

# The script directory respects symbolic links so that the gNB and UE can patch their own openairinterface5g
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

UE_NUMBER=$1
if [ -z "$UE_NUMBER" ]; then
    echo "Usage: $0 <UE_NUMBER>"
    exit 1
fi
if ! [[ "$UE_NUMBER" =~ ^[0-9]+$ ]] || [ "$UE_NUMBER" -lt 1 ]; then
    echo "ERROR: UE number must be a positive integer."
    exit 1
fi

LOG_FILE="$PARENT_DIR/logs/ue${UE_NUMBER}_stdout.txt"
if [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: Log file $LOG_FILE does not exist. Please start UE $UE_NUMBER first."
    exit 1
fi

PDU_SESSIONS=$(sed -n 's/.*Received PDU Session Establishment Accept.*: *\([^[:space:]\r]*\).*/\1/p' "$LOG_FILE" | sort -u)
if [ -z "$PDU_SESSIONS" ]; then
    echo "ERROR: No PDU sessions found for UE $UE_NUMBER."
    exit 1
fi

echo "$PDU_SESSIONS"

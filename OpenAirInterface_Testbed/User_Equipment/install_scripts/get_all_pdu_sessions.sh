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

UE_NUMBERS=("$@")
if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    for UE_LOG in logs/ue*_stdout.txt; do
        [ -e "$UE_LOG" ] || continue
        UE_NAME=$(basename "$UE_LOG")
        UE_NUMBER="${UE_NAME#ue}"
        UE_NUMBER="${UE_NUMBER%_stdout.txt}"
        if [[ "$UE_NUMBER" =~ ^[0-9]+$ ]]; then
            UE_NUMBERS+=("$UE_NUMBER")
        fi
    done
fi

if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    echo "ERROR: No UE stdout logs found. Pass UE numbers explicitly, for example: $0 1 2 3"
    exit 1
fi

for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    if ! [[ "$UE_NUMBER" =~ ^[0-9]+$ ]] || [ "$UE_NUMBER" -lt 1 ]; then
        echo "ERROR: UE number must be a positive integer: $UE_NUMBER"
        exit 1
    fi
done

IFS=$'\n' SORTED_UES=($(printf "%s\n" "${UE_NUMBERS[@]}" | sort -n))
unset IFS

for UE_NUMBER in "${SORTED_UES[@]}"; do
    if ! PDU_SESSIONS=$(./install_scripts/get_pdu_sessions.sh "$UE_NUMBER"); then
        echo "$PDU_SESSIONS"
        continue
    fi
    echo "UE $UE_NUMBER: $PDU_SESSIONS"
done

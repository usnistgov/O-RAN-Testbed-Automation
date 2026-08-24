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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
CU_CONFIG="$SCRIPT_DIR/configs/split_cu.conf"
CU_LOG="$SCRIPT_DIR/logs/split_cu_stdout.txt"

if [ ! -f "$CU_CONFIG" ] ||
    ! "$SCRIPT_DIR/is_running.sh" | grep -Eq '(^|[ (])cu([ )]|$)' ||
    [ ! -f "$CU_LOG" ] ||
    ! grep -qaF "TYPE <CTRL-C> TO TERMINATE" "$CU_LOG"; then
    echo false
    exit 0
fi

CU_ADDRESS=$(sed -n 's/^[[:space:]]*local_s_address[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$CU_CONFIG" | head -n 1)
CU_PORT=$(sed -n 's/^[[:space:]]*local_s_portc[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$CU_CONFIG" | head -n 1)
CU_PORT=${CU_PORT:-38472}

if [ -z "$CU_ADDRESS" ] || ! [[ "$CU_PORT" =~ ^[1-9][0-9]*$ ]] ||
    [ "${#CU_PORT}" -gt 5 ] ||
    { [ "${#CU_PORT}" -eq 5 ] && [[ "$CU_PORT" > "65535" ]]; }; then
    echo false
    exit 0
fi

if [ ! -r /proc/net/sctp/eps ]; then
    echo false
elif awk -v address="$CU_ADDRESS" -v port="$CU_PORT" \
    'NR > 1 && $6 == port { for (i = 9; i <= NF; i++) if ($i == address) found = 1 } END { exit !found }' \
    /proc/net/sctp/eps; then
    echo true
else
    echo false
fi

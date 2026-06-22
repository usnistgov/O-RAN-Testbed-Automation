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

set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

UE_NUMBER=$1
if [ -z "$UE_NUMBER" ]; then
    echo "Usage: $0 <UE_NUMBER>" >&2
    exit 1
fi
if ! [[ "$UE_NUMBER" =~ ^[0-9]+$ ]] || [ "$UE_NUMBER" -lt 1 ]; then
    echo "ERROR: UE number must be a positive integer." >&2
    exit 1
fi

LOG_FILE="logs/ue${UE_NUMBER}_stdout.txt"
if [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: Log file $LOG_FILE does not exist. Please start UE $UE_NUMBER first." >&2
    exit 1
fi

PDU_SESSIONS=$(sed -n 's/.*PDU Session Establishment successful\. IP: \([^[:space:]\r]*\).*/\1/p' "$LOG_FILE" | sort -u)
if [ -z "$PDU_SESSIONS" ]; then
    echo "ERROR: No PDU sessions found for UE $UE_NUMBER." >&2
    exit 1
fi

echo "$PDU_SESSIONS"

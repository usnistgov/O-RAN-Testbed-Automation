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

# Script directory from the called path, including symlinks
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR=$(dirname "$SCRIPT_DIR")

usage() {
    echo "Usage: $0 {--broker-file|--cells|--ues|--listen-ports|--cell NUMBER|--ue NUMBER}"
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

case "$(basename "$PARENT_DIR")" in
Next_Generation_Node_B)
    BROKER_FILE="$PARENT_DIR/zmq_broker/multi_ue_scenario.py"
    UE_NAMESPACE_SCRIPT="$PARENT_DIR/../User_Equipment/install_scripts/get_ue_namespace_ip.sh"
    ;;
User_Equipment)
    BROKER_FILE="$PARENT_DIR/../Next_Generation_Node_B/zmq_broker/multi_ue_scenario.py"
    UE_NAMESPACE_SCRIPT="$PARENT_DIR/install_scripts/get_ue_namespace_ip.sh"
    ;;
OpenAirInterface_UE)
    BROKER_FILE="$PARENT_DIR/../../Next_Generation_Node_B/zmq_broker/multi_ue_scenario.py"
    UE_NAMESPACE_SCRIPT="$PARENT_DIR/../../User_Equipment/install_scripts/get_ue_namespace_ip.sh"
    ;;
*)
    echo "ERROR: Unable to determine the ZeroMQ channel emulator directory from $PARENT_DIR." >&2
    exit 1
    ;;
esac
if [ ! -f "$BROKER_FILE" ]; then
    echo "ERROR: ZeroMQ channel emulator configuration not found. Run generate_configurations.sh first." >&2
    exit 1
fi

case "$1" in
--broker-file)
    if [ $# -ne 1 ]; then
        usage
        exit 1
    fi
    echo "$BROKER_FILE"
    ;;
--cells)
    if [ $# -ne 1 ]; then
        usage
        exit 1
    fi
    awk '$1 == "#" && $2 == "CELL_CONFIG:" { print $3 }' "$BROKER_FILE"
    ;;
--ues)
    if [ $# -ne 1 ]; then
        usage
        exit 1
    fi
    awk '$1 == "#" && $2 == "UE_CONFIG:" { print $3 }' "$BROKER_FILE"
    ;;
--listen-ports)
    if [ $# -ne 1 ]; then
        usage
        exit 1
    fi
    awk '$1 == "#" && $2 == "CELL_CONFIG:" { print $5 }
         $1 == "#" && $2 == "UE_CONFIG:" { print $4 }' "$BROKER_FILE"
    ;;
--cell)
    if [ $# -ne 2 ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
        usage
        exit 1
    fi
    CELL_CONFIG=$(awk -v cell="$2" '$1 == "#" && $2 == "CELL_CONFIG:" && $3 == cell { print $3, $4, $5; exit }' "$BROKER_FILE")
    if [ -z "$CELL_CONFIG" ]; then
        echo "ERROR: Cell $2 is not present in the generated ZeroMQ channel emulator configuration." >&2
        exit 1
    fi
    read -r CELL_NUMBER BROKER_CELL_RX_PORT BROKER_CELL_TX_PORT <<<"$CELL_CONFIG"
    echo "$CELL_NUMBER $BROKER_CELL_RX_PORT $BROKER_CELL_TX_PORT"
    ;;
--ue)
    if [ $# -ne 2 ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
        usage
        exit 1
    fi
    UE_CONFIG=$(awk -v ue="$2" '$1 == "#" && $2 == "UE_CONFIG:" && $3 == ue { print $3, $4, $5, $6; exit }' "$BROKER_FILE")
    if [ -z "$UE_CONFIG" ]; then
        echo "ERROR: UE $2 is not present in the generated ZeroMQ channel emulator configuration." >&2
        exit 1
    fi
    read -r UE_NUMBER UE_RX_PORT UE_TX_PORT UE_IP <<<"$UE_CONFIG"
    if ! [[ "$UE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "ERROR: UE $2 has an invalid ZeroMQ channel emulator IP address: $UE_IP" >&2
        exit 1
    fi
    UE_HOST_IP=$("$UE_NAMESPACE_SCRIPT" host "$UE_NUMBER")
    echo "$UE_NUMBER $UE_RX_PORT $UE_TX_PORT $UE_IP $UE_HOST_IP"
    ;;
*)
    usage
    exit 1
    ;;
esac

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

echo "# Script: $(realpath "$0") $@"

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

GNB_CONFIG="configs/gnb.yaml"
UE_CONFIG_DIR="../User_Equipment/configs"
BROKER_ONLY=false
UE_NUMBERS=()
CELL_NUMBERS=()
ERRORS=()

usage() {
    echo "Usage: $0 [--broker-only] [--ues <ue_numbers>] [--cells <cell_numbers>]"
}

while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --broker-only)
        BROKER_ONLY=true
        shift
        ;;
    --ues)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --ues requires comma-separated UE numbers."
            usage
            exit 1
        fi
        IFS=',' read -r -a UE_NUMBERS <<<"$2"
        shift 2
        ;;
    --cells)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --cells requires comma-separated cell numbers."
            usage
            exit 1
        fi
        IFS=',' read -r -a CELL_NUMBERS <<<"$2"
        shift 2
        ;;
    *)
        echo "ERROR: Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
done

add_error() {
    ERRORS+=("$1")
}

yaml_value() {
    grep -E "^[[:space:]]*$2:" "$1" | head -n 1 | sed "s/^[[:space:]]*$2:[[:space:]]*//" | xargs || true
}

conf_section_value() {
    awk -v section="$2" -v key="$3" '
        $0 == "[" section "]" { in_section = 1; next }
        /^\[/ { in_section = 0 }
        in_section && $1 == key {
            sub(/^[^=]*=[[:space:]]*/, "")
            print
            exit
        }
    ' "$1" | xargs || true
}

device_arg_value() {
    echo "$1" | tr ',' '\n' | awk -F= -v key="$2" '$1 == key { print $2; exit }' | xargs || true
}

if [ ! -x "$SCRIPT_DIR/get_zmq_broker_config.sh" ]; then
    add_error "ZeroMQ Broker configuration reader not found: $SCRIPT_DIR/get_zmq_broker_config.sh"
else
    BROKER=$("$SCRIPT_DIR/get_zmq_broker_config.sh" --broker-file)
    if [ ! -f "$BROKER" ]; then
        add_error "ZeroMQ Broker configuration not found: $BROKER"
    fi
fi

if [ "$BROKER_ONLY" != "true" ]; then
    if [ ! -f "$GNB_CONFIG" ]; then
        add_error "gNB config not found: $GNB_CONFIG"
    fi
    if [ ! -d "$UE_CONFIG_DIR" ]; then
        add_error "UE config directory not found: $UE_CONFIG_DIR"
    fi
fi

if [ ${#ERRORS[@]} -eq 0 ] && [ ${#CELL_NUMBERS[@]} -eq 0 ]; then
    mapfile -t CELL_NUMBERS < <("$SCRIPT_DIR/get_zmq_broker_config.sh" --cells)
fi
if [ ${#ERRORS[@]} -eq 0 ] && [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    mapfile -t UE_NUMBERS < <("$SCRIPT_DIR/get_zmq_broker_config.sh" --ues)
fi
if [ ${#CELL_NUMBERS[@]} -eq 0 ]; then
    add_error "No cells were found in the generated ZeroMQ Broker configuration"
fi
if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    add_error "No UEs were found in the generated ZeroMQ Broker configuration"
fi

if [ "$BROKER_ONLY" != "true" ] && [ ${#ERRORS[@]} -eq 0 ]; then
    GNB_DEVICE_ARGS=$(yaml_value "$GNB_CONFIG" "device_args")
    GNB_SRATE=$(yaml_value "$GNB_CONFIG" "srate")
    GNB_BASE_SRATE=$(device_arg_value "$GNB_DEVICE_ARGS" "base_srate")
    if [ -z "$GNB_BASE_SRATE" ]; then
        add_error "gNB device_args is missing base_srate"
    fi
    if [ -z "$GNB_SRATE" ]; then
        add_error "gNB ru_sdr.srate is missing"
    fi
fi

CELL_COUNT=0
for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
    if ! [[ "$CELL_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
        add_error "Cell number '$CELL_NUMBER' must be a positive integer"
        continue
    fi
    EXPECTED_CELL_RX_PORT=$((2000 + (CELL_NUMBER - 1) * 2))
    EXPECTED_CELL_TX_PORT=$((EXPECTED_CELL_RX_PORT + 1))
    if [ "$EXPECTED_CELL_TX_PORT" -gt 65535 ]; then
        add_error "Cell $CELL_NUMBER has a ZeroMQ port above 65535"
        continue
    fi

    BROKER_CELL_CONFIG=$("$SCRIPT_DIR/get_zmq_broker_config.sh" --cell "$CELL_NUMBER" 2>/dev/null || true)
    if [ -z "$BROKER_CELL_CONFIG" ]; then
        add_error "Cell $CELL_NUMBER is missing from the generated ZeroMQ Broker configuration"
        continue
    fi
    read -r BROKER_CELL_NUMBER BROKER_CELL_RX_PORT BROKER_CELL_TX_PORT <<<"$BROKER_CELL_CONFIG"

    if [ "$BROKER_CELL_NUMBER" != "$CELL_NUMBER" ]; then
        add_error "Cell $CELL_NUMBER: broker record has cell number $BROKER_CELL_NUMBER"
    fi
    if [ "$BROKER_CELL_RX_PORT" != "$EXPECTED_CELL_RX_PORT" ]; then
        add_error "Cell $CELL_NUMBER: broker rx_port must be $EXPECTED_CELL_RX_PORT (got $BROKER_CELL_RX_PORT)"
    fi
    if [ "$BROKER_CELL_TX_PORT" != "$EXPECTED_CELL_TX_PORT" ]; then
        add_error "Cell $CELL_NUMBER: broker tx_port must be $EXPECTED_CELL_TX_PORT (got $BROKER_CELL_TX_PORT)"
    fi
    if [ "$BROKER_ONLY" != "true" ]; then
        if [ "$(device_arg_value "$GNB_DEVICE_ARGS" "tx_port$CELL_COUNT")" != "tcp://127.0.0.1:$EXPECTED_CELL_RX_PORT" ]; then
            add_error "Cell $CELL_NUMBER: gNB tx_port$CELL_COUNT must be tcp://127.0.0.1:$EXPECTED_CELL_RX_PORT for broker mode"
        fi
        if [ "$(device_arg_value "$GNB_DEVICE_ARGS" "rx_port$CELL_COUNT")" != "tcp://127.0.0.1:$EXPECTED_CELL_TX_PORT" ]; then
            add_error "Cell $CELL_NUMBER: gNB rx_port$CELL_COUNT must be tcp://127.0.0.1:$EXPECTED_CELL_TX_PORT for broker mode"
        fi
    fi
    CELL_COUNT=$((CELL_COUNT + 1))
done

for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    if ! [[ "$UE_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
        add_error "UE number '$UE_NUMBER' must be a positive integer"
        continue
    fi
    EXPECTED_RX_PORT=$((2000 + UE_NUMBER * 100))
    EXPECTED_TX_PORT=$((EXPECTED_RX_PORT + 1))
    if [ "$EXPECTED_TX_PORT" -gt 65535 ]; then
        add_error "UE $UE_NUMBER has a ZeroMQ port above 65535"
        continue
    fi

    BROKER_UE_CONFIG=$("$SCRIPT_DIR/get_zmq_broker_config.sh" --ue "$UE_NUMBER" 2>/dev/null || true)
    if [ -z "$BROKER_UE_CONFIG" ]; then
        add_error "UE $UE_NUMBER is missing from the generated ZeroMQ Broker configuration"
        continue
    fi
    read -r BROKER_UE_NUMBER BROKER_UE_RX_PORT BROKER_UE_TX_PORT BROKER_UE_IP BROKER_HOST_IP <<<"$BROKER_UE_CONFIG"
    EXPECTED_HOST_IP=$("$PARENT_DIR/../User_Equipment/install_scripts/get_ue_namespace_ip.sh" host "$UE_NUMBER")
    EXPECTED_UE_IP=$("$PARENT_DIR/../User_Equipment/install_scripts/get_ue_namespace_ip.sh" ue "$UE_NUMBER")

    if [ "$BROKER_UE_NUMBER" != "$UE_NUMBER" ]; then
        add_error "UE $UE_NUMBER: broker record has UE number $BROKER_UE_NUMBER"
    fi
    if [ "$BROKER_UE_RX_PORT" != "$EXPECTED_RX_PORT" ]; then
        add_error "UE $UE_NUMBER: broker rx_port must be $EXPECTED_RX_PORT (got $BROKER_UE_RX_PORT)"
    fi
    if [ "$BROKER_UE_TX_PORT" != "$EXPECTED_TX_PORT" ]; then
        add_error "UE $UE_NUMBER: broker tx_port must be $EXPECTED_TX_PORT (got $BROKER_UE_TX_PORT)"
    fi
    if [ "$BROKER_UE_IP" != "$EXPECTED_UE_IP" ]; then
        add_error "UE $UE_NUMBER: broker ue_ip must be $EXPECTED_UE_IP (got $BROKER_UE_IP)"
    fi
    if [ "$BROKER_HOST_IP" != "$EXPECTED_HOST_IP" ]; then
        add_error "UE $UE_NUMBER: broker host IP must be $EXPECTED_HOST_IP (got $BROKER_HOST_IP)"
    fi
    if [ "$BROKER_ONLY" != "true" ]; then
        UE_CONFIG="$UE_CONFIG_DIR/ue${UE_NUMBER}.conf"
        if [ ! -f "$UE_CONFIG" ]; then
            add_error "UE $UE_NUMBER: missing $UE_CONFIG"
            continue
        fi
        UE_DEVICE_ARGS=$(conf_section_value "$UE_CONFIG" "rf" "device_args")
        UE_SRATE=$(conf_section_value "$UE_CONFIG" "rf" "srate")
        if [ "$(device_arg_value "$UE_DEVICE_ARGS" "tx_port")" != "tcp://*:$EXPECTED_TX_PORT" ]; then
            add_error "UE $UE_NUMBER: tx_port must be tcp://*:$EXPECTED_TX_PORT (got $(device_arg_value "$UE_DEVICE_ARGS" "tx_port"))"
        fi
        if [ "$(device_arg_value "$UE_DEVICE_ARGS" "rx_port")" != "tcp://$EXPECTED_HOST_IP:$EXPECTED_RX_PORT" ]; then
            add_error "UE $UE_NUMBER: rx_port must be tcp://$EXPECTED_HOST_IP:$EXPECTED_RX_PORT (got $(device_arg_value "$UE_DEVICE_ARGS" "rx_port"))"
        fi
        if [ "$(device_arg_value "$UE_DEVICE_ARGS" "base_srate")" != "$GNB_BASE_SRATE" ]; then
            add_error "UE $UE_NUMBER: base_srate does not match gNB base_srate (got $(device_arg_value "$UE_DEVICE_ARGS" "base_srate"))"
        fi
        if [ "$UE_SRATE" != "${GNB_SRATE}e6" ]; then
            add_error "UE $UE_NUMBER: srate $UE_SRATE does not match gNB srate ${GNB_SRATE}e6 (got ${GNB_SRATE}e6)"
        fi
    fi
done

if [ ${#ERRORS[@]} -gt 0 ]; then
    for ERROR in "${ERRORS[@]}"; do
        echo "ERROR: $ERROR"
    done
    exit 1
fi

echo "Successfully validated ZeroMQ broker for UEs: [${UE_NUMBERS[*]}], Cells: [${CELL_NUMBERS[*]}]."

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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
GNB_CONFIG="configs/gnb.yaml"
BROKER="zmq_broker/multi_ue_scenario.py"
UE_CONFIG_DIR="../User_Equipment/configs"
UE_NUMBERS=()
CELL_COUNT=""
ERRORS=()

while [ $# -gt 0 ]; do
    case "$1" in
    --gnb-config)
        GNB_CONFIG="$2"
        shift 2
        ;;
    --broker)
        BROKER="$2"
        shift 2
        ;;
    --ue-config-dir)
        UE_CONFIG_DIR="$2"
        shift 2
        ;;
    --ue)
        UE_NUMBERS+=("$2")
        shift 2
        ;;
    --cells | --cell-count)
        CELL_COUNT="$2"
        shift 2
        ;;
    *)
        echo "Usage: $0 [--gnb-config FILE] [--broker FILE] [--ue-config-dir DIR] [--ue NUMBER ...]"
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

broker_field() {
    grep -E "^# UE_CONFIG: $2 " "$1" | awk -v field="$3" '{ print $field; exit }' || true
}

broker_cell_field() {
    grep -E "^# CELL_CONFIG: $2 " "$1" | awk -v field="$3" '{ print $field; exit }' || true
}

if [ ! -f "$GNB_CONFIG" ]; then
    add_error "gNB config not found: $GNB_CONFIG"
fi
if [ ! -f "$BROKER" ]; then
    add_error "ZMQ broker not found: $BROKER"
fi
if [ ! -d "$UE_CONFIG_DIR" ]; then
    add_error "UE config directory not found: $UE_CONFIG_DIR"
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
    GNB_DEVICE_ARGS=$(yaml_value "$GNB_CONFIG" "device_args")
    GNB_SRATE=$(yaml_value "$GNB_CONFIG" "srate")
    GNB_BASE_SRATE=$(device_arg_value "$GNB_DEVICE_ARGS" "base_srate")
    PDU_TIMEOUT=$(yaml_value "$GNB_CONFIG" "request_pdu_session_timeout")

    if [ -z "$CELL_COUNT" ]; then
        CELL_COUNT=$(grep -Ec '^# CELL_CONFIG: ' "$BROKER")
        if [ "$CELL_COUNT" -eq 0 ]; then
            CELL_COUNT=1
        fi
    fi
    if ! [[ "$CELL_COUNT" =~ ^[0-9]+$ ]] || [ "$CELL_COUNT" -lt 1 ]; then
        add_error "Cell count must be a positive integer"
    else
        for CELL_NUMBER in $(seq 1 "$CELL_COUNT"); do
            CELL_INDEX=$((CELL_NUMBER - 1))
            EXPECTED_CELL_RX_PORT=$((2000 + CELL_INDEX * 2))
            EXPECTED_CELL_TX_PORT=$((2001 + CELL_INDEX * 2))

            if [ "$(broker_cell_field "$BROKER" "$CELL_NUMBER" 4)" != "$EXPECTED_CELL_RX_PORT" ]; then
                add_error "Cell $CELL_NUMBER: broker rx_port must be $EXPECTED_CELL_RX_PORT"
            fi
            if [ "$(broker_cell_field "$BROKER" "$CELL_NUMBER" 5)" != "$EXPECTED_CELL_TX_PORT" ]; then
                add_error "Cell $CELL_NUMBER: broker tx_port must be $EXPECTED_CELL_TX_PORT"
            fi
            if [ "$(device_arg_value "$GNB_DEVICE_ARGS" "tx_port$CELL_INDEX")" != "tcp://127.0.0.1:$EXPECTED_CELL_RX_PORT" ]; then
                add_error "Cell $CELL_NUMBER: gNB tx_port$CELL_INDEX must be tcp://127.0.0.1:$EXPECTED_CELL_RX_PORT for broker mode"
            fi
            if [ "$(device_arg_value "$GNB_DEVICE_ARGS" "rx_port$CELL_INDEX")" != "tcp://127.0.0.1:$EXPECTED_CELL_TX_PORT" ]; then
                add_error "Cell $CELL_NUMBER: gNB rx_port$CELL_INDEX must be tcp://127.0.0.1:$EXPECTED_CELL_TX_PORT for broker mode"
            fi
        done
    fi
    if [ -z "$GNB_BASE_SRATE" ]; then
        add_error "gNB device_args is missing base_srate"
    fi
    if [ -z "$GNB_SRATE" ]; then
        add_error "gNB ru_sdr.srate is missing"
    fi
fi

if [ ${#UE_NUMBERS[@]} -eq 0 ] && [ -d "$UE_CONFIG_DIR" ]; then
    for UE_CONFIG in "$UE_CONFIG_DIR"/ue*.conf; do
        [ -e "$UE_CONFIG" ] || continue
        UE_NAME=$(basename "$UE_CONFIG")
        UE_NUMBER="${UE_NAME#ue}"
        UE_NUMBER="${UE_NUMBER%.conf}"
        if [[ "$UE_NUMBER" =~ ^[0-9]+$ ]]; then
            UE_NUMBERS+=("$UE_NUMBER")
        fi
    done
fi

if [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    add_error "No UE configs were found to validate"
fi

for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    UE_CONFIG="$UE_CONFIG_DIR/ue${UE_NUMBER}.conf"
    if [ ! -f "$UE_CONFIG" ]; then
        add_error "UE $UE_NUMBER: missing $UE_CONFIG"
        continue
    fi

    UE_DEVICE_ARGS=$(conf_section_value "$UE_CONFIG" "rf" "device_args")
    UE_SRATE=$(conf_section_value "$UE_CONFIG" "rf" "srate")
    EXPECTED_HOST_IP=$(python3 "$SCRIPT_DIR/fetch_nth_ip.py" "10.201.0.0/16" "$((UE_NUMBER * 4))")
    EXPECTED_UE_IP=$(python3 "$SCRIPT_DIR/fetch_nth_ip.py" "10.201.0.0/16" "$((UE_NUMBER * 4 + 1))")
    EXPECTED_RX_PORT=$((2000 + UE_NUMBER * 100))
    EXPECTED_TX_PORT=$((2001 + UE_NUMBER * 100))

    if [ "$(broker_field "$BROKER" "$UE_NUMBER" 4)" != "$EXPECTED_RX_PORT" ]; then
        add_error "UE $UE_NUMBER: broker rx_port must be $EXPECTED_RX_PORT"
    fi
    if [ "$(broker_field "$BROKER" "$UE_NUMBER" 5)" != "$EXPECTED_TX_PORT" ]; then
        add_error "UE $UE_NUMBER: broker tx_port must be $EXPECTED_TX_PORT"
    fi
    if [ "$(broker_field "$BROKER" "$UE_NUMBER" 6)" != "$EXPECTED_UE_IP" ]; then
        add_error "UE $UE_NUMBER: broker ue_ip must be $EXPECTED_UE_IP"
    fi
    if [ "$(device_arg_value "$UE_DEVICE_ARGS" "tx_port")" != "tcp://*:$EXPECTED_TX_PORT" ]; then
        add_error "UE $UE_NUMBER: tx_port must be tcp://*:$EXPECTED_TX_PORT"
    fi
    if [ "$(device_arg_value "$UE_DEVICE_ARGS" "rx_port")" != "tcp://$EXPECTED_HOST_IP:$EXPECTED_RX_PORT" ]; then
        add_error "UE $UE_NUMBER: rx_port must be tcp://$EXPECTED_HOST_IP:$EXPECTED_RX_PORT"
    fi
    if [ "$(device_arg_value "$UE_DEVICE_ARGS" "base_srate")" != "$GNB_BASE_SRATE" ]; then
        add_error "UE $UE_NUMBER: base_srate does not match gNB base_srate"
    fi
    if [ "$UE_SRATE" != "${GNB_SRATE}e6" ]; then
        add_error "UE $UE_NUMBER: srate $UE_SRATE does not match gNB srate ${GNB_SRATE}e6"
    fi
done

for BROKER_UE in $(grep -E '^# UE_CONFIG: ' "$BROKER" | awk '{ print $3 }'); do
    FOUND=false
    for UE_NUMBER in "${UE_NUMBERS[@]}"; do
        if [ "$BROKER_UE" = "$UE_NUMBER" ]; then
            FOUND=true
        fi
    done
    if [ "$FOUND" = false ]; then
        add_error "Generated broker contains UE $BROKER_UE without matching UE config"
    fi
done

if [ -n "$CELL_COUNT" ]; then
    for BROKER_CELL in $(grep -E '^# CELL_CONFIG: ' "$BROKER" | awk '{ print $3 }'); do
        if [ "$BROKER_CELL" -lt 1 ] || [ "$BROKER_CELL" -gt "$CELL_COUNT" ]; then
            add_error "Generated broker contains cell $BROKER_CELL outside configured cell count $CELL_COUNT"
        fi
    done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
    for ERROR in "${ERRORS[@]}"; do
        echo "ERROR: $ERROR"
    done
    exit 1
fi

IFS=$'\n' SORTED_UES=($(printf "%s\n" "${UE_NUMBERS[@]}" | sort -n))
unset IFS
echo "Successfully validated ZeroMQ broker configuration for $CELL_COUNT cell(s), gNB, and UE(s): ${SORTED_UES[*]}"

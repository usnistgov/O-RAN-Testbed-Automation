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
GNB_CONFIG="configs/gnb.yaml"
BROKER="zmq_broker/multi_ue_scenario.py"
UE_CONFIG_DIR="../User_Equipment/configs"
UE_NUMBERS=()
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

    [ "$(device_arg_value "$GNB_DEVICE_ARGS" "tx_port")" = "tcp://127.0.0.1:2000" ] || add_error "gNB tx_port must be tcp://127.0.0.1:2000 for broker mode"
    [ "$(device_arg_value "$GNB_DEVICE_ARGS" "rx_port")" = "tcp://127.0.0.1:2001" ] || add_error "gNB rx_port must be tcp://127.0.0.1:2001 for broker mode"
    [ -n "$GNB_BASE_SRATE" ] || add_error "gNB device_args is missing base_srate"
    [ -n "$GNB_SRATE" ] || add_error "gNB ru_sdr.srate is missing"
    [ -n "$PDU_TIMEOUT" ] && [ "$PDU_TIMEOUT" -ge 30 ] || add_error "gNB cu_cp.request_pdu_session_timeout should be at least 30 seconds for broker mode"
    grep -q "^SLOW_DOWN_RATIO = 1$" "$BROKER" || add_error "ZMQ broker SLOW_DOWN_RATIO must be 1 for real-time gNB/UE operation"
    grep -q "ZMQ broker sample_rate=" "$BROKER" || add_error "ZMQ broker is missing startup endpoint logging; regenerate broker config"
    grep -q "ZMQ broker gNB UL sink tcp://127.0.0.1:2001" "$BROKER" || add_error "ZMQ broker is missing gNB UL endpoint logging; regenerate broker config"

    [ "$(yaml_value "$GNB_CONFIG" "resource_set_size")" = "7" ] || add_error "gNB cell_cfg.pucch.resource_set_size must be 7"
    [ "$(yaml_value "$GNB_CONFIG" "nof_cell_res_set_configs")" = "1" ] || add_error "gNB cell_cfg.pucch.nof_cell_res_set_configs must be 1"
    [ "$(yaml_value "$GNB_CONFIG" "f1_nof_cyclic_shifts")" = "1" ] || add_error "gNB cell_cfg.pucch.f1_nof_cyclic_shifts must be 1"
    [ "$(yaml_value "$GNB_CONFIG" "f1_enable_occ")" = "true" ] || add_error "gNB cell_cfg.pucch.f1_enable_occ must be true"
    [ "$(yaml_value "$GNB_CONFIG" "nof_cell_sr_res")" = "7" ] || add_error "gNB cell_cfg.pucch.nof_cell_sr_res must be 7"
    [ "$(yaml_value "$GNB_CONFIG" "nof_cell_csi_res")" = "7" ] || add_error "gNB cell_cfg.pucch.nof_cell_csi_res must be 7"
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

    [ "$(broker_field "$BROKER" "$UE_NUMBER" 4)" = "$EXPECTED_RX_PORT" ] || add_error "UE $UE_NUMBER: broker rx_port must be $EXPECTED_RX_PORT"
    [ "$(broker_field "$BROKER" "$UE_NUMBER" 5)" = "$EXPECTED_TX_PORT" ] || add_error "UE $UE_NUMBER: broker tx_port must be $EXPECTED_TX_PORT"
    [ "$(broker_field "$BROKER" "$UE_NUMBER" 6)" = "$EXPECTED_UE_IP" ] || add_error "UE $UE_NUMBER: broker ue_ip must be $EXPECTED_UE_IP"
    grep -q "ZMQ broker UE{ue_number} DL sink" "$BROKER" ||
        add_error "ZMQ broker is missing UE endpoint logging; regenerate broker config"
    [ "$(device_arg_value "$UE_DEVICE_ARGS" "tx_port")" = "tcp://*:$EXPECTED_TX_PORT" ] || add_error "UE $UE_NUMBER: tx_port must be tcp://*:$EXPECTED_TX_PORT"
    [ "$(device_arg_value "$UE_DEVICE_ARGS" "rx_port")" = "tcp://$EXPECTED_HOST_IP:$EXPECTED_RX_PORT" ] || add_error "UE $UE_NUMBER: rx_port must be tcp://$EXPECTED_HOST_IP:$EXPECTED_RX_PORT"
    [ "$(device_arg_value "$UE_DEVICE_ARGS" "base_srate")" = "$GNB_BASE_SRATE" ] || add_error "UE $UE_NUMBER: base_srate does not match gNB base_srate"
    [ "$UE_SRATE" = "${GNB_SRATE}e6" ] || add_error "UE $UE_NUMBER: srate $UE_SRATE does not match gNB srate ${GNB_SRATE}e6"
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

if [ ${#ERRORS[@]} -gt 0 ]; then
    for ERROR in "${ERRORS[@]}"; do
        echo "ERROR: $ERROR"
    done
    exit 1
fi

IFS=$'\n' SORTED_UES=($(printf "%s\n" "${UE_NUMBERS[@]}" | sort -n))
unset IFS
echo "ZMQ broker configuration is aligned for UE(s): ${SORTED_UES[*]}"

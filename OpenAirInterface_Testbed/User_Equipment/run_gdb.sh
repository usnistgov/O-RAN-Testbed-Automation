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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Default values
UE_NUMBER=1
RFSIM_SERVER=0
DISABLE_NRSCOPE_IF_INSTALLED=false
USE_ZMQ_BROKER=false
SHOW_ZMQ_BROKER_UI=true
ZMQ_THREAD_POOL="-1,-1"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
    [0-9]*)
        UE_NUMBER="$1"
        shift
        ;;
    --rfsim-server)
        RFSIM_SERVER=1
        shift
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

if ! [[ "$UE_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: UE number must be a positive integer."
    exit 1
fi
if [ "$SHOW_ZMQ_BROKER_UI" != "true" ] && [ "$SHOW_ZMQ_BROKER_UI" != "false" ]; then
    echo "ERROR: SHOW_ZMQ_BROKER_UI must be true or false."
    exit 1
fi

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    # Optionally, validate the ZeroMQ broker before starting the UE
    # "$SCRIPT_DIR/install_scripts/validate_zmq_broker_config.sh" --broker-only --ue "$UE_NUMBER"

    BROKER_UE_NUMBER=$("$SCRIPT_DIR/install_scripts/get_zmq_broker_config.sh" --ue "$UE_NUMBER" | awk '{print $1}')
    ZMQ_RX_PORT=$("$SCRIPT_DIR/install_scripts/get_zmq_broker_config.sh" --ue "$UE_NUMBER" | awk '{print $2}')
    ZMQ_TX_PORT=$("$SCRIPT_DIR/install_scripts/get_zmq_broker_config.sh" --ue "$UE_NUMBER" | awk '{print $3}')
    UE_HOST_IP=$("$SCRIPT_DIR/install_scripts/get_ue_namespace_ip.sh" host "$UE_NUMBER")
    if [ ! -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/liboai_zmqdevif.so" ]; then
        echo "ERROR: ZeroMQ device library not found. Rerun full_install.sh after setting RADIO_TYPE=\"ZMQ\"."
        exit 1
    fi
    "$SCRIPT_DIR/install_scripts/run_zmq_broker.sh" --show-ui "$SHOW_ZMQ_BROKER_UI"
fi

# Function to handle graceful shutdown
graceful_shutdown() {
    trap - SIGINT SIGTERM SIGQUIT
    echo "Shutting down UE $UE_NUMBER gracefully..."
    "$SCRIPT_DIR/stop.sh" "$UE_NUMBER"
    exit
}
trap graceful_shutdown SIGINT SIGTERM SIGQUIT

# Function to update or add configuration properties in .conf files, considering sections and uncommenting if needed
update_conf() {
    echo "update_conf($1, $2, $3)"
    local FILE_PATH="$1"
    local PROPERTY="$2"
    local VALUE="$3"

    # Check if the property exists in the file, and update or append it accordingly
    if grep -q "^\s*$PROPERTY\s*=" "$FILE_PATH"; then
        # Update existing property's value
        sed -i "s|^\(\s*$PROPERTY\s*=\).*|\1 $VALUE;|" "$FILE_PATH"
    else
        # Append new property-value pair if it does not exist
        echo "$PROPERTY = $VALUE;" >>"$FILE_PATH"
    fi
}

UE_CONF_PATH="configs/ue$UE_NUMBER.conf"

if [ ! -f "$UE_CONF_PATH" ]; then
    echo "Configuration file for UE $UE_NUMBER not found, creating..."
    ./generate_configurations.sh "$UE_NUMBER"
    if [ ! -f "$UE_CONF_PATH" ]; then
        echo "ERROR: Configuration file for UE $UE_NUMBER not found."
        exit 1
    fi
fi

HOSTNAME_IP=$(hostname -I | awk '{print $1}')

if ./is_running.sh | grep -Eq "(^|[ (])ue${UE_NUMBER}([ )]|$)"; then
    echo "Already running ue$UE_NUMBER."
else
    if [ ! -f "$UE_CONF_PATH" ]; then
        echo "Configuration was not found for Duranta UE $UE_NUMBER. Please run ./generate_configurations.sh first."
        exit 1
    fi
    mkdir -p logs
    if [ -f "logs/ue${UE_NUMBER}_stdout.txt" ]; then
        sudo chown "${SUDO_USER:-$USER}" logs/ue${UE_NUMBER}_stdout.txt
    fi
    >logs/ue${UE_NUMBER}_stdout.txt

    if ! command -v gdb &>/dev/null; then
        echo "Installing GNU Debugger..."
        sudo apt-get update
        sudo env $APTVARS apt-get install -y gdb
    fi

    echo "Starting nr-uesoftmodem (ue$UE_NUMBER)..."

    # Give the UE its own network namespace and configure it to access the host network
    sudo ./install_scripts/setup_ue_namespace.sh "$UE_NUMBER"

    if [ "$USE_ZMQ_BROKER" = "true" ]; then
        RFSIM_SERVER_ARG=""
    else
        if [ "$RFSIM_SERVER" -ne 0 ]; then
            echo "RF simulator server mode enabled."
            RFSIM_SERVER_ARG="--rfsimulator.[0].serveraddr server"
            SERVER_IP=$(sudo ip netns exec ue$UE_NUMBER ip addr show dev v-ue$UE_NUMBER | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            mkdir -p configs
            echo "$SERVER_IP" >configs/get_rfsim_server_address.txt
        else
            SERVER_IP=$(cat configs/get_rfsim_server_address.txt)
            if [ -z "$SERVER_IP" ]; then
                echo "ERROR: Could not find RF simulator server address."
                exit 1
            fi
            RFSIM_SERVER_ARG="--rfsimulator.[0].serveraddr $SERVER_IP"
        fi
    fi

    ADDITIONAL_FLAGS="-E"
    if [ "$DISABLE_NRSCOPE_IF_INSTALLED" = false ] && [ -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/libimscope.so" ]; then
        echo "Enabling ImScope..."
        ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --imscope -d --log_config.global_log_options utc_time"
    fi

    cd "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build"

    RADIO_TYPE=$(cat "$SCRIPT_DIR/configs/radio_type.txt" 2>/dev/null || echo "RFSIM")
    if [ "$USE_ZMQ_BROKER" = "true" ]; then
        RADIO_ARGS="--device.name oai_zmqdevif --zmq.[0].tx_channels tcp://0.0.0.0:$ZMQ_TX_PORT --zmq.[0].rx_channels tcp://$UE_HOST_IP:$ZMQ_RX_PORT --thread-pool $ZMQ_THREAD_POOL"
    elif [ "$RADIO_TYPE" = "ZMQ" ]; then
        ZMQ_TX_PORT=$((4555 + UE_NUMBER * 2))
        ZMQ_RX_PORT=$((4554 + UE_NUMBER * 2))
        UE_HOST_IP=$("$SCRIPT_DIR/install_scripts/get_ue_namespace_ip.sh" host "$UE_NUMBER")
        RADIO_ARGS="--device.name oai_zmqdevif --zmq.[0].tx_channels tcp://0.0.0.0:$ZMQ_TX_PORT --zmq.[0].rx_channels tcp://$UE_HOST_IP:$ZMQ_RX_PORT"
    elif [ "$RADIO_TYPE" = "USRP" ]; then
        RADIO_ARGS=""
    else
        RADIO_ARGS="--rfsim $RFSIM_SERVER_ARG --rfsimulator.[0].options chanmod"
    fi

    # Radio configuration presets (band 3 and band 78)
    BANDWIDTH_RBS=106
    NUMEROLOGY=0
    BAND=3
    DL_CARRIER_FREQUENCY_HZ=1842500000
    UL_CARRIER_OFFSET_HZ=-95000000
    SSB_START_SUBCARRIER=486
    # BANDWIDTH_RBS=51
    # NUMEROLOGY=1
    # BAND=78
    # DL_CARRIER_FREQUENCY_HZ=3489420000
    # UL_CARRIER_OFFSET_HZ=0
    # SSB_START_SUBCARRIER=0

    # sudo ip netns exec ue$UE_NUMBER sudo gdb --args ./nr-uesoftmodem -O "../../../../configs/ue$UE_NUMBER.conf" $RADIO_ARGS -r $BANDWIDTH_RBS --numerology $NUMEROLOGY --band $BAND -C $DL_CARRIER_FREQUENCY_HZ --CO $UL_CARRIER_OFFSET_HZ --ssb $SSB_START_SUBCARRIER
    sudo script -q -f -c "ip netns exec ue$UE_NUMBER sudo gdb --args ./nr-uesoftmodem -O \"../../../../configs/ue$UE_NUMBER.conf\" $RADIO_ARGS -r $BANDWIDTH_RBS --numerology $NUMEROLOGY --band $BAND -C $DL_CARRIER_FREQUENCY_HZ --CO $UL_CARRIER_OFFSET_HZ --ssb $SSB_START_SUBCARRIER $ADDITIONAL_FLAGS" "$SCRIPT_DIR/logs/ue${UE_NUMBER}_stdout.txt"
fi

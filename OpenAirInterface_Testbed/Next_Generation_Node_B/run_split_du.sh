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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Parse arguments
RFSIM_SERVER=1
USE_ZMQ_BROKER=false
ZMQ_THREAD_POOL="-1,-1"
ENABLE_NRSCOPE=false
USE_GDB=false
while [[ $# -gt 0 ]]; do
    case "$1" in
    [0-9]*)
        DU_NUMBER="$1"
        shift
        ;;
    --no-rfsim-server)
        RFSIM_SERVER=0
        shift
        ;;
    --nrscope)
        ENABLE_NRSCOPE=true
        shift
        ;;
    --gdb)
        USE_GDB=true
        shift
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done
if [ -z "$DU_NUMBER" ]; then
    echo "ERROR: A DU number must be provided as an argument."
    echo "    For example, $0 1 [--no-rfsim-server] [--nrscope] [--gdb]"
    exit 1
fi
if ! [[ "$DU_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: DU number must bbe a positive integer"
    exit 1
fi

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    # Optionally, validate the ZeroMQ broker before starting the DU
    # "$SCRIPT_DIR/install_scripts/validate_zmq_broker_config.sh" --broker-only --cell "$DU_NUMBER"

    BROKER_CELL_NUMBER=$("$SCRIPT_DIR/install_scripts/get_zmq_broker_config.sh" --cell "$DU_NUMBER" | awk '{print $1}')
    ZMQ_TX_PORT=$("$SCRIPT_DIR/install_scripts/get_zmq_broker_config.sh" --cell "$DU_NUMBER" | awk '{print $2}')
    ZMQ_RX_PORT=$("$SCRIPT_DIR/install_scripts/get_zmq_broker_config.sh" --cell "$DU_NUMBER" | awk '{print $3}')
    if [ ! -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/liboai_zmqdevif.so" ]; then
        echo "ERROR: ZeroMQ device library not found. Rerun full_install.sh after setting RADIO_TYPE=\"ZMQ\"."
        exit 1
    fi
fi

# Only DU 1 can be the RF simulator server
if [ "$DU_NUMBER" -ne 1 ]; then
    RFSIM_SERVER=0
fi

ADDITIONAL_FLAGS="-E"
# if [ -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/libtelnetsrv.so" ]; then
#     echo "Found telnet server library. Enabling telnet server..."
#     TELNET_ADDRESS=127.0.0.1
#     TELNET_PORT=9099
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.shrmod ci,o1"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenaddr $TELNET_ADDRESS"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenport $TELNET_PORT"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenstdin 1"
# fi

IMSCOPE=false
if [ "$ENABLE_NRSCOPE" = "true" ]; then
    if [ ! -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/libimscope.so" ]; then
        echo "ERROR: ImScope library not found. Rerun full_install.sh after setting NRSCOPE_GUI=true."
        exit 1
    fi
    echo "Enabling ImScope..."
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --imscope -d --log_config.global_log_options utc_time"
    IMSCOPE=true
fi

if [ "$USE_GDB" = "true" ] && ! command -v gdb >/dev/null 2>&1; then
    echo "Installing GNU Debugger..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y gdb
fi

cd "$SCRIPT_DIR"

DU_CONFIG="$SCRIPT_DIR/configs/split_du$DU_NUMBER.conf"
if [ ! -f "$DU_CONFIG" ]; then
    echo "Generating configuration for DU $DU_NUMBER..."
    ./install_scripts/generate_du_configuration.sh "$DU_NUMBER"
fi

mkdir -p logs
if [ -f "logs/split_du${DU_NUMBER}_stdout.txt" ]; then
    sudo chown "${SUDO_USER:-$USER}" logs/split_du${DU_NUMBER}_stdout.txt
fi
>logs/split_du${DU_NUMBER}_stdout.txt

# Give the DU its own network namespace and configure it to access the host network
sudo ./install_scripts/setup_du_namespace.sh "$DU_NUMBER"

if [ "$USE_ZMQ_BROKER" = "true" ]; then
    if ! "$SCRIPT_DIR/is_cu_ready.sh" | grep -qx true; then
        echo "CU is not ready. Starting CU in background..."
        "$SCRIPT_DIR/run_background_split_cu.sh"
    fi
    RFSIM_SERVER_ARG=""
else
    HOSTNAME_IP=$(hostname -I | awk '{print $1}')
    if [ "$RFSIM_SERVER" -eq 0 ]; then
        SERVER_IP=$(cat configs/get_rfsim_server_address.txt)
        if [ -z "$SERVER_IP" ]; then
            echo "ERROR: Could not find RF simulator server address."
            exit 1
        fi
        RFSIM_SERVER_ARG="--rfsimulator.[0].serveraddr $SERVER_IP"
    else
        echo "RF simulator server mode enabled."
        RFSIM_SERVER_ARG="--rfsimulator.[0].serveraddr server"

        mkdir -p configs
        echo "$HOSTNAME_IP" >configs/get_rfsim_server_address.txt
    fi
fi

cd "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build"

# Code from (https://github.com/duranta-project/openairinterface5g/blob/develop/doc/handover-tutorial.md#run-the-setup):
# sudo ./nr-softmodem -O "$DU_CONFIG" $RADIO_ARGS --gNBs.[0].min_rxtxtime 6 $ADDITIONAL_FLAGS

RADIO_TYPE=$(cat "$SCRIPT_DIR/configs/radio_type.txt" 2>/dev/null || echo "RFSIM")
if [ "$USE_ZMQ_BROKER" = "true" ]; then
    RADIO_ARGS="--device.name oai_zmqdevif --zmq.[0].tx_channels tcp://0.0.0.0:$ZMQ_TX_PORT --zmq.[0].rx_channels tcp://127.0.0.1:$ZMQ_RX_PORT --thread-pool $ZMQ_THREAD_POOL"
elif [ "$RADIO_TYPE" = "ZMQ" ]; then
    ZMQ_TX_PORT=$((4554 + DU_NUMBER * 2))
    ZMQ_RX_PORT=$((4555 + DU_NUMBER * 2))
    UE_NUMBER=$DU_NUMBER
    UE_NS_IP=$("$SCRIPT_DIR/install_scripts/get_ue_namespace_ip.sh" ue "$UE_NUMBER")
    RADIO_ARGS="--device.name oai_zmqdevif --zmq.[0].tx_channels tcp://0.0.0.0:$ZMQ_TX_PORT --zmq.[0].rx_channels tcp://$UE_NS_IP:$ZMQ_RX_PORT"
elif [ "$RADIO_TYPE" = "USRP" ]; then
    RADIO_ARGS=""
else
    RADIO_ARGS="--rfsim $RFSIM_SERVER_ARG --rfsimulator.[0].options chanmod"
fi

SOFTMODEM_COMMAND="./nr-softmodem -O \"$DU_CONFIG\" $RADIO_ARGS --gNBs.[0].min_rxtxtime 6 $ADDITIONAL_FLAGS"
if [ "$USE_GDB" = "true" ]; then
    SOFTMODEM_COMMAND="gdb --args $SOFTMODEM_COMMAND"
fi

if [ "$IMSCOPE" = "true" ]; then
    script -q -f -c "$SOFTMODEM_COMMAND" "$SCRIPT_DIR/logs/split_du${DU_NUMBER}_stdout.txt"
else
    sudo script -q -f -c "$SOFTMODEM_COMMAND" "$SCRIPT_DIR/logs/split_du${DU_NUMBER}_stdout.txt"
fi

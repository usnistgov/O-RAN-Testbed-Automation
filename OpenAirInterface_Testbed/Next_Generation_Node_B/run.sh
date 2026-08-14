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

USE_IMSCOPE=false
USE_ZMQ_CHANNEL_EMULATOR=false
SHOW_ZMQ_CHANNEL_EMULATOR_UI=true

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")

ENV_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
    --imscope)
        USE_IMSCOPE=true
        shift
        ;;
    *)
        ENV_ARGS+=("$1")
        shift
        ;;
    esac
done
set -- "${ENV_ARGS[@]}"

if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    if [ ! -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/liboai_zmqdevif.so" ]; then
        echo "ERROR: ZeroMQ device library not found. Rerun full_install.sh after setting RADIO_TYPE=\"ZMQ\"."
        exit 1
    fi
    "$SCRIPT_DIR/install_scripts/run_zmq_channel_emulator.sh" --show-ui "$SHOW_ZMQ_CHANNEL_EMULATOR_UI"
    if [ $# -eq 0 ]; then
        set -- 1
    fi
    if [ "$USE_IMSCOPE" = "true" ]; then
        set -- "$@" --imscope
    fi
    exec "$SCRIPT_DIR/run_split_du.sh" "$@"
fi

ADDITIONAL_FLAGS="-E"
if [ -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/libtelnetsrv.so" ]; then
    echo "Found telnet server library. Enabling telnet server..."
    TELNET_ADDRESS=127.0.0.1
    TELNET_PORT=9099
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv"
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.shrmod ci,o1"
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenaddr $TELNET_ADDRESS"
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenport $TELNET_PORT"
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenstdin 1"
fi
if [ "$USE_IMSCOPE" = "true" ]; then
    if [ ! -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/libimscope.so" ]; then
        echo "ERROR: ImScope library not found. Rerun full_install.sh after setting USE_IMSCOPE=true."
        exit 1
    fi
    echo "Enabling ImScope..."
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --imscope --log_config.global_log_options utc_time"
fi

cd "$SCRIPT_DIR"

# Write the hostname IP to the get_rfsim_server_address.txt file
HOSTNAME_IP=$(hostname -I | awk '{print $1}')
mkdir -p configs
echo "$HOSTNAME_IP" >configs/get_rfsim_server_address.txt

mkdir -p logs
if [ -f "logs/gnb_stdout.txt" ]; then
    sudo chown "${SUDO_USER:-$USER}" logs/gnb_stdout.txt
fi
>logs/gnb_stdout.txt

cd "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build"

# Code from (https://github.com/duranta-project/openairinterface5g/blob/develop/radio/rfsimulator/README.md#5g-case):
# sudo ./nr-softmodem -O "$SCRIPT_DIR/configs/gnb.conf" $RADIO_ARGS --gNBs.[0].min_rxtxtime 6 $ADDITIONAL_FLAGS

RADIO_TYPE=$(cat "$SCRIPT_DIR/configs/radio_type.txt" 2>/dev/null || echo "RFSIM")
if [ "$RADIO_TYPE" = "ZMQ" ]; then
    ZMQ_TX_PORT=4556
    ZMQ_RX_PORT=4557
    UE_NUMBER=1
    UE_NS_IP=$("$SCRIPT_DIR/install_scripts/get_ue_namespace_ip.sh" ue "$UE_NUMBER")
    RADIO_ARGS="--device.name oai_zmqdevif --zmq.[0].tx_channels tcp://0.0.0.0:$ZMQ_TX_PORT --zmq.[0].rx_channels tcp://$UE_NS_IP:$ZMQ_RX_PORT"
elif [ "$RADIO_TYPE" = "USRP" ]; then
    RADIO_ARGS=""
else
    RADIO_ARGS="--rfsim --rfsimulator.[0].serveraddr server --rfsimulator.[0].options chanmod"
fi

if [ "$USE_IMSCOPE" = true ]; then # ImScope GUI cannot be run with sudo
    script -q -f -c "./nr-softmodem -O \"$SCRIPT_DIR/configs/gnb.conf\" $RADIO_ARGS --gNBs.[0].min_rxtxtime 6 $ADDITIONAL_FLAGS" "$SCRIPT_DIR/logs/gnb_stdout.txt"
else
    sudo script -q -f -c "./nr-softmodem -O \"$SCRIPT_DIR/configs/gnb.conf\" $RADIO_ARGS --gNBs.[0].min_rxtxtime 6 $ADDITIONAL_FLAGS" "$SCRIPT_DIR/logs/gnb_stdout.txt"
fi

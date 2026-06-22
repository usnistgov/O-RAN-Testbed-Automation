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

USE_ZMQ_BROKER=false
SHOW_ZMQ_BROKER_UI=false
ZMQ_BROKER_PROCESS_RE="[m]ulti_ue_scenario\.py"
ZMQ_BROKER_READY_TIMEOUT=30

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Function to handle graceful shutdown
graceful_shutdown() {
    trap - SIGINT SIGTERM SIGQUIT
    echo "Shutting down gNodeB gracefully..."
    ./stop.sh
    exit
}
trap graceful_shutdown SIGINT SIGTERM SIGQUIT

port_is_listening() {
    PORT=$1
    if command -v ss >/dev/null 2>&1; then
        ss -ltn | awk '{ print $4 }' | grep -Eq "[:.]$PORT$"
        return
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -ltn | awk '{ print $4 }' | grep -Eq "[:.]$PORT$"
        return
    fi
    return 0
}

wait_for_zmq_broker_ready() {
    BROKER_FILE="zmq_broker/multi_ue_scenario.py"
    REQUIRED_PORTS="2001"

    if [ -f "$BROKER_FILE" ]; then
        UE_PORTS=$(awk '/^# UE_CONFIG: / { print $4 }' "$BROKER_FILE")
        for UE_PORT in $UE_PORTS; do
            REQUIRED_PORTS="$REQUIRED_PORTS $UE_PORT"
        done
    fi

    echo "Expected ZMQ Broker listening ports:$REQUIRED_PORTS"
    echo -n "Waiting for ZMQ Broker sockets"
    ATTEMPT=0
    while true; do
        ALL_READY=true
        for PORT in $REQUIRED_PORTS; do
            if ! port_is_listening "$PORT"; then
                ALL_READY=false
                break
            fi
        done
        if [ "$ALL_READY" = true ]; then
            break
        fi
        if ! pgrep -f "$ZMQ_BROKER_PROCESS_RE" >/dev/null; then
            echo
            echo "ZMQ Broker stopped before opening sockets. Recent broker log:"
            tail -n 80 logs/zmq_broker.log
            exit 1
        fi
        echo -n "."
        sleep 1
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge $ZMQ_BROKER_READY_TIMEOUT ]; then
            echo
            echo "ZMQ Broker sockets did not become ready after $ZMQ_BROKER_READY_TIMEOUT seconds."
            echo "Expected listening ports:$REQUIRED_PORTS"
            echo "Recent broker log:"
            tail -n 80 logs/zmq_broker.log
            exit 1
        fi
    done
    echo
}

if pgrep -x "gnb" >/dev/null; then
    echo "Already running gnb."
else
    echo "Starting gnb..."
    mkdir -p logs
    >logs/gnb.log
    >logs/gnb_stdout.txt

    if [ "$USE_ZMQ_BROKER" = "true" ]; then
        if pgrep -f "$ZMQ_BROKER_PROCESS_RE" >/dev/null; then
            echo "Already running ZMQ Broker."
            wait_for_zmq_broker_ready
        else
            >logs/zmq_broker.log
            echo "Starting ZMQ Broker..."
            if [ "$SHOW_ZMQ_BROKER_UI" = true ]; then
                nohup python3 zmq_broker/multi_ue_scenario.py >logs/zmq_broker.log 2>&1 &
            else
                QT_QPA_PLATFORM=offscreen nohup python3 zmq_broker/multi_ue_scenario.py >logs/zmq_broker.log 2>&1 &
            fi
            sleep 2
            if ! pgrep -f "$ZMQ_BROKER_PROCESS_RE" >/dev/null; then
                echo "ZMQ Broker failed to start. Recent broker log:"
                tail -n 80 logs/zmq_broker.log
                exit 1
            fi
            wait_for_zmq_broker_ready
        fi
    fi

    sudo chown --recursive "${SUDO_USER:-$USER}" logs

    # ocudu/build/apps/gnb/gnb -c configs/gnb.yaml # cell_cfg prach --ports 0 1 2
    sudo script -q -f -c "./ocudu/build/apps/gnb/gnb -c configs/gnb.yaml" logs/gnb_stdout.txt # cell_cfg prach --ports 0 1 2
fi

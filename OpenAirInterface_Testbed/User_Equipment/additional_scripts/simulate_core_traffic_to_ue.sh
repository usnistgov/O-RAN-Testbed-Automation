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
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

UE_NUMBER=$1
BANDWIDTH=${2:-1M}
DURATION=${3:-60}
IPERF_PORT=${4:-}

if [[ -z "$UE_NUMBER" ]]; then
    echo "ERROR: No UE number provided."
    echo "Usage: $0 <UE_NUMBER> [BANDWIDTH] [DURATION] [PORT]"
    echo "       BANDWIDTH is optional and can be specified in units [k, K, m, M, g, G]. Default is 1M."
    echo "       DURATION is optional and specifies the duration in seconds. Default is 60."
    echo "       PORT is optional. Default is 5000 + UE_NUMBER."
    exit 1
fi

if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
    echo "ERROR: UE number must be a number."
    exit 1
fi

if [ $UE_NUMBER -lt 1 ]; then
    echo "ERROR: UE number must be greater than or equal to 1."
    exit 1
fi

if [ -z "$IPERF_PORT" ]; then
    IPERF_PORT=$((5000 + UE_NUMBER))
fi
if ! [[ $IPERF_PORT =~ ^[0-9]+$ ]] || [ "$IPERF_PORT" -lt 1 ] || [ "$IPERF_PORT" -gt 65535 ]; then
    echo "ERROR: PORT must be an integer between 1 and 65535."
    exit 1
fi

if ! [[ $BANDWIDTH =~ ^[0-9]+[kmgKMG]$ ]]; then
    echo "ERROR: BANDWIDTH must be a number followed by a unit [k, K, m, M, g, G]."
    exit 1
fi

if ! [[ $DURATION =~ ^[0-9]+$ ]]; then
    echo "ERROR: DURATION must be a positive integer."
    exit 1
fi

if [ $DURATION -lt 1 ]; then
    echo "ERROR: DURATION must be greater than or equal to 1."
    exit 1
fi

if [ ! -f "configs/ue1.conf" ]; then
    echo "Configuration was not found for OAI UE 1. Please run ./generate_configurations.sh first."
    exit 1
fi

UE_NAMESPACE="ue$UE_NUMBER"
if ! ip netns list | grep -qw "$UE_NAMESPACE"; then
    echo "ERROR: Namespace $UE_NAMESPACE does not exist. Please start the UE first with: ./run_background.sh $UE_NUMBER"
    exit 1
fi

LOG_FILE="logs/ue${UE_NUMBER}_stdout.txt"
if [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: Log file $LOG_FILE does not exist. Please start the UE first."
    exit 1
fi
PDU_SESSION_IP=$(cat $LOG_FILE | grep "Received PDU Session Establishment Accept" | cut -d ':' -f2 | xargs | tr -d '\r\n')

if [ -z "$PDU_SESSION_IP" ]; then
    echo "ERROR: Unable to find PDU Session IP from the log file $LOG_FILE."
    exit 1
fi

echo "Successfully found PDU Session IP: $PDU_SESSION_IP"

CORE_OPTIONS="$PARENT_DIR/../5G_Core_Network/options.yaml"
CORE_TO_USE=$(awk '$1 == "core_to_use:" { print $2; exit }' "$CORE_OPTIONS" 2>/dev/null)
if [[ "$CORE_TO_USE" == 5gdeploy-* ]]; then
    command -v docker >/dev/null 2>&1 || {
        echo "ERROR: Docker is required by core_to_use=$CORE_TO_USE."
        exit 1
    }
    docker info >/dev/null 2>&1 || {
        echo "ERROR: Docker is not accessible while core_to_use=$CORE_TO_USE."
        exit 1
    }
    docker ps --format '{{.Names}}' | grep -qw dn_internet || {
        echo "ERROR: The 5GDeploy dn_internet container is not running."
        exit 1
    }
    USING_5GDEPLOY=true
else
    USING_5GDEPLOY=false
fi

if ! command -v iperf &>/dev/null; then
    echo "Package \"iperf\" not found, installing..."
    sudo env $APTVARS apt-get install -y iperf
fi

mkdir -p logs
SERVER_LOG="logs/iperf_dl_server_ue${UE_NUMBER}.log"
sudo ip netns exec "$UE_NAMESPACE" timeout "$((DURATION + 15))" \
    iperf -s -u -B "$PDU_SESSION_IP" -p "$IPERF_PORT" -i 1 >"$SERVER_LOG" 2>&1 &
IPERF_SERVER_PID=$!

cleanup_server() {
    if sudo kill -0 "$IPERF_SERVER_PID" 2>/dev/null; then
        sudo kill "$IPERF_SERVER_PID" 2>/dev/null || true
        wait "$IPERF_SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup_server EXIT
trap 'exit 130' INT TERM

sleep 1
if ! sudo kill -0 "$IPERF_SERVER_PID" 2>/dev/null; then
    echo "ERROR: Unable to start the iperf2 server in $UE_NAMESPACE on $PDU_SESSION_IP:$IPERF_PORT."
    cat "$SERVER_LOG"
    exit 1
fi

echo "Generating core-to-UE UDP traffic at $BANDWIDTH for ${DURATION}s on port $IPERF_PORT..."

if [ "$USING_5GDEPLOY" = true ]; then # 5GDeploy:
    docker exec dn_internet apk add --no-cache iperf
    docker exec dn_internet iperf -c "$PDU_SESSION_IP" -u -i 1 \
        -b "$BANDWIDTH" -t "$DURATION" -p "$IPERF_PORT"
else # Open5GS:
    iperf -c "$PDU_SESSION_IP" -u -i 1 -b "$BANDWIDTH" \
        -t "$DURATION" -p "$IPERF_PORT"
fi

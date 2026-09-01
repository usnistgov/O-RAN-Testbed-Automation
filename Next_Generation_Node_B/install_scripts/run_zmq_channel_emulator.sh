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

ZMQ_CHANNEL_EMULATOR_READY_TIMEOUT=30
SHOW_ZMQ_CHANNEL_EMULATOR_GUI=true
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    SHOW_ZMQ_CHANNEL_EMULATOR_GUI=false
fi

# Script directory from the called path, including symlinks
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    exec sudo -u "$SUDO_USER" "$SCRIPT_DIR/$(basename "$0")" "$@"
fi

usage() {
    echo "Usage: $0 [--show-ui true|false]"
}

while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --show-ui)
        if [ $# -lt 2 ]; then
            echo "ERROR: --show-ui requires true or false."
            usage
            exit 1
        fi
        SHOW_ZMQ_CHANNEL_EMULATOR_GUI=$2
        shift 2
        ;;
    *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
done

if [ "$SHOW_ZMQ_CHANNEL_EMULATOR_GUI" != "true" ] && [ "$SHOW_ZMQ_CHANNEL_EMULATOR_GUI" != "false" ]; then
    echo "ERROR: SHOW_ZMQ_CHANNEL_EMULATOR_GUI must be true or false."
    usage
    exit 1
fi

CHANNEL_EMULATOR_FILE=$("$PARENT_DIR/install_scripts/get_zmq_channel_emulator_config.sh" --channel-emulator-file)
CHANNEL_EMULATOR_LOG="$PARENT_DIR/logs/zmq_channel_emulator.log"
CHANNEL_EMULATOR_STARTED=false

if ! pgrep -f "[z]mq_channel_emulator\.py" >/dev/null; then
    "$PARENT_DIR/install_scripts/validate_zmq_channel_emulator_config.sh" --channel-emulator-only

    mkdir -p "$PARENT_DIR/logs"
    >"$CHANNEL_EMULATOR_LOG"
    echo "Starting ZeroMQ Channel Emulator..."
    if [ "$SHOW_ZMQ_CHANNEL_EMULATOR_GUI" = "true" ]; then
        nohup python3 "$CHANNEL_EMULATOR_FILE" >"$CHANNEL_EMULATOR_LOG" 2>&1 &
    else
        QT_QPA_PLATFORM=offscreen nohup python3 "$CHANNEL_EMULATOR_FILE" >"$CHANNEL_EMULATOR_LOG" 2>&1 &
    fi
    sleep 2
    if ! pgrep -f "[z]mq_channel_emulator\.py" >/dev/null; then
        echo "ZeroMQ Channel Emulator failed to start. Recent log output:"
        tail -n 80 "$CHANNEL_EMULATOR_LOG" 2>/dev/null || true
        exit 1
    fi
    CHANNEL_EMULATOR_STARTED=true
fi

mapfile -t REQUIRED_PORTS < <("$PARENT_DIR/install_scripts/get_zmq_channel_emulator_config.sh" --listen-ports)
if [ ${#REQUIRED_PORTS[@]} -eq 0 ]; then
    echo "ERROR: ZeroMQ Channel Emulator configuration does not contain any listening ports."
    exit 1
fi

if ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
    echo "ERROR: Either ss or netstat is required to check the ZeroMQ Channel Emulator sockets."
    exit 1
fi

if [ "$CHANNEL_EMULATOR_STARTED" = "true" ]; then
    echo "Expected ZeroMQ Channel Emulator listening ports: ${REQUIRED_PORTS[*]}"
    echo -n "Waiting for ZeroMQ Channel Emulator sockets"
fi
ATTEMPT=0
while true; do
    ALL_READY=true
    for PORT in "${REQUIRED_PORTS[@]}"; do
        if command -v ss >/dev/null 2>&1; then
            if ! ss -ltnH | awk '{ print $4 }' | grep -Eq "[:.]${PORT}$"; then
                ALL_READY=false
                break
            fi
        elif ! netstat -ltn | awk '{ print $4 }' | grep -Eq "[:.]${PORT}$"; then
            ALL_READY=false
            break
        fi
    done

    if [ "$ALL_READY" = "true" ]; then
        if [ "$CHANNEL_EMULATOR_STARTED" = "true" ]; then
            echo
        fi
        break
    fi
    if ! pgrep -f "[z]mq_channel_emulator\.py" >/dev/null; then
        if [ "$CHANNEL_EMULATOR_STARTED" = "true" ]; then
            echo
        fi
        echo "ZeroMQ Channel Emulator stopped before opening its sockets. Recent log output:"
        tail -n 80 "$CHANNEL_EMULATOR_LOG" 2>/dev/null || true
        exit 1
    fi

    if [ "$CHANNEL_EMULATOR_STARTED" = "true" ]; then
        echo -n "."
    fi
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
    if [ "$ATTEMPT" -ge "$ZMQ_CHANNEL_EMULATOR_READY_TIMEOUT" ]; then
        if [ "$CHANNEL_EMULATOR_STARTED" = "true" ]; then
            echo
        fi
        echo "ZeroMQ Channel Emulator sockets did not become ready after $ZMQ_CHANNEL_EMULATOR_READY_TIMEOUT seconds."
        echo "Recent log output:"
        tail -n 80 "$CHANNEL_EMULATOR_LOG" 2>/dev/null || true
        exit 1
    fi
done

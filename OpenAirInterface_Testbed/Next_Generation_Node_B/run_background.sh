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

IMSCOPE_ENABLED=false
USE_ZMQ_CHANNEL_EMULATOR=false
SHOW_ZMQ_CHANNEL_EMULATOR_GUI=false
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    SHOW_ZMQ_CHANNEL_EMULATOR_GUI=false
fi

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
        IMSCOPE_ENABLED=true
        shift
        ;;
    *)
        ENV_ARGS+=("$1")
        shift
        ;;
    esac
done
set -- "${ENV_ARGS[@]}"

cd "$SCRIPT_DIR"

if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    if [ ! -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/liboai_zmqdevif.so" ]; then
        echo "ERROR: ZeroMQ device library not found. Rerun full_install.sh after setting RADIO_TYPE=\"ZMQ\"."
        exit 1
    fi
    ./install_scripts/run_zmq_channel_emulator.sh --show-ui "$SHOW_ZMQ_CHANNEL_EMULATOR_GUI"
    if [ $# -eq 0 ]; then
        set -- 1
    fi
    if [ "$IMSCOPE_ENABLED" = "true" ]; then
        set -- "$@" --imscope
    fi
    exec "$SCRIPT_DIR/run_background_split_du.sh" "$@"
fi

if pgrep -x "nr-softmodem" >/dev/null; then
    echo "Already running gNodeB."
else
    if [ ! -f "configs/gnb.conf" ]; then
        echo "Configuration was not found for Duranta gNodeB. Please run ./generate_configurations.sh first."
        exit 1
    fi

    echo "Starting gNodeB in background..."

    sudo -v # Ensure sudo session is active
    if [ "$IMSCOPE_ENABLED" = "true" ]; then
        setsid bash -c "exec stdbuf -oL -eL \"$SCRIPT_DIR/run.sh\" --imscope" </dev/null >/dev/null 2>&1 &
    else
        sudo setsid bash -c "exec stdbuf -oL -eL \"$SCRIPT_DIR/run.sh\"" </dev/null >/dev/null 2>&1 &
    fi
    stty sane || true

    ATTEMPT=0
    while $(./is_running.sh | grep -q "NOT_RUNNING"); do
        stty sane || true
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -ge 120 ]; then
            echo "gNodeB did not start after 60 seconds, exiting..."
            exit 1
        fi
    done

    stty sane || true
    ./is_running.sh
fi

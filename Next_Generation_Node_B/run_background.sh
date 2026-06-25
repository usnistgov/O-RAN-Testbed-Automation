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

USE_ZMQ_BROKER=true

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if pgrep -x "gnb" >/dev/null; then
    echo "Already running gnb."
else
    if [ ! -f "configs/gnb.yaml" ]; then
        echo "Configuration was not found for OCUDU. Please run ./generate_configurations.sh first."
        exit 1
    fi

    # Allow ZMQ Broker UI to access the display if xhost is available
    ZMQ_BROKER_UI_ENV=""
    if [ "$USE_ZMQ_BROKER" = "true" ] && [ -n "$DISPLAY" ]; then
        ZMQ_BROKER_UI_ENV="DISPLAY=$DISPLAY XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}"
        if command -v xhost &>/dev/null; then
            xhost +SI:localuser:root >/dev/null 2>&1 || true
        fi
    fi

    echo "Starting gNodeB in background..."
    mkdir -p logs
    >logs/gnb_stdout.txt
    sudo chown --recursive "${SUDO_USER:-$USER}" logs

    sudo -v # Ensure sudo session is active
    sudo env $ZMQ_BROKER_UI_ENV setsid bash -c "stdbuf -oL -eL \"$SCRIPT_DIR/run.sh\" >/dev/null 2>&1" </dev/null &

    echo -n "Waiting for gNodeB to be ready"
    ATTEMPT=0
    while true; do
        if ! GNB_READY_OUTPUT=$(./is_gnb_ready.sh); then
            GNB_READY_OUTPUT="error"
        fi
        if [ "$GNB_READY_OUTPUT" = "true" ]; then
            break
        fi
        if [ "$GNB_READY_OUTPUT" = "error" ]; then
            echo
            echo "gNodeB failed to start. Recent stdout:"
            tail -n 80 logs/gnb_stdout.txt
            exit 1
        fi

        echo -n "."
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))

        if [ $ATTEMPT -ge 120 ]; then
            echo
            echo "gNodeB did not report readiness after 60 seconds."
            echo
            echo "Recent stdout:"
            [ -f logs/gnb_stdout.txt ] && tail -n 120 logs/gnb_stdout.txt
            if [ -s logs/gnb.log ]; then
                echo
                echo "Recent gNB log:"
                tail -n 120 logs/gnb.log
            fi
            exit 1
        fi
    done
    echo -e "\ngNodeB is ready."
    ./is_running.sh
fi

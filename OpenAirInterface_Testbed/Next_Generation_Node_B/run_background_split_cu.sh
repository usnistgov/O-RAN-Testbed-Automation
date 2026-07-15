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

cd "$SCRIPT_DIR"

if ./is_cu_ready.sh | grep -qx true; then
    echo "Already running gNodeB (CU)."
else
    if [ ! -d "configs" ]; then
        echo "Configuration directory does not exist. Please run ./generate_configurations.sh first."
        exit 1
    fi

    CU_PID=""
    if ! ./is_running.sh | grep -Eq '(^|[ (])cu([ )]|$)'; then
        echo "Starting CU in background..."

        sudo -v # Ensure sudo session is active
        sudo setsid --wait bash -c "exec stdbuf -oL -eL \"$SCRIPT_DIR/run_split_cu.sh\"" </dev/null >/dev/null 2>&1 &
        CU_PID=$!
        if [ -t 0 ]; then
            stty sane || true
        fi
    else
        echo "Waiting for the running CU to be ready..."
    fi

    ATTEMPT=0
    while ! ./is_cu_ready.sh | grep -qx true; do
        sleep 0.5
        ATTEMPT=$((ATTEMPT + 1))
        if { [ -n "$CU_PID" ] && ! ps -p "$CU_PID" >/dev/null; } ||
            { [ -z "$CU_PID" ] && ! ./is_running.sh | grep -Eq '(^|[ (])cu([ )]|$)'; }; then
            wait "$CU_PID" 2>/dev/null || true
            echo "CU exited before its F1-C socket was ready. Check logs/split_cu_stdout.txt."
            exit 1
        fi
        if [ $ATTEMPT -ge 120 ]; then
            echo "CU F1-C socket did not become ready after 60 seconds. Check logs/split_cu_stdout.txt."
            exit 1
        fi
    done

    if [ -t 0 ]; then
        stty sane || true
    fi
    ./is_running.sh
fi

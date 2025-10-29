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

# Check if the gNodeB is already stopped
if $(./is_running.sh | grep -q "gNodeB: NOT_RUNNING"); then
    ./is_running.sh
    exit 0
fi

if [ "$#" -eq 1 ]; then
    SELECTOR=$1
fi

DU_NUMBER=""
if [[ $SELECTOR =~ ^[0-9]+$ ]]; then
    DU_NUMBER=$SELECTOR
elif [[ $SELECTOR =~ ^du[0-9]+$ ]]; then
    DU_NUMBER=${SELECTOR:2}
fi

# Remove a network namespace given the DU number
remove_du_namespace() {
    local DU_NUMBER="$1"
    if ! ip netns list | grep -qw "du$DU_NUMBER"; then
        echo "Namespace du$DU_NUMBER does not exist, skipping removal."
        return
    fi
    echo "Removing namespace du$DU_NUMBER..."
    sudo ./install_scripts/revert_du_namespace.sh "$DU_NUMBER"
}

# Remove all DU network namespaces
remove_all_du_namespaces() {
    # Get all active DU namespaces, and remove the namespaces
    DU_NETNS=($(ip netns list | grep -oP '^du\K[0-9]+'))
    for DU_NUM in "${DU_NETNS[@]}"; do
        remove_du_namespace "$DU_NUM"
    done
}

# Check if the DU is already stopped
if $(./is_running.sh | grep -q "gNodeB: NOT_RUNNING"); then
    # Remove DU namespaces
    if [ -z "$DU_NUMBER" ]; then
        remove_all_du_namespaces
    else
        remove_du_namespace "$DU_NUMBER"
    fi
    ./is_running.sh
    exit 0
fi

# Prevent the subsequent command from requiring credential input
sudo ls >/dev/null 2>&1

# Send a graceful shutdown signal to the gNodeB process
if [ -z "$SELECTOR" ]; then
    sudo pkill -f "nr-softmodem" >/dev/null 2>&1
    remove_all_du_namespaces
    stty sane || true
else
    # Find all nr-softmodem processes with -O <config> argument
    pgrep -af "nr-softmodem.*-O" | while read -r LINE; do
        PID=$(echo "$LINE" | awk '{print $1}')
        # Extract the -O argument value (config path)
        CONFIG_PATH=$(echo "$LINE" | grep -oP '(?<=-O )[^ ]+')
        if [ -n "$CONFIG_PATH" ]; then
            CONFIG_FILE=$(basename "$CONFIG_PATH")
            if [[ "$CONFIG_FILE" == *"$SELECTOR"* ]]; then
                #echo "Stopping nr-softmodem with config $CONFIG_FILE (PID $PID)..."
                sudo kill "$PID" >/dev/null 2>&1
            fi
        fi
    done
    if [ -n "$DU_NUMBER" ]; then
        remove_du_namespace "$DU_NUMBER"
    fi
fi

# Wait for the process to terminate gracefully
COUNT=0
MAX_COUNT=5
sleep 1
while [ $COUNT -lt $MAX_COUNT ]; do
    IS_RUNNING=$(./is_running.sh)
    if [ -z "$SELECTOR" ]; then
        if echo "$IS_RUNNING" | grep -q "gNodeB: NOT_RUNNING"; then
            echo "The gNodeB has stopped gracefully."
            ./is_running.sh
            exit 0
        fi
    else
        if ! echo "$IS_RUNNING" | grep -q "$SELECTOR"; then
            echo "The gNodeB component '$SELECTOR' has stopped gracefully."
            ./is_running.sh
            exit 0
        fi
    fi
    COUNT=$((COUNT + 1))
    echo "$IS_RUNNING [$((MAX_COUNT - COUNT + 1))]"
    sleep 2
done

# If the process is still running after 20 seconds, send a forceful kill signal
if [ -z "$SELECTOR" ]; then
    echo "The gNodeB did not stop in time, sending forceful kill signal..."
    sudo pkill -9 -f "nr-softmodem" >/dev/null 2>&1
    remove_all_du_namespaces
    stty sane || true
else
    echo "The gNodeB component '$SELECTOR' did not stop in time, sending forceful kill signal..."
    # Find all nr-softmodem processes with -O <config> argument
    pgrep -af "nr-softmodem.*-O" | while read -r LINE; do
        PID=$(echo "$LINE" | awk '{print $1}')
        # Extract the -O argument value (config path)
        CONFIG_PATH=$(echo "$LINE" | grep -oP '(?<=-O )[^ ]+')
        if [ -n "$CONFIG_PATH" ]; then
            CONFIG_FILE=$(basename "$CONFIG_PATH")
            if [[ "$CONFIG_FILE" == *"$SELECTOR"* ]]; then
                #echo "Force stopping nr-softmodem with config $CONFIG_FILE (PID $PID)..."
                sudo kill -9 "$PID" >/dev/null 2>&1
            fi
        fi
    done
    if [ -n "$DU_NUMBER" ]; then
        remove_du_namespace "$DU_NUMBER"
    fi
fi

sleep 2
./is_running.sh

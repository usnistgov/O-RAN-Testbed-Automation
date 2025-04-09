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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Check if the gNodeB is already stopped
if $(./is_running.sh | grep -q "gNodeB: NOT_RUNNING"); then
    ./is_running.sh
    exit 0
fi

# Prevent the subsequent command from requiring credential input
sudo ls >/dev/null 2>&1

# Send a graceful shutdown signal to the gNodeB process
sudo pkill -f "gnb" >/dev/null 2>&1 &

# Wait for the process to terminate gracefully
COUNT=0
MAX_COUNT=10
sleep 1
while [ $COUNT -lt $MAX_COUNT ]; do
    IS_RUNNING=$(./is_running.sh)
    echo "$IS_RUNNING ($COUNT / $MAX_COUNT)"
    if echo "$IS_RUNNING" | grep -q "gNodeB: NOT_RUNNING"; then
        echo "The gNodeB has stopped gracefully."
        ./is_running.sh
        exit 0
    fi
    COUNT=$((COUNT + 1))
    sleep 2
done

# If the process is still running after 20 seconds, send a forceful kill signal
echo "The gNodeB did not stop in time, sending forceful kill signal..."
sudo pkill -9 -f "gnb" >/dev/null 2>&1 &

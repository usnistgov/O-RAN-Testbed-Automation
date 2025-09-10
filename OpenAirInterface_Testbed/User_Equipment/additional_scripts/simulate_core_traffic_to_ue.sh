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

if [[ -z "$UE_NUMBER" ]]; then
    echo "Error: No UE number provided."
    echo "Usage: $0 <UE_NUMBER> [BANDWIDTH] [DURATION]"
    echo "       BANDWIDTH is optional and can be specified in units [k, K, m, M]. Default is 1M."
    echo "       DURATION is optional and specifies the duration in seconds. Default is 60."
    exit 1
fi

if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
    echo "Error: UE number must be a number."
    exit 1
fi

if [ $UE_NUMBER -lt 1 ]; then
    echo "Error: UE number must be greater than or equal to 1."
    exit 1
fi

if ! [[ $BANDWIDTH =~ ^[0-9]+[kKmM]$ ]]; then
    echo "Error: BANDWIDTH must be a number followed by a unit [k, K, m, M]."
    exit 1
fi

if ! [[ $DURATION =~ ^[0-9]+$ ]]; then
    echo "Error: DURATION must be a positive integer."
    exit 1
fi

if [ $DURATION -lt 1 ]; then
    echo "Error: DURATION must be greater than or equal to 1."
    exit 1
fi

if [ ! -f "configs/ue1.conf" ]; then
    echo "Configuration was not found for OAI UE 1. Please run ./generate_configurations.sh first."
    exit 1
fi

LOG_FILE="logs/ue${UE_NUMBER}_stdout.txt"
PDU_SESSION_IP=$(cat $LOG_FILE | grep "Received PDU Session Establishment Accept" | cut -d ':' -f2 | xargs | tr -d '\r\n')

if [ -z "$PDU_SESSION_IP" ]; then
    echo "Error: Unable to find PDU Session IP from the log file $LOG_FILE."
    exit 1
fi

echo "Successfully found PDU Session IP: $PDU_SESSION_IP"


if ! command -v iperf &>/dev/null; then
    echo "Package \"iperf\" not found, installing..."
    sudo env $APTVARS apt-get install -y iperf
fi

iperf -c $PDU_SESSION_IP -u -i 1 -b $BANDWIDTH -t $DURATION

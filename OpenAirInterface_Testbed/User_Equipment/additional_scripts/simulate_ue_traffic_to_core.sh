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
PDU_SESSION_IP=${4:-}

if [[ -z "$UE_NUMBER" ]]; then
    echo "ERROR: No UE number provided."
    echo "Usage: $0 <UE_NUMBER> [BANDWIDTH] [DURATION] [PDU_SESSION_IP]"
    echo "       BANDWIDTH is optional and can be specified in units [k, K, m, M, g, G]. Default is 1M."
    echo "       DURATION is optional and specifies the duration in seconds. Default is 60."
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

if [ ! -f "configs/ue${UE_NUMBER}.conf" ]; then
    echo "Configuration was not found for OAI UE $UE_NUMBER. Please run ./generate_configurations.sh first."
    exit 1
fi

# Remove the CIDR suffix from an IP address
# For example, 10.45.0.1/16 --> 10.45.0.1
remove_cidr_suffix() {
    local IP=$1
    echo "${IP%/*}"
}

UE_NAMESPACE="ue$UE_NUMBER"

# If the namespace doesn't exist
if ! ip netns list | grep -qw "$UE_NAMESPACE"; then
    echo "ERROR: Namespace $UE_NAMESPACE does not exist. Please start the UE first with: ./run_background.sh $UE_NUMBER"
    exit 1
fi

if [ -z "$PDU_SESSION_IP" ]; then # Select a PDU session
    if ! PDU_SESSION_OUTPUT=$(./additional_scripts/get_pdu_sessions.sh "$UE_NUMBER" 2>&1); then
        echo "$PDU_SESSION_OUTPUT"
        exit 1
    fi

    PDU_SESSIONS=()
    while IFS= read -r SESSION; do
        [ -n "$SESSION" ] && PDU_SESSIONS+=("$SESSION")
    done <<<"$PDU_SESSION_OUTPUT"

    if [ ${#PDU_SESSIONS[@]} -eq 0 ]; then
        echo "ERROR: No PDU sessions found for UE $UE_NUMBER."
        exit 1
    fi

    if [ ${#PDU_SESSIONS[@]} -eq 1 ]; then
        PDU_SESSION_IP="${PDU_SESSIONS[0]}"
    else
        echo "Available PDU sessions for UE $UE_NUMBER:"
        for INDEX in "${!PDU_SESSIONS[@]}"; do
            echo "$((INDEX + 1)). ${PDU_SESSIONS[$INDEX]}"
        done
        read -p "Select PDU session: " SELECTION
        if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#PDU_SESSIONS[@]} ]; then
            echo "ERROR: Invalid PDU session selection."
            exit 1
        fi
        PDU_SESSION_IP="${PDU_SESSIONS[$((SELECTION - 1))]}"
    fi
fi

CORE_IP=$(ip route | grep ogstun | cut -d ' ' -f 9 | xargs)
if [ -z "$CORE_IP" ]; then # 5GDeploy:
    if sudo ip netns exec "$UE_NAMESPACE" ip route | grep -q "oaitun_ue$UE_NUMBER"; then
        SUBNET=$(sudo ip netns exec "$UE_NAMESPACE" ip route | grep "oaitun_ue$UE_NUMBER" | grep -v "default" | awk '{print $1}')
        if [ -n "$SUBNET" ]; then
            CORE_IP=$(remove_cidr_suffix "$SUBNET")
            CORE_IP="${CORE_IP%.0}.1"
        fi
    fi
fi

echo "Using PDU Session IP: $PDU_SESSION_IP"
echo "Using 5G Core IP: $CORE_IP"

if [ -z "$CORE_IP" ]; then
    echo "WARNING: Unable to find 5G core IP from the routing table."
    read -p "Please enter the IP address of the 5G core: " CORE_IP
    if [ -z "$CORE_IP" ]; then
        echo "ERROR: No IP address provided. Exiting."
        exit 1
    fi
fi

if ! command -v iperf &>/dev/null; then
    echo "Package \"iperf\" not found, installing..."
    sudo env $APTVARS apt-get install -y iperf
fi

sudo ip netns exec "$UE_NAMESPACE" iperf -c "$CORE_IP" -u -i 1 -b "$BANDWIDTH" -t "$DURATION"

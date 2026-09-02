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

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR=$(dirname "$SCRIPT_DIR")
BASE_SUBNET="10.201.0.0/16"
SUBNET_SIZE=4
OUTPUT="$PARENT_DIR/zmq_channel_emulator/zmq_channel_emulator.py" # multi_ue_scenario.py
REQUESTED_CELLS="1"
REQUESTED_UES="1,2,3"

usage() {
    echo "Usage: $0 [--output FILE] [--cells 1] [--ues 1,2,3]"
}

while [ $# -gt 0 ]; do
    case "$1" in
    --output)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            usage
            exit 1
        fi
        OUTPUT="$2"
        shift 2
        ;;
    --cells)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            usage
            exit 1
        fi
        REQUESTED_CELLS="$2"
        shift 2
        ;;
    --ues)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            usage
            exit 1
        fi
        REQUESTED_UES="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "ERROR: Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
done

if [ -z "$OUTPUT" ]; then
    usage
    exit 1
fi

if [ "$REQUESTED_CELLS" != "1" ] || ! [[ "$REQUESTED_UES" =~ ^[1-9][0-9]*(,[1-9][0-9]*)*$ ]]; then
    echo "ERROR: The OCUDU ZeroMQ broker supports only cell 1 and UEs 1,2,3 (requested cells: $REQUESTED_CELLS; UEs: $REQUESTED_UES)."
    exit 1
fi
IFS=',' read -r -a REQUESTED_UE_NUMBERS <<<"$REQUESTED_UES"
if [ ${#REQUESTED_UE_NUMBERS[@]} -ne 3 ]; then
    echo "ERROR: The OCUDU ZeroMQ broker supports only cell 1 and UEs 1,2,3 (requested cells: $REQUESTED_CELLS; UEs: $REQUESTED_UES)."
    exit 1
fi
for UE_NUMBER in 1 2 3; do
    if [[ ",$REQUESTED_UES," != *",$UE_NUMBER,"* ]]; then
        echo "ERROR: The OCUDU ZeroMQ broker supports only cell 1 and UEs 1,2,3 (requested cells: $REQUESTED_CELLS; UEs: $REQUESTED_UES)."
        exit 1
    fi
done

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"

echo "Compiling ZeroMQ Broker GNU Radio Companion flowgraph..."
ZMQ_DIR="$(dirname "$OUTPUT")"
mkdir -p "$ZMQ_DIR"

if ! command -v grcc >/dev/null 2>&1; then
    echo "Installing GNU Radio Companion Compiler (grcc) for the ZeroMQ Broker..."
    sudo env $APTVARS apt-get install -y gnuradio
fi

GRC_FILE="$ZMQ_DIR/multi_ue_scenario.grc"
LICENSE_FILE="$GRC_FILE.license"
if [ ! -f "$GRC_FILE" ] || [ ! -f "$LICENSE_FILE" ]; then
    if ! command -v jq &>/dev/null; then
        echo "Installing jq..."
        sudo env $APTVARS apt-get install -y jq
    fi
    DOCS_HASH=$(jq -r '."https://gitlab.com/ocudu/ocudu_docs.git"[1]' "$PARENT_DIR/../commit_hashes.json" 2>/dev/null || echo "main")
    if [ -z "$DOCS_HASH" ] || [ "$DOCS_HASH" = "null" ]; then
        DOCS_HASH="main"
    fi
    echo "Downloading ZeroMQ Broker GNU Radio Companion flowgraph (${DOCS_HASH})..."
    rm -f "$GRC_FILE.tmp" "$LICENSE_FILE.tmp"
    if ! wget -qO "$GRC_FILE.tmp" "https://gitlab.com/ocudu/ocudu_docs/-/raw/${DOCS_HASH}/docs/tutorials/srsue/assets/multi_ue_scenario.grc" ||
        ! wget -qO "$LICENSE_FILE.tmp" "https://gitlab.com/ocudu/ocudu_docs/-/raw/${DOCS_HASH}/docs/tutorials/srsue/assets/multi_ue_scenario.grc.license"; then
        rm -f "$GRC_FILE" "$LICENSE_FILE" "$GRC_FILE.tmp" "$LICENSE_FILE.tmp" "$OUTPUT"
        echo "ERROR: Failed to download the OCUDU flowgraph and license."
        exit 1
    fi
    mv "$GRC_FILE.tmp" "$GRC_FILE"
    mv "$LICENSE_FILE.tmp" "$LICENSE_FILE"
fi

# GNU Radio 3.8 issue with vmcircbuf_default_factory
mkdir -p ~/.gnuradio/prefs
if [ ! -f ~/.gnuradio/prefs/vmcircbuf_default_factory ]; then
    echo "gr::vmcircbuf_sysv_shm_factory" >~/.gnuradio/prefs/vmcircbuf_default_factory
fi
sudo mkdir -p /root/.gnuradio/prefs
if ! sudo test -f /root/.gnuradio/prefs/vmcircbuf_default_factory; then
    sudo bash -c 'echo "gr::vmcircbuf_sysv_shm_factory" > /root/.gnuradio/prefs/vmcircbuf_default_factory'
fi

# Numpy version must be less than 2 to avoid grcc compatibility issue
NUMPY_VERSION=$(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "0")
NUMPY_MAJOR=$(echo "$NUMPY_VERSION" | cut -d. -f1)
if [ "$NUMPY_MAJOR" -ge 2 ]; then
    echo "Downgrading NumPy to version < 2 for GNU Radio compatibility..."
    pip3 install "numpy<2" --break-system-packages
fi

grcc -o "$ZMQ_DIR" "$GRC_FILE"
mv "$ZMQ_DIR/multi_ue_scenario.py" "$OUTPUT"

if [ ! -f "$OUTPUT" ]; then
    echo "Failed to locate $OUTPUT after generation."
    exit 1
fi

echo "Synchronizing ZeroMQ Broker endpoints with UE subnet mapping..."

# The OCUDU ZeroMQ Broker supports only one cell right now
CHANNEL_EMULATOR_CONFIG="# CELL_CONFIG: 1 2000 2001"

UE_NUMBER=1
while true; do
    PORT_RX=$((2100 + (UE_NUMBER - 1) * 100))
    PORT_TX=$((2101 + (UE_NUMBER - 1) * 100))

    # Stop when the UE endpoint does not exist in the broker graph
    if ! grep -qE "'tcp://(127\\.0\\.0\\.1|\*):$PORT_RX'" "$OUTPUT"; then
        break
    fi

    SUBNET_OFFSET=$((UE_NUMBER * SUBNET_SIZE))
    UE_IP_OFFSET=$((SUBNET_OFFSET + 1)) # .6
    UE_IP=$(python3 "$SCRIPT_DIR/fetch_nth_ip.py" "$BASE_SUBNET" "$UE_IP_OFFSET")

    CHANNEL_EMULATOR_CONFIG=$(printf '# UE_CONFIG: %s %s %s %s\n%s' "$UE_NUMBER" "$PORT_RX" "$PORT_TX" "$UE_IP" "$CHANNEL_EMULATOR_CONFIG")

    # UE RX: broker should listen on all interfaces in the host namespace
    sed -i "s|'tcp://127\\.0\\.0\\.1:$PORT_RX'|'tcp://*:$PORT_RX'|g" "$OUTPUT"

    # UE TX: force broker to connect to current UE namespace IP every run
    sed -i "s|'tcp://127\\.0\\.0\\.1:$PORT_TX'|'tcp://$UE_IP:$PORT_TX'|g" "$OUTPUT"
    sed -i "s|'tcp://10\\.[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+:$PORT_TX'|'tcp://$UE_IP:$PORT_TX'|g" "$OUTPUT"

    UE_NUMBER=$((UE_NUMBER + 1))
done

GENERATED_UE_COUNT=$((UE_NUMBER - 1))
if [ "$GENERATED_UE_COUNT" -ne 3 ]; then
    rm -f "$OUTPUT"
    echo "ERROR: The OCUDU flowgraph contains $GENERATED_UE_COUNT UE endpoints instead of 3."
    exit 1
fi

if ! grep -q '^# GNU Radio version:' "$OUTPUT"; then
    rm -f "$OUTPUT"
    echo "ERROR: GNU Radio header not found in the generated OCUDU flowgraph."
    exit 1
fi
awk -v config="$CHANNEL_EMULATOR_CONFIG" '
    { print }
    !inserted && /^# GNU Radio version:/ {
        print ""
        print config
        inserted = 1
    }
' "$OUTPUT" >"$OUTPUT.tmp"
mv "$OUTPUT.tmp" "$OUTPUT"

echo "Successfully synchronized ZMQ Broker Python script for $GENERATED_UE_COUNT UEs."

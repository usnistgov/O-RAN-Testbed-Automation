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
    sudo $APTVARS apt-get install -y coreutils
fi

echo "# Script: $(realpath $0)..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

DBCTL_DIR="./open5gs/misc/db/open5gs-dbctl"

# Default values as specified in your documentation
DEFAULT_IMSI="001010123456780"
DEFAULT_KEY="00112233445566778899aabbccddeeff"
DEFAULT_OPC="63BFA50EE6523365FF14C1F45F88737D"
DEFAULT_APN="internet"
DEFAULT_SST=""
DEFAULT_SD=""

./start_webui.sh no-browser

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --imsi [IMSI]                 Set the IMSI value (default: $DEFAULT_IMSI)"
    echo "  --key [Key]                   Set the authentication key (default: $DEFAULT_KEY)"
    echo "  --opc [OPC]                   Set the OPC value (default: $DEFAULT_OPC)"
    echo "  --apn [APN]                   Set the APN value (default: $DEFAULT_APN)"
    echo "  --sst [SST]                   Set the SST value (optional)"
    echo "  --sd [SD]                     Set the SD value (optional)"
    echo "  -h, --help                    Display this help message and exit"
    exit 1
}

# Check if the dbctl file exists
if [ ! -f "$DBCTL_DIR" ]; then
    echo "Error: The dbctl script ($DBCTL_DIR) does not exist."
    usage
fi

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --imsi)
        IMSI="${2}"
        shift
        ;;
    --key)
        KEY="${2}"
        shift
        ;;
    --opc)
        OPC="${2}"
        shift
        ;;
    --apn)
        APN="${2}"
        shift
        ;;
    --sst)
        SST="${2}"
        shift
        ;;
    --sd)
        SD="${2}"
        shift
        ;;
    -h | --help) usage ;;
    *)
        echo "Unknown parameter passed: $1"
        usage
        ;;
    esac
    shift
done

# Set default values if variables are not set
IMSI="${IMSI:-$DEFAULT_IMSI}"
KEY="${KEY:-$DEFAULT_KEY}"
OPC="${OPC:-$DEFAULT_OPC}"
APN="${APN:-$DEFAULT_APN}"
SST="${SST:-$DEFAULT_SST}"
SD="${SD:-$DEFAULT_SD}"

# Check if the subscriber already exists
if $DBCTL_DIR showpretty | grep -q "imsi: '$IMSI'"; then
    echo "Subscriber with IMSI $IMSI already exists in the database."
    exit 0
fi

# Command to add subscriber using the open5gs-dbctl tool
if [[ -n "$SST" && -n "$SD" ]]; then
    CMD="$DBCTL_DIR add_ue_with_slice $IMSI $KEY $OPC $APN $SST $SD"
else
    CMD="$DBCTL_DIR add_ue_with_apn $IMSI $KEY $OPC $APN"
fi

echo "Running command: $CMD"
$CMD

# Check exit status of the command
if [ $? -eq 0 ]; then
    echo "Subscriber successfully added to the database."
    $DBCTL_DIR showpretty
else
    echo "Failed to add subscriber to the database."
fi

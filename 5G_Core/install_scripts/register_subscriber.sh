#!/bin/bash

DBCTL_DIR="./open5gs/misc/db/open5gs-dbctl"

# Default values as specified in your documentation
DEFAULT_IMSI="001010123456780"
DEFAULT_KEY="00112233445566778899aabbccddeeff"
DEFAULT_OPC="63BFA50EE6523365FF14C1F45F88737D"
DEFAULT_APN="srsapn"

if ! systemctl is-active --quiet "open5gs-webui"; then
    echo "WebUI not running. Starting..."
    sudo systemctl start open5gs-webui
fi

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --imsi [IMSI]                 Set the IMSI value (default: $DEFAULT_IMSI)"
    echo "  --key [Key]                   Set the authentication key (default: $DEFAULT_KEY)"
    echo "  --opc [OPC]                   Set the OPC value (default: $DEFAULT_OPC)"
    echo "  --apn [APN]                   Set the APN value (default: $DEFAULT_APN)"
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
        --imsi) IMSI="${2}"; shift ;;
        --key) KEY="${2}"; shift ;;
        --opc) OPC="${2}"; shift ;;
        --apn) APN="${2}"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Set default values if variables are not set
IMSI="${IMSI:-$DEFAULT_IMSI}"
KEY="${KEY:-$DEFAULT_KEY}"
OPC="${OPC:-$DEFAULT_OPC}"
APN="${APN:-$DEFAULT_APN}"

# Check if the subscriber already exists
if $DBCTL_DIR showpretty | grep -q "imsi: '$IMSI'"; then
    echo "Subscriber with IMSI $IMSI already exists in the database."
    exit 0
fi

# Command to add subscriber using the open5gs-dbctl tool
CMD="$DBCTL_DIR add_ue_with_apn $IMSI $KEY $OPC $APN"

echo "Running command: $CMD"
$CMD

# Check exit status of the command
if [ $? -eq 0 ]; then
    echo "Subscriber successfully added to the database."
    $DBCTL_DIR showpretty
else
    echo "Failed to add subscriber to the database."
fi


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

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

DBCTL_PATH="./open5gs/misc/db/open5gs-dbctl"

# Default values as specified in your documentation
DEFAULT_IMSI="001010123456780"
DEFAULT_KEY="00112233445566778899aabbccddeeff"
DEFAULT_OPC="63BFA50EE6523365FF14C1F45F88737D"
DEFAULT_APN="internet"
DEFAULT_SST=""
DEFAULT_SD=""
DEFAULT_IPV4=""
DEFAULT_IPV6=""

APNS=()
IPV4S=()

./start_webui.sh no-browser

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --imsi [IMSI]                 Set the IMSI value (default: $DEFAULT_IMSI)"
    echo "  --key [Key]                   Set the authentication key (default: $DEFAULT_KEY)"
    echo "  --opc [OPC]                   Set the OPC value (default: $DEFAULT_OPC)"
    echo "  --apn [APN]                   Set the APN value (default: $DEFAULT_APN). Can be specified multiple times."
    echo "  --sst [SST]                   Set SST in decimal (optional). Hex is also accepted with 0x prefix"
    echo "  --sd [SD]                     Set SD in hex (optional). A 0x prefix is also accepted"
    echo "  --ipv4 [IPv4]                 Set the IPv4 address (optional). Can be specified multiple times."
    echo "  --ipv6 [IPv6]                 Set the IPv6 address (optional)"
    echo "  -h, --help                    Display this help message and exit"
    exit 1
}

# Check if the dbctl file exists
if [ ! -f "$DBCTL_PATH" ]; then
    echo "ERROR: The dbctl script ($DBCTL_PATH) does not exist."
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
        APNS+=("${2}")
        shift
        ;;
    --sst)
        SSTS+=("${2}")
        shift
        ;;
    --sd)
        SDS+=("${2}")
        shift
        ;;
    --ipv4)
        IPV4S+=("${2}")
        shift
        ;;
    --ipv6)
        IPV6="${2}"
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
IPV6="${IPV6:-$DEFAULT_IPV6}"

if [ ${#APNS[@]} -eq 0 ]; then
    APNS=("$DEFAULT_APN")
    if [ -n "$DEFAULT_IPV4" ]; then
        IPV4S=("$DEFAULT_IPV4")
    fi
fi
if [ ${#SSTS[@]} -eq 0 ]; then
    if [ -n "$DEFAULT_SST" ]; then
        SSTS=("$DEFAULT_SST")
    fi
fi
if [ ${#SDS[@]} -eq 0 ]; then
    if [ -n "$DEFAULT_SD" ]; then
        SDS=("$DEFAULT_SD")
    fi
fi

# Parse and validate SST/SD values
parse_sst_sd() {
    local RAW_SST="$1"
    local RAW_SD="$2"
    local RESULTING_SST=""
    local RESULTING_SD=""

    if [[ -n "$RAW_SST" && -n "$RAW_SD" ]]; then
        if [[ "$RAW_SST" =~ ^0[xX][0-9A-Fa-f]{1,2}$ ]]; then
            RESULTING_SST="$((16#${RAW_SST:2}))" # Remove 0x
        elif [[ "$RAW_SST" =~ [A-Fa-f] ]]; then
            SST_HEX="${RAW_SST^^}" # Uppercase
            if [[ ! "$SST_HEX" =~ ^[0-9A-F]{1,2}$ ]]; then
                echo "Invalid --sst '$RAW_SST'"
                exit 1
            fi
            RESULTING_SST="$((16#$SST_HEX))" # Hex to decimal
        elif [[ "$RAW_SST" =~ ^[0-9]{1,3}$ ]]; then
            RESULTING_SST="$RAW_SST"
        else
            echo "Invalid --sst '$RAW_SST'"
            exit 1
        fi

        if ((RESULTING_SST < 0 || RESULTING_SST > 255)); then
            echo "Invalid --sst '$RAW_SST'"
            exit 1
        fi

        SD_HEX="${RAW_SD#0x}"
        SD_HEX="${SD_HEX#0X}"
        SD_HEX="${SD_HEX^^}"
        if [[ ! "$SD_HEX" =~ ^[0-9A-F]{1,6}$ ]]; then
            echo "Invalid --sd '$RAW_SD'"
            exit 1
        fi
        RESULTING_SD="$(printf "%06X" "$((16#$SD_HEX))")" # Hex to decimal
    fi
    echo "$RESULTING_SST"
    echo "$RESULTING_SD"
}

# Check if the subscriber already exists
if $DBCTL_PATH showpretty | grep -q "imsi: '$IMSI'"; then
    echo "Subscriber with IMSI $IMSI already exists in the database."
    exit 0
fi

# Parse the initial SST/SD
OUTPUT=$(parse_sst_sd "${SSTS[0]}" "${SDS[0]}")
SST_DEC=$(echo "$OUTPUT" | sed -n '1p')
SD_HEX=$(echo "$OUTPUT" | sed -n '2p')

# Command to add subscriber using the open5gs-dbctl tool
if [[ -n "$SST_DEC" && -n "$SD_HEX" ]]; then
    CMD="$DBCTL_PATH add_ue_with_slice $IMSI $KEY $OPC ${APNS[0]} $SST_DEC $SD_HEX"
else
    CMD="$DBCTL_PATH add_ue_with_apn $IMSI $KEY $OPC ${APNS[0]}"
fi

echo "Running command: $CMD"
$CMD

# Support for IPv4 and IPv6
if [[ -n "${IPV4S[0]}" ]]; then
    echo "Assigning static IPv4 ${IPV4S[0]} to subscriber $IMSI"
    $DBCTL_PATH static_ip $IMSI "${IPV4S[0]}"
fi
if [[ -n "$IPV6" ]]; then
    echo "Assigning static IPv6 $IPV6 to subscriber $IMSI"
    $DBCTL_PATH static_ip6 $IMSI $IPV6
fi
TYPE=""
if [[ -n "${IPV4S[0]}" && -n "$IPV6" ]]; then # IPv4v6
    TYPE="3"
elif [[ -n "${IPV4S[0]}" ]]; then # IPv4
    TYPE="1"
elif [[ -n "$IPV6" ]]; then # IPv6
    TYPE="2"
fi
if [[ -n "$TYPE" ]]; then
    echo "Assigning PDN-Type $TYPE to subscriber $IMSI"
    $DBCTL_PATH type $IMSI $TYPE
fi

ACTIVE_SST="${SSTS[0]}"
ACTIVE_SD="${SDS[0]}"
SLICE_INDEX=0
COUNTER=0

APN_LENGTH=${#APNS[@]}
if [ ${#SSTS[@]} -gt $APN_LENGTH ]; then
    APN_LENGTH=${#SSTS[@]}
fi

for ((i = 1; i < $APN_LENGTH; i++)); do
    CURRENT_APN="${APNS[$i]:-${APNS[0]}}"
    CURRENT_SST="${SSTS[$i]}"
    CURRENT_SD="${SDS[$i]}"
    CURRENT_IPV4="${IPV4S[$i]}"

    if [[ -n "$CURRENT_SST" && -n "$CURRENT_SD" && ("$CURRENT_SST" != "$ACTIVE_SST" || "$CURRENT_SD" != "$ACTIVE_SD") ]]; then
        OUTPUT=$(parse_sst_sd "$CURRENT_SST" "$CURRENT_SD")
        PARSED_SST=$(echo "$OUTPUT" | sed -n '1p')
        PARSED_SD=$(echo "$OUTPUT" | sed -n '2p')
        echo "Adding slice (index $i) SST: $PARSED_SST, SD: $PARSED_SD for subscriber $IMSI"
        $DBCTL_PATH update_slice "$IMSI" "$CURRENT_APN" "$PARSED_SST" "$PARSED_SD"

        ACTIVE_SST="$CURRENT_SST"
        ACTIVE_SD="$CURRENT_SD"
        SLICE_INDEX=$((SLICE_INDEX + 1))
        COUNTER=0

        if [[ -n "$CURRENT_IPV4" ]]; then
            echo "Assigning static IPv4 $CURRENT_IPV4 to new slice $CURRENT_SD on subscriber $IMSI"
            mongosh mongodb://localhost/open5gs --quiet --eval "
db.subscribers.updateOne(
  { \"imsi\": \"$IMSI\", \"slice.sd\": \"$PARSED_SD\" },
  {
    \$set: {
      \"slice.$SLICE_INDEX.session.$COUNTER.ue\": { \"ipv4\": \"$CURRENT_IPV4\" },
      \"slice.$SLICE_INDEX.session.$COUNTER.type\": NumberInt(1)
    }
  }
)"
        fi
    else
        # Add to existing slice
        COUNTER=$((COUNTER + 1))
        echo "Assigning secondary APN $CURRENT_APN (session $COUNTER) for subscriber $IMSI"
        $DBCTL_PATH update_apn "$IMSI" "$CURRENT_APN" "$SLICE_INDEX"
        if [[ -n "$CURRENT_IPV4" ]]; then
            echo "Assigning static IPv4 $CURRENT_IPV4 to session $COUNTER on subscriber $IMSI"
            mongosh mongodb://localhost/open5gs --quiet --eval "
db.subscribers.updateOne(
  { \"imsi\": \"$IMSI\" },
  {
    \$set: {
      \"slice.$SLICE_INDEX.session.$COUNTER.ue\": { \"ipv4\": \"$CURRENT_IPV4\" },
      \"slice.$SLICE_INDEX.session.$COUNTER.type\": NumberInt(1)
    }
  }
)"
        fi
    fi
done

# Check exit status of the command
if [ $? -eq 0 ]; then
    echo "Subscriber successfully added to the database."
    $DBCTL_PATH showpretty
else
    echo "Failed to add subscriber to the database."
fi

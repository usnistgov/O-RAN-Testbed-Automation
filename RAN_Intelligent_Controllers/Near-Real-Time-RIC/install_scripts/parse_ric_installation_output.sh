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

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"

# Paths to the log files
mkdir -p logs
RIC_INSTALLATION_STDOUT="logs/ric_installation_stdout.txt"
RIC_INSTALLATION_LOG_JSON="logs/ric_installation_stdout_parsed.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
    sudo env $APTVARS apt-get install -y jq
fi

# Initialize the JSON log file if it doesn't exist
if [ ! -f "$RIC_INSTALLATION_LOG_JSON" ]; then
    echo "{}" >"$RIC_INSTALLATION_LOG_JSON"
fi

# Use associative arrays to store statuses
declare -A APP_STATUSES
APP_STATUSES=()

# Parse the output file and extract statuses
while read -r LINE; do
    if [[ $LINE == NAME:* ]]; then
        APP_NAME="${LINE#NAME: }"
        APP_NAME=$(echo "$APP_NAME" | tr -d ',') # Clean up the app name
    elif [[ $LINE == STATUS:* ]]; then
        STATUS="${LINE#STATUS: }"
        STATUS=$(echo "$STATUS" | tr -d ',') # Clean up the status
        APP_STATUSES["$APP_NAME"]="$STATUS"
    elif [[ $LINE == Error:* ]]; then
        # Extract a more specific error name or description
        ERROR_DESCRIPTION=$(echo "$LINE" | sed -E 's/Error: INSTALLATION FAILED: (.+)/\1/')
        ERROR_DESCRIPTION=$(echo "$ERROR_DESCRIPTION" | tr -d '\"') # Remove quotes to clean up the message
        APP_NAME="error_$ERROR_DESCRIPTION"
        STATUS="failed"
        APP_STATUSES["$APP_NAME"]="$STATUS"
    fi
done <"$RIC_INSTALLATION_STDOUT"

# Read existing JSON data
if [ -s "$RIC_INSTALLATION_LOG_JSON" ]; then
    JSON_DATA=$(cat "$RIC_INSTALLATION_LOG_JSON")
else
    JSON_DATA="{}"
fi

# Update JSON data with latest statuses
for APP in "${!APP_STATUSES[@]}"; do
    NEW_STATUS="${APP_STATUSES[$APP]}"
    # Check existing status, and only update if it is not 'deployed'
    CURRENT_STATUS=$(echo "$JSON_DATA" | jq -r --arg app "$APP" '.[$app]')
    if [[ $CURRENT_STATUS != "deployed" ]]; then
        JSON_DATA=$(echo "$JSON_DATA" | jq --arg app "$APP" --arg status "$NEW_STATUS" '.[$app] = $status')
    fi
done

# Write updated JSON data to file
echo "$JSON_DATA" >"$RIC_INSTALLATION_LOG_JSON"

echo "$JSON_DATA" | jq

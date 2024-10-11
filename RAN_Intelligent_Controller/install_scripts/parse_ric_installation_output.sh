#!/bin/bash
echo "# Script: $(realpath $0)..."

# Paths to the log files
mkdir -p logs
RIC_INSTALLATION_STDOUT="logs/ric_installation_stdout.txt"
RIC_INSTALLATION_LOG_JSON="logs/ric_installation_stdout_parsed.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    sudo apt-get install -y jq
fi

# Initialize the JSON log file if it doesn't exist
if [ ! -f "$RIC_INSTALLATION_LOG_JSON" ]; then
    echo "{}" > "$RIC_INSTALLATION_LOG_JSON"
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
done < "$RIC_INSTALLATION_STDOUT"

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
echo "$JSON_DATA" > "$RIC_INSTALLATION_LOG_JSON"

echo "$JSON_DATA" | jq
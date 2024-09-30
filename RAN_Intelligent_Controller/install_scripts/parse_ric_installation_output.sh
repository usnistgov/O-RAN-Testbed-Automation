#!/bin/bash

# Paths to the log files
RIC_INSTALLATION_STDOUT="logs/ric_installation_stdout.txt"
RIC_INSTALLATION_LOG_JSON="logs/ric_installation_stdout_parsed.json"
mkdir -p ../../logs

if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    sudo apt-get install -y jq
fi

# Initialize the JSON log file if it doesn't exist
if [ ! -f "$RIC_INSTALLATION_LOG_JSON" ]; then
    echo "{}" > "$RIC_INSTALLATION_LOG_JSON"
fi

# Use associative arrays to store statuses
declare -A app_statuses

# Parse the output file and extract statuses
while read -r line; do
    if [[ $line == NAME:* ]]; then
        app_name="${line#NAME: }"
        app_name=$(echo "$app_name" | tr -d ',') # Clean up the app name
    elif [[ $line == STATUS:* ]]; then
        status="${line#STATUS: }"
        status=$(echo "$status" | tr -d ',') # Clean up the status
        app_statuses["$app_name"]="$status"
    elif [[ $line == Error:* ]]; then
        # Extract a more specific error name or description
        error_description=$(echo "$line" | sed -E 's/Error: INSTALLATION FAILED: (.+)/\1/')
        error_description=$(echo "$error_description" | tr -d '\"') # Remove quotes to clean up the message
        app_name="error_$error_description"
        status="failed"
        app_statuses["$app_name"]="$status"
    fi
done < "$RIC_INSTALLATION_STDOUT"


# Read existing JSON data
if [ -s "$RIC_INSTALLATION_LOG_JSON" ]; then
    JSON_DATA=$(cat "$RIC_INSTALLATION_LOG_JSON")
else
    JSON_DATA="{}"
fi

# Update JSON data with latest statuses
for app in "${!app_statuses[@]}"; do
    new_status="${app_statuses[$app]}"
    # Check existing status, and only update if it is not 'deployed'
    current_status=$(echo "$JSON_DATA" | jq -r --arg app "$app" '.[$app]')
    if [[ $current_status != "deployed" ]]; then
        JSON_DATA=$(echo "$JSON_DATA" | jq --arg app "$app" --arg status "$new_status" '.[$app] = $status')
    fi
done

# Write updated JSON data to file
echo "$JSON_DATA" > "$RIC_INSTALLATION_LOG_JSON"

echo "$JSON_DATA"
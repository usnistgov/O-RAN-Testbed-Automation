#!/bin/bash

# Function to stop service
stop_service() {
    local app_name="open5gs-$1"
    if pgrep -x "$app_name" > /dev/null; then
        echo "Stopping $app_name..."
        sudo pkill -9 -x "$app_name"
    else
        echo "Stopping $app_name..."
        sudo systemctl stop "$app_name.service"
    fi
}

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

# Check if sudo is needed and prompt if it is not already running as root
if [[ $(id -u) -ne 0 ]]; then
    echo "Some operations require root privileges..."
    # Try to elevate privileges
    sudo echo "Privileges elevated successfully."
fi

# Iterate through each application and stop if running
for app in "${apps[@]}"; do
    stop_service "$app"
done

./is_running.sh

#!/bin/bash

# Function to stop service
stop_service() {
    local app_name="open5gs-$1"
    if pgrep -x "$app_name" > /dev/null; then
        echo "Stopping $app_name..."
        sudo pkill -9 -x "$app_name"
    fi
}

# Array of applications
# Previous Open5GS components:
#apps=("nrfd" "scpd" "amfd" "smfd" "upfd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "sgwcd" "sgwud" "hssd" "pcrfd")

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
#apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")
# Removing SEPPD and WEBUI
apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd")

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

#echo lab | sudo -S pkill -f -9 open5gs

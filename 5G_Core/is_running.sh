#!/bin/bash

check_service() {
    local app_name="open5gs-$1"
    if pgrep -x "$app_name" > /dev/null; then
        echo "$1: RUNNING"
    else
        echo "$1: NOT RUNNING"
    fi
}

# Array of applications
# Previous Open5GS components:
#apps=("nrfd" "scpd" "amfd" "smfd" "upfd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "sgwcd" "sgwud" "hssd" "pcrfd")

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
#apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")
# Removing SEPPD and WEBUI
apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd")

for app in "${apps[@]}"; do
    check_service "$app"
done

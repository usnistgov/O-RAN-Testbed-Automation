#!/bin/bash

check_service() {
    local app_name="open5gs-$1"
    local service_name="$1"
    if pgrep -x "$app_name" > /dev/null; then
        echo "$service_name: RUNNING"
    else
        if systemctl is-active --quiet "$app_name"; then
            echo "$service_name: RUNNING"
        else
            echo "$service_name: NOT RUNNING"
        fi
    fi
}

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

for app in "${apps[@]}"; do
    check_service "$app"
done

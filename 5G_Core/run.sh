#!/bin/bash

if [ ! -f "configs/amf.yaml" ] || [ ! -f "configs/mme.yaml" ]; then
    echo "Configurations were not found for Open5GS. Please run ./generate_configurations.sh first."
    exit 1
fi

sudo ./install_scripts/network_config.sh

run_in_background() {
    local app_name="open5gs-$1"
    if pgrep -x "$app_name" > /dev/null; then
        echo "Already running $app_name."
    else
        echo "Starting $app_name in background..."
        ./open5gs/install/bin/$app_name > /dev/null 2>&1 &
    fi
}

run_in_terminal() {
    local app_name="open5gs-$1"
    if pgrep -x "$app_name" > /dev/null; then
        echo "Already running $app_name."
    else
        echo "Starting $app_name in GNOME Terminal..."
        gnome-terminal -t "$app_name Node" -- /bin/sh -c "./open5gs/install/bin/$app_name"
    fi
}

# Array of applications
# Previous Open5GS components:
#apps=("nrfd" "scpd" "amfd" "smfd" "upfd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "sgwcd" "sgwud" "hssd" "pcrfd")

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
#apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")
# Removing SEPPD and WEBUI
apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd")

if [[ $1 == "show" ]]; then
    # Run in separate terminal windows
    for app in "${apps[@]}"; do
        run_in_terminal "$app"
    done
else
    # Run in background
    for app in "${apps[@]}"; do
        run_in_background "$app"
    done
fi

./is_running.sh
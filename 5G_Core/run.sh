#!/bin/bash

if [ ! -f "configs/amf.yaml" ] || [ ! -f "configs/mme.yaml" ]; then
    echo "Configurations were not found for Open5GS. Please run ./generate_configurations.sh first."
    exit 1
fi

sudo ./install_scripts/network_config.sh

run_in_background() {
    local app_name="open5gs-$1"
    local config_file=""
    if [ -f "configs/${1%?}.yaml" ]; then
        config_file="-c $(pwd)/configs/${1%?}.yaml"
    fi
    if pgrep -x "$app_name" > /dev/null; then
        echo "Already running $app_name."
    else
        echo "Starting $app_name in background..."
        ./open5gs/install/bin/$app_name $config_file > /dev/null 2>&1 &
    fi
}

run_in_terminal() {
    local app_name="open5gs-$1"
    local config_file=""
    if [ -f "configs/${1%?}.yaml" ]; then
        config_file="-c $(pwd)/configs/${1%?}.yaml"
    fi
    if pgrep -x "$app_name" > /dev/null; then
        echo "Already running $app_name."
    else
        echo "Starting $app_name in GNOME Terminal..."
        gnome-terminal -t "$app_name Node" -- /bin/sh -c "./open5gs/install/bin/$app_name $config_file"
    fi
}

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
apps=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

# Check if the last application is 'webui'
if [ "${apps[-1]}" == "webui" ]; then
    unset apps[-1]
    echo "Starting webui service..."
    sudo systemctl start open5gs-webui
fi

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

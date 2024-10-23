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

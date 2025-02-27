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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ ! -f "configs/amf.yaml" ] || [ ! -f "configs/mme.yaml" ]; then
    echo "Configurations were not found for Open5GS. Please run ./generate_configurations.sh first."
    exit 1
fi
mkdir -p logs

sudo ./install_scripts/network_config.sh

run_in_background() {
    local APP_NAME="open5gs-$1"
    if [ "$1" == "seppd" ]; then
        local SEPP1_RUNNING=$(pgrep -f "$APP_NAME.*sepp1.yaml")
        local SEPP2_RUNNING=$(pgrep -f "$APP_NAME.*sepp2.yaml")
        if [ -z "$SEPP1_RUNNING" ]; then
            CONFIG_FILE_1="$SCRIPT_DIR/configs/sepp1.yaml"
            if [ ! -f "$CONFIG_FILE_1" ]; then
                echo "Configuration file not found: $CONFIG_FILE_1"
                exit 1
            fi
            echo "Starting $APP_NAME 1 in background..."
            ./open5gs/install/bin/$APP_NAME -c $CONFIG_FILE_1 >/dev/null 2>&1 &
            #./open5gs/install/bin/$APP_NAME -c $CONFIG_FILE_1 >logs/${1}_1_stdout.txt 2>&1 &
        else
            echo "Already running $APP_NAME 1."
        fi
        if [ -z "$SEPP2_RUNNING" ]; then
            CONFIG_FILE_2="$SCRIPT_DIR/configs/sepp2.yaml"
            if [ ! -f "$CONFIG_FILE_2" ]; then
                echo "Configuration file not found: $CONFIG_FILE_2"
                exit 1
            fi
            echo "Starting $APP_NAME 2 in background..."
            ./open5gs/install/bin/$APP_NAME -c $CONFIG_FILE_2 >/dev/null 2>&1 &
            #./open5gs/install/bin/$APP_NAME -c $CONFIG_FILE_2 >logs/${1}_2_stdout.txt 2>&1 &
        else
            echo "Already running $APP_NAME 2."
        fi
        return
    fi
    if pgrep -x "$APP_NAME" >/dev/null; then
        echo "Already running $APP_NAME."
        return
    fi
    local CONFIG_FILE="$SCRIPT_DIR/configs/${1%?}.yaml"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Remove the log file if it exists before starting the application
    LOG_PATH=$(yq eval '.logger.file.path' "$CONFIG_FILE")
    rm -f "$LOG_PATH"

    echo "Starting $APP_NAME in background..."
    ./open5gs/install/bin/$APP_NAME -c "$CONFIG_FILE" >/dev/null 2>&1 &
    #./open5gs/install/bin/$APP_NAME -c "$CONFIG_FILE" >logs/${1}_stdout.txt 2>&1 &
}

run_in_terminal() {
    local APP_NAME="open5gs-$1"
    if [ "$1" == "seppd" ]; then
        local SEPP1_RUNNING=$(pgrep -f "$APP_NAME.*sepp1.yaml")
        local SEPP2_RUNNING=$(pgrep -f "$APP_NAME.*sepp2.yaml")
        if [ -z "$SEPP1_RUNNING" ]; then
            CONFIG_FILE_1="$SCRIPT_DIR/configs/sepp1.yaml"
            if [ ! -f "$CONFIG_FILE_1" ]; then
                echo "Configuration file not found: $CONFIG_FILE_1"
                exit 1
            fi
            echo "Starting $APP_NAME 1 in GNOME Terminal..."
            gnome-terminal -t "$APP_NAME 1 Node" -- /bin/sh -c "./open5gs/install/bin/$APP_NAME -c $CONFIG_FILE_1"
        else
            echo "Already running $APP_NAME 1."
        fi
        if [ -z "$SEPP2_RUNNING" ]; then
            CONFIG_FILE_2="$SCRIPT_DIR/configs/sepp2.yaml"
            if [ ! -f "$CONFIG_FILE_2" ]; then
                echo "Configuration file not found: $CONFIG_FILE_2"
                exit 1
            fi
            echo "Starting $APP_NAME 2 in GNOME Terminal..."
            gnome-terminal -t "$APP_NAME 2 Node" -- /bin/sh -c "./open5gs/install/bin/$APP_NAME -c $CONFIG_FILE_2"
        else
            echo "Already running $APP_NAME 2."
        fi
        return
    fi
    if pgrep -x "$APP_NAME" >/dev/null; then
        echo "Already running $APP_NAME."
        return
    fi
    local CONFIG_FILE="$SCRIPT_DIR/configs/${1%?}.yaml"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Remove the log file if it exists before starting the application
    LOG_PATH=$(yq eval '.logger.file.path' "$CONFIG_FILE")
    rm -f "$LOG_PATH"

    echo "Starting $APP_NAME in GNOME Terminal..."
    gnome-terminal -t "$APP_NAME Node" -- /bin/sh -c "./open5gs/install/bin/$APP_NAME -c $CONFIG_FILE"
}

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
APPS=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

# Check if the last application is 'webui'
if [ "${APPS[-1]}" == "webui" ]; then
    unset APPS[-1]
    echo "Starting webui service..."
    sudo systemctl start open5gs-webui
fi

if [[ $1 == "show" ]]; then
    # Run in separate terminal windows
    for APP in "${APPS[@]}"; do
        run_in_terminal "$APP"
    done
else
    # Run in background
    for APP in "${APPS[@]}"; do
        run_in_background "$APP"
    done
fi

./is_running.sh

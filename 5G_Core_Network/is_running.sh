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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Ensure that the correct script is used
if [ -f "options.yaml" ]; then
    CORE_TO_USE=$(yq eval '.core_to_use' options.yaml)
fi
if [[ "$CORE_TO_USE" == "null" || -z "$CORE_TO_USE" ]]; then
    CORE_TO_USE="open5gs" # Default
fi
if [[ "$CORE_TO_USE" != "open5gs" && -z "$INTERMEDIATE_CHECK" ]]; then
    cd Additional_Cores_5GDeploy || {
        echo "Directory 'Additional_Cores_5GDeploy' not found. Please ensure that it exists in the script's directory."
        exit 1
    }
    ./is_running.sh
    cd "$SCRIPT_DIR"
    export INTERMEDIATE_CHECK=1
    if ! ./is_running.sh | grep -q ": RUNNING"; then
        unset INTERMEDIATE_CHECK
        exit 0
    fi
    unset INTERMEDIATE_CHECK
fi

check_service() {
    local APP="$1"
    local DISPLAY_NAME="$2"
    local CONFIG_FILE="$3"
    local SEARCH_PATTERN="open5gs-$APP"

    if pgrep -af "$SEARCH_PATTERN" | grep -F -- "$CONFIG_FILE" >/dev/null; then
        echo "$DISPLAY_NAME: RUNNING"
    elif pgrep -af "$SEARCH_PATTERN" >/dev/null; then
        echo "$DISPLAY_NAME: RUNNING"
    else
        echo "$DISPLAY_NAME: NOT_RUNNING"
    fi
}

check_webui() {
    local WEBUI_SERVER="$SCRIPT_DIR/open5gs/webui/server/index.js"
    if pgrep -af "node" | grep -F -- "$WEBUI_SERVER" >/dev/null; then
        echo "webui: RUNNING"
    elif pgrep -af "node" | grep -F -- "/open5gs/webui/server/index.js" >/dev/null; then
        echo "webui: RUNNING"
    elif pgrep -af "open5gs-webui" >/dev/null; then
        echo "webui: RUNNING"
    elif pgrep -af "node server/index.js" >/dev/null; then
        echo "webui: RUNNING"
    elif command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet open5gs-webui 2>/dev/null; then
        echo "webui: RUNNING"
    # elif command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)9999$'; then
    #     echo "webui: RUNNING"
    else
        echo "webui: NOT_RUNNING"
    fi
}

INCLUDE_SEPP=$(yq eval '.include_sepp' options.yaml)

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
APPS=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

for APP in "${APPS[@]}"; do
    if [ "$APP" == "seppd" ]; then
        if [ "$INCLUDE_SEPP" == true ]; then
            check_service "seppd" "seppd_1" "$SCRIPT_DIR/configs/sepp1.yaml"
            check_service "seppd" "seppd_2" "$SCRIPT_DIR/configs/sepp2.yaml"
        fi
    elif [ "$APP" == "webui" ]; then
        check_webui
    else
        check_service "$APP" "$APP" "$SCRIPT_DIR/configs/${APP%?}.yaml"
    fi
done

# # Check if 5gdeploy is running
# STATUS_5GDEPLOY=$(./Additional_Cores_5GDeploy/is_running.sh 2>/dev/null)
# if echo "$STATUS_5GDEPLOY" | grep -q ": RUNNING"; then
#     ./Additional_Cores_5GDeploy/is_running.sh
# fi

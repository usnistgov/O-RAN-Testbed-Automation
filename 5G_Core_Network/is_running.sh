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

check_service() {
    local SEARCH_PATTERN="open5gs-$1"
    local DISPLAY_NAME="$2"
    if pgrep -f "$SEARCH_PATTERN" >/dev/null; then
        echo "$DISPLAY_NAME: RUNNING"
    else
        if systemctl is-active --quiet "$SEARCH_PATTERN"; then
            echo "$DISPLAY_NAME: RUNNING"
        else
            echo "$DISPLAY_NAME: NOT_RUNNING"
        fi
    fi
}

INCLUDE_SEPP=$(yq eval '.include_sepp' options.yaml)

# Latest components (see https://open5gs.org/open5gs/docs/guide/01-quickstart/#:~:text=Starting%20and%20Stopping%20Open5GS)
APPS=("mmed" "sgwcd" "smfd" "amfd" "sgwud" "upfd" "hssd" "pcrfd" "nrfd" "scpd" "seppd" "ausfd" "udmd" "pcfd" "nssfd" "bsfd" "udrd" "webui")

for APP in "${APPS[@]}"; do
    if [ "$APP" == "seppd" ]; then
        if [ "$INCLUDE_SEPP" == true ]; then
            check_service "seppd.*sepp1.yaml" "seppd_1"
            check_service "seppd.*sepp2.yaml" "seppd_2"
        fi
    else
        check_service "$APP" "$APP"
    fi
done

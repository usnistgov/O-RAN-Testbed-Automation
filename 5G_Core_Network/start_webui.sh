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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

NO_BROWSER=false
for ARG in "$@"; do
    if [[ "$ARG" == "no-browser" ]]; then
        NO_BROWSER=true
        break
    fi
done

USE_SYSTEMCTL=$(yq eval '.use_systemctl' options.yaml)
if [[ "$USE_SYSTEMCTL" == "null" || -z "$USE_SYSTEMCTL" ]]; then
    USE_SYSTEMCTL="true" # Default
fi

# Ensure that MongoDB is running
sudo ./install_scripts/start_mongodb.sh

if [[ "$USE_SYSTEMCTL" == "true" ]]; then
    if ! systemctl is-active --quiet "open5gs-webui"; then
        echo "Starting webui service..."
        sudo systemctl start open5gs-webui
    fi
else
    # Check if the WebUI server is already running by looking for the Node.js process in the correct directory
    if ! pgrep -f "open5gs-webui" >/dev/null; then
        echo "Starting webui process..."
        cd open5gs/webui
        npm install
        # nohup node --title="open5gs-webui" server/index.js >logs/webui_stdout.txt 2>&1 &
        nohup node --title="open5gs-webui" server/index.js >/dev/null 2>&1 &
        cd "$SCRIPT_DIR"
    fi
fi

WEBUI_PORT=9999

if [[ "$NO_BROWSER" == false ]]; then
    if command -v xdg-open &>/dev/null; then
        echo "Opening the WebUI in the default web browser at URL http://localhost:$WEBUI_PORT"
        xdg-open "http://localhost:$WEBUI_PORT" >/dev/null 2>&1 &
        sleep 3
    else
        echo "No default browser detected. Visit http://localhost:$WEBUI_PORT to access the WebUI."
    fi
    echo
    echo "The login credentials are set to the following."
    echo "    - U: \"admin\""
    echo "    - P: \"1423\""
fi

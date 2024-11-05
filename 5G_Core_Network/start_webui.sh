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

if ! systemctl is-active --quiet "open5gs-webui"; then
    echo "Starting webui service..."
    sudo systemctl start open5gs-webui
fi

WEBUI_PORT=3000
if ! curl -s localhost:$WEBUI_PORT >/dev/null; then
    WEBUI_PORT=9999
fi

if command -v google-chrome &>/dev/null; then
    echo "Opening the WebUI in Google Chrome..."
    google-chrome "http://localhost:$WEBUI_PORT" >/dev/null 2>&1 &
    sleep 3
elif command -v firefox &>/dev/null; then
    echo "Opening the WebUI in Firefox..."
    firefox "http://localhost:$WEBUI_PORT" >/dev/null 2>&1 &
    sleep 3
else
    echo "No supported browser detected. Visit http://localhost:$WEBUI_PORT to access the WebUI."
fi

echo
echo "The login credentials are set to the following."
echo "    - U: \"admin\""
echo "    - P: \"1423\""
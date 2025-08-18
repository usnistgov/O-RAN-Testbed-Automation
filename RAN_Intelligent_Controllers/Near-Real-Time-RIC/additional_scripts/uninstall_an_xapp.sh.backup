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

echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

CHARTS_OUTPUT=$(dms_cli get_charts_list)

echo
kubectl get pods -n ricxapp || true
echo

echo "List of available xApps to uninstall:"

# Parse the list of installed xApps and versions into an array
XAPP_LIST=$(echo "$CHARTS_OUTPUT" | jq -r '. | to_entries[] | "\(.key) \(.value[].version)"')
IFS=$'\n' XAPP_NAMES=($XAPP_LIST) # Convert the string to an array
unset IFS

# Display the list of installed xApps
COUNTER=1
for XAPP in "${XAPP_NAMES[@]}"; do
    echo -e "    $COUNTER. \t$XAPP"
    let COUNTER++
done

echo -n "Please select an xApp to uninstall (between 1 and ${#XAPP_NAMES[@]}): "
read USER_CHOICE

# Validate user input and uninstall the selected xApp
if [[ $USER_CHOICE =~ ^[0-9]+$ ]] && [ $USER_CHOICE -ge 1 ] && [ $USER_CHOICE -le ${#XAPP_NAMES[@]} ]; then
    SELECTED_XAPP=$(echo "${XAPP_NAMES[$USER_CHOICE - 1]}" | awk '{print $1}')
    SELECTED_VERSION=$(echo "${XAPP_NAMES[$USER_CHOICE - 1]}" | awk '{print $2}')

    echo "Uninstalling $SELECTED_XAPP version $SELECTED_VERSION..."
    UNINSTALL_OUTPUT=$(dms_cli uninstall "$SELECTED_XAPP" ricxapp --version "$SELECTED_VERSION" 2>&1) || true

    if echo "$UNINSTALL_OUTPUT" | grep -q 'release: not found\|No XAPP to uninstall'; then
        echo "Application $SELECTED_XAPP not found or already uninstalled."
    else
        echo "$UNINSTALL_OUTPUT"
        kubectl get pods -n ricxapp || true
        echo
        echo "Successfully uninstalled $SELECTED_XAPP version $SELECTED_VERSION."
    fi
else
    echo "Invalid input. Exiting."
fi

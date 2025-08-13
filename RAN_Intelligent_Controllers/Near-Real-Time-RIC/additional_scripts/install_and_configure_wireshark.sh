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

# Install Wireshark if not already installed
if ! dpkg -s "wireshark" &>/dev/null; then
    echo "Installing Wireshark..."
    sudo add-apt-repository ppa:wireshark-dev/stable -y
    sudo apt-get update
    APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
    sudo $APTVARS apt-get install -y wireshark
fi

# Add user to the Wireshark group if not already a member
if ! groups $USER | grep -q '\bwireshark\b'; then
    echo "Adding $USER to the Wireshark group..."
    sudo usermod -a -G wireshark $USER || true
fi

# Set permissions for dumpcap
if [[ $(getcap /usr/bin/dumpcap) != "/usr/bin/dumpcap cap_net_admin,cap_net_raw=eip" ]]; then
    echo "Setting permissions for dumpcap..."
    sudo chgrp wireshark /usr/bin/dumpcap || true
    sudo chmod 750 /usr/bin/dumpcap || true
    sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap || true
fi

PREFS_PATH="$HOME/.config/wireshark/preferences"
DLT_FILE="$HOME/.config/wireshark/user_dlts"
HEURISTIC_PROTOS_PATH="$HOME/.config/wireshark/heuristic_protos"

if [ ! -f "$PREFS_PATH" ]; then
    echo "Wireshark preferences file not found. Creating one at $PREFS_PATH."
    mkdir -p "$(dirname "$PREFS_PATH")"
    touch "$PREFS_PATH"
fi

if [ ! -f "$DLT_FILE" ]; then
    echo "Wireshark user_dlts file not found. Creating one at $DLT_FILE."
    mkdir -p "$(dirname "$DLT_FILE")"
    touch "$DLT_FILE"
fi

if [ ! -f "$HEURISTIC_PROTOS_PATH" ]; then
    echo "Wireshark euristic protocols file not found. Creating one at $HEURISTIC_PROTOS_PATH."
    mkdir -p "$(dirname "$HEURISTIC_PROTOS_PATH")"
    touch "$HEURISTIC_PROTOS_PATH"
fi

# DLT to User ID mappings
declare -A DLT_TO_USER_ID=(
    [147]=0
    [148]=1
    [149]=2
    [150]=3
    [151]=4
    [152]=5
    [153]=6
    [154]=7
    [155]=8
    [156]=9
    [157]=10
    [158]=11
    [159]=12
    [160]=13
    [161]=14
    [162]=15
)

# Function to update DLT_USER settings in the user_dlts file
function update_dlt_user() {
    local DLT=$1
    local PROTOCOL=$2
    local USER_ID=${DLT_TO_USER_ID[$DLT]}
    local ENTRY="\"User $USER_ID (DLT=$DLT)\",\"$PROTOCOL\",\"0\",\"\",\"0\",\"\""

    # Check if the entry already exists in the file
    if ! grep -q "\"User $USER_ID (DLT=$DLT)\"" "$DLT_FILE"; then
        echo "Adding new DLT entry for $PROTOCOL..."
        echo $ENTRY >>"$DLT_FILE"
    else
        echo "Entry for DLT=$DLT already exists."
    fi
}

# Function to enable a heuristic protocol
function enable_protocol() {
    local PROTOCOL=$1
    local PROTOCOL_SETTING="${PROTOCOL},1" # Format to set the protocol as enabled
    # Check if the protocol setting exists
    if grep -q "^${PROTOCOL}," "$HEURISTIC_PROTOS_PATH"; then
        # Protocol exists, update the setting
        sed -i.bak "s/^${PROTOCOL},.*/${PROTOCOL_SETTING}/" "$HEURISTIC_PROTOS_PATH"
        echo "Protocol $PROTOCOL enabled."
    else
        echo $PROTOCOL_SETTING >>"$HEURISTIC_PROTOS_PATH"
        echo "Protocol $PROTOCOL added and enabled."
    fi
}

# Function to set a preference
function set_preference() {
    local PREF_NAME="$1"
    local PREF_VALUE="$2"
    local REGEX="^#\?\s*$PREF_NAME\s*:.*"
    # Check if the preference exists (commented or not)
    if grep -Pq "$REGEX" "$PREFS_PATH"; then
        sed -i -r "s/$REGEX/$PREF_NAME: $PREF_VALUE/" "$PREFS_PATH"
        echo "Updated $PREF_NAME to $PREF_VALUE in preferences."
    else
        echo "$PREF_NAME: $PREF_VALUE" >>"$PREFS_PATH"
        echo "Added $PREF_NAME with value $PREF_VALUE to preferences."
    fi
}

echo
echo "Configuring Wireshark to handle MAC, RLC, NGAP, GTP-U, E1AP, F1AP, and E2AP packet captures..."
echo "More information about the configurations can be found at: https://docs.srsran.com/projects/project/en/latest/user_manuals/source/outputs.html#pcaps"

# Update DLT_USER settings
update_dlt_user 149 "udp"  # For MAC and RLC
update_dlt_user 152 "ngap" # For NGAP
update_dlt_user 156 "gtp"  # For GTP-U
update_dlt_user 153 "e1ap" # For E1AP
update_dlt_user 154 "f1ap" # For F1AP
update_dlt_user 155 "e2ap" # For E2AP

# Enable necessary protocols
enable_protocol "mac_nr_udp"
enable_protocol "rlc_nr_udp"

# Set protocol-specific preferences
set_preference "mac-nr.attempt_rrc_decode" "TRUE"
set_preference "mac-nr.attempt_to_dissect_srb_sdus" "TRUE"
set_preference "mac-lte.attempt_rrc_decode" "TRUE"
set_preference "mac-lte.attempt_to_dissect_crc_failures" "TRUE"
set_preference "mac-lte.attempt_to_dissect_srb_sdus" "TRUE"
set_preference "mac-lte.attempt_to_dissect_mcch" "TRUE"
set_preference "nas-5gs.null_decipher" "TRUE"
set_preference "nas-eps.dissect_plain" "TRUE"

echo "Successfully updated Wireshark preferences."

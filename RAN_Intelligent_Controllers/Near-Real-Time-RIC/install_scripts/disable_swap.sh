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

echo "# Script: $(realpath "$0")..."

SWAP_STATE_DIR="${SWAP_STATE_DIR:-/var/lib/nist-oran-testbed}"
SWAP_STATE_FILE="${SWAP_STATE_FILE:-$SWAP_STATE_DIR/swap_fstab_entries}"

# Detect if systemctl is available
USE_SYSTEMCTL=false
if command -v systemctl >/dev/null 2>&1; then
    if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        OUTPUT="$(systemctl 2>&1 || true)"
        if echo "$OUTPUT" | grep -qiE 'not supported|System has not been booted with systemd'; then
            echo "Detected systemctl is not supported. Using background processes instead."
        elif systemctl list-units >/dev/null 2>&1 || systemctl is-system-running --quiet >/dev/null 2>&1; then
            USE_SYSTEMCTL=true
        fi
    fi
fi

echo "Checking for traditional swap in /etc/fstab..."
sudo install -d -m 0755 "$SWAP_STATE_DIR"
sudo awk '$0 !~ /^[[:space:]]*#/ && $3 == "swap" { print }' /etc/fstab | sudo tee "$SWAP_STATE_FILE" >/dev/null

if [ -s "$SWAP_STATE_FILE" ]; then
    echo "Saved traditional swap entries to $SWAP_STATE_FILE."
else
    echo "No traditional swap entries to save."
    sudo rm -f "$SWAP_STATE_FILE"
fi

SWAPFILES=$(sudo awk '$0 !~ /^[[:space:]]*#/ && $3 == "swap" { print $1 }' /etc/fstab)
if [ ! -z "$SWAPFILES" ]; then
    for SWAPFILE in $SWAPFILES; do
        if [ ! -z "$SWAPFILE" ]; then
            echo "Disabling swap file $SWAPFILE"
            if [[ "$SWAPFILE" == UUID* ]]; then
                UUID=$(echo "$SWAPFILE" | cut -f2 -d'=')
                sudo swapoff -U "$UUID" || true
            else
                sudo swapoff "$SWAPFILE" || true
            fi
            sudo sed -i "\%^[[:space:]]*$SWAPFILE[[:space:]]%d" /etc/fstab
        fi
    done
else
    echo "No traditional swap entries found in /etc/fstab."
fi
# Disable zram swap
echo "Checking for zram swap devices..."
ZRAM_DEVICES=$(sudo swapon --noheadings --show=NAME 2>/dev/null | grep -E '(^|/)zram[0-9]+$' || true)
if [ ! -z "$ZRAM_DEVICES" ]; then
    for ZRAM_DEVICE in $ZRAM_DEVICES; do
        echo "Disabling zram device $ZRAM_DEVICE"
        sudo swapoff "$ZRAM_DEVICE" || true
    done
    # Disable zram services if they exist
    if [ "$USE_SYSTEMCTL" = true ]; then
        ZRAM_SERVICES=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '/zram/ { print $1 }' || true)
        for SERVICE in $ZRAM_SERVICES; do
            echo "Disabling zram service $SERVICE"
            sudo systemctl disable --now "$SERVICE" || true
        done
    fi
else
    echo "No zram devices currently active."
fi

echo "Verifying swap is disabled..."
if sudo swapon --noheadings --show=NAME 2>/dev/null | grep -q .; then
    echo "WARNING: Swap is still active."
    sudo swapon --show
else
    echo "All swap has been successfully disabled."
fi

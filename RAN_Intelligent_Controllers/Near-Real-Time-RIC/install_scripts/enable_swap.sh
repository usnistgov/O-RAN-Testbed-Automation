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

SWAPFILE="${SWAPFILE:-/swapfile}"
SWAP_SIZE="${SWAP_SIZE:-2G}"
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

# Restore swap entries saved by disable_swap.sh, if available
echo "Checking for saved swap configuration..."
if [ -s "$SWAP_STATE_FILE" ]; then
    echo "Restoring saved swap entries from $SWAP_STATE_FILE..."
    while IFS= read -r FSTAB_LINE; do
        if [ -z "$FSTAB_LINE" ]; then
            continue
        fi

        SWAP_DEVICE=$(echo "$FSTAB_LINE" | awk '{print $1}')
        if sudo awk -v dev="$SWAP_DEVICE" '$0 !~ /^[[:space:]]*#/ && $1 == dev && $3 == "swap" { found=1 } END { exit !found }' /etc/fstab; then
            echo "Swap entry already present for $SWAP_DEVICE."
        else
            echo "Restoring swap entry for $SWAP_DEVICE."
            echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
        fi
    done <"$SWAP_STATE_FILE"
else
    echo "No saved swap configuration found."
fi

# Enable traditional swap entries from /etc/fstab
echo "Checking for traditional swap in /etc/fstab..."
SWAPFILES=$(sudo awk '$0 !~ /^[[:space:]]*#/ && $3 == "swap" { print $1 }' /etc/fstab)
if [ ! -z "$SWAPFILES" ]; then
    echo "Enabling traditional swap entries from /etc/fstab..."
    sudo swapon -a || true
else
    echo "No traditional swap entries found in /etc/fstab."
fi

# Enable zram swap services, if present
echo "Checking for zram swap services..."
if [ "$USE_SYSTEMCTL" = true ]; then
    ZRAM_SERVICES=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '/zram/ { print $1 }' || true)
    if [ ! -z "$ZRAM_SERVICES" ]; then
        for SERVICE in $ZRAM_SERVICES; do
            echo "Enabling zram service $SERVICE"
            sudo systemctl enable --now "$SERVICE" || true
        done
    else
        echo "No zram services found."
    fi
else
    echo "systemctl is not available. Skipping zram service enablement."
fi

# Create a fallback swap file only if no existing swap configuration was restored
if ! sudo swapon --noheadings --show=NAME 2>/dev/null | grep -q .; then
    echo "No existing swap configuration could be enabled."
    echo "Creating traditional swap file $SWAPFILE..."

    if [[ "$SWAP_SIZE" =~ ^[0-9]+[Gg]$ ]]; then
        SWAP_SIZE_MIB=$((10#${SWAP_SIZE%[Gg]} * 1024))
    elif [[ "$SWAP_SIZE" =~ ^[0-9]+[Mm]$ ]]; then
        SWAP_SIZE_MIB=$((10#${SWAP_SIZE%[Mm]}))
    else
        echo "WARNING: Could not parse SWAP_SIZE=$SWAP_SIZE for dd fallback. Using 2048 MiB."
        SWAP_SIZE_MIB=2048
    fi

    if [ ! -f "$SWAPFILE" ]; then
        if command -v fallocate >/dev/null 2>&1; then
            if ! sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE"; then
                echo "WARNING: fallocate failed. Falling back to dd."
                sudo rm -f "$SWAPFILE"
                sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAP_SIZE_MIB" status=progress
            fi
        else
            sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAP_SIZE_MIB" status=progress
        fi
    else
        echo "Swap file $SWAPFILE already exists."
    fi

    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"

    if sudo awk -v dev="$SWAPFILE" '$0 !~ /^[[:space:]]*#/ && $1 == dev && $3 == "swap" { found=1 } END { exit !found }' /etc/fstab; then
        echo "Swap entry already present for $SWAPFILE."
    else
        echo "Adding $SWAPFILE to /etc/fstab."
        echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
    fi

    echo "Enabling swap file $SWAPFILE"
    if ! sudo swapon "$SWAPFILE"; then
        echo "WARNING: swapon failed for $SWAPFILE. Recreating swap file with dd and retrying."
        sudo swapoff "$SWAPFILE" 2>/dev/null || true
        sudo rm -f "$SWAPFILE"
        sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAP_SIZE_MIB" status=progress
        sudo chmod 600 "$SWAPFILE"
        sudo mkswap "$SWAPFILE"
        sudo swapon "$SWAPFILE"
    fi
fi

echo "Verifying swap is enabled..."
if sudo swapon --noheadings --show=NAME 2>/dev/null | grep -q .; then
    echo "Swap has been successfully enabled."
    sudo swapon --show
else
    echo "WARNING: Swap is still not active."
fi

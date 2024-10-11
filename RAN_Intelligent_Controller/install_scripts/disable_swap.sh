#!/bin/bash
echo "# Script: $(realpath $0)..."

echo "Checking for traditional swap in /etc/fstab..."
SWAPFILES=$(grep swap /etc/fstab | sed '/^[ \t]*#/ d' | sed 's/[\t ]/ /g' | tr -s " " | cut -f1 -d' ')
if [ ! -z "$SWAPFILES" ]; then
    for SWAPFILE in $SWAPFILES; do
        if [ ! -z "$SWAPFILE" ]; then
            echo "Disabling swap file $SWAPFILE"
            if [[ $SWAPFILE == UUID* ]]; then
                UUID=$(echo "$SWAPFILE" | cut -f2 -d'=')
                sudo swapoff -U "$UUID"
            else
                sudo swapoff "$SWAPFILE"
            fi
            sudo sed -i "\%$SWAPFILE%d" /etc/fstab
        fi
    done
else
    echo "No traditional swap entries found in /etc/fstab."
fi
# Disable zram swap
echo "Checking for zram swap devices..."
ZRAM_DEVICES=$(sudo swapon --show=NAME,TYPE | grep partition | grep zram | cut -d' ' -f1)
if [ ! -z "$ZRAM_DEVICES" ]; then
    for ZRAM in $ZRAM_DEVICES; do
        # Handle case where device path might already include '/dev/'
        ZRAM_DEVICE_PATH=$(echo "$ZRAM" | grep -q "^/dev/" && echo "$ZRAM" || echo "/dev/$ZRAM")
        echo "Disabling zram device $ZRAM_DEVICE_PATH"
        sudo swapoff "$ZRAM_DEVICE_PATH"
    done
    # Disable zram services if they exist
    systemctl list-units --type=service | grep zram | cut -d' ' -f1 | while read -r service; do
        echo "Disabling zram service $service"
        sudo systemctl disable --now "$service"
    done
else
    echo "No zram devices currently active."
fi

echo "Verifying swap is disabled..."
if sudo swapon --show | grep -q 'swap'; then
    echo "Warning: Swap is still active."
    sudo swapon --show
else
    echo "All swap has been successfully disabled."
fi

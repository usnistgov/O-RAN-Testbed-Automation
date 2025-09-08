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
    systemctl list-units --type=service | grep zram | cut -d' ' -f1 | while read -r SERVICE; do
        echo "Disabling zram service $SERVICE"
        sudo systemctl disable --now "$SERVICE"
    done
else
    echo "No zram devices currently active."
fi

echo "Verifying swap is disabled..."
if sudo swapon --show | grep -q 'swap'; then
    echo "WARNING: Swap is still active."
    sudo swapon --show
else
    echo "All swap has been successfully disabled."
fi

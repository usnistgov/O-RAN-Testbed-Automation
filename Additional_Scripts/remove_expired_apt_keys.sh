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

OUTPUT=$(sudo apt-get update 2>&1 | tee /dev/tty)

# Look for EXPKEYSIG errors in the output
if echo "$OUTPUT" | grep -iq "EXPKEYSIG"; then
    # Extract the key IDs
    KEYS=$(echo "$OUTPUT" | grep -io "EXPKEYSIG [0-9A-F]*" | awk '{print $2}' | sort | uniq)

    if [ -n "$KEYS" ]; then
        for KEY in $KEYS; do
            echo
            echo "Invalid key detected: $KEY"
            # Determine the keyring file to be modified
            KEYRING_PATH=""
            for FILE in /etc/apt/keyrings/*.gpg; do
                if sudo gpg --no-default-keyring --keyring "$FILE" --list-keys | grep -q "$KEY"; then
                    KEYRING_PATH="$FILE"
                    break
                fi
            done

            if [ -n "$KEYRING_PATH" -a -f "$KEYRING_PATH" ]; then
                echo "Removing key $KEY from keyring $KEYRING_PATH..."
                sudo gpg --batch --yes --no-default-keyring --keyring "$KEYRING_PATH" --delete-keys "$KEY"
            else
                echo "No keyring file found for key: $KEY"
            fi

            # Find the corresponding list file(s) and remove them
            FILES_LIST=""
            for FILE in /etc/apt/sources.list.d/*.list; do
                # Now we need to grep $KEY or grep $KEYRING_PATH exists in the file contents
                if grep -q "$KEY" "$FILE" || grep -q "$KEYRING_PATH" "$FILE"; then
                    FILES_LIST="$FILES_LIST $FILE"
                fi
            done
            for FILE in $FILES_LIST; do
                if [ -n "$FILE" ]; then
                    echo "Removing file: $FILE"
                    sudo rm "$FILE"
                fi
            done

            if [ -z "$FILES_LIST" ]; then
                echo "No corresponding .list files found to remove for key: $KEY"
            else
                echo "Successfully removed expired key $KEY and corresponding .list files."
            fi
        done
    else
        echo "No invalid keys found to remove."
    fi
else
    echo "Successfully completed apt-get update with no EXPKEYSIG errors detected."
fi

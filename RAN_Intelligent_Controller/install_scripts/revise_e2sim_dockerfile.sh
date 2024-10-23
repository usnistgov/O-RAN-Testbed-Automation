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

# Get the file path from the command line argument
FILE=$1

# Check if the file path is provided
if [[ -z "$FILE" ]]; then
    echo "Error: No file path provided."
    echo "Usage: $0 <path_to_yaml_file>"
    exit 1
fi

# Check if the file exists and is readable
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' does not exist."
    exit 1
fi

if [[ ! -r "$FILE" ]]; then
    echo "Error: File '$FILE' is not readable."
    exit 1
fi

echo "Revising $1..."

# Search for the line containing the commented CMD and modify it if found
if grep -q "#CMD sleep 100000000000" "$FILE"; then
    # The line is found; replace the line by removing the comment
    sed -i '/#CMD sleep 100000000000/c\CMD sleep 100000000000' "$FILE"
    echo "Replaced the commented command."
else
    # The line is not found; append the new command at the end of the file
    echo -e "\nCMD sleep 100000000000" >> "$FILE"
    echo "Appended the new command at the end of the file."
fi

echo "Revision completed."


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

# Exit immediately if a command fails
set -e

# FLEXRIC_LIBRARY_DIR="/usr/local/lib/flexric/" # Default
FLEXRIC_LIBRARY_DIR="flexric/build/flexric_libraries/lib/flexric/"

SCRIPT_DIR=$(dirname "$(realpath "$0")")

if [[ "$FLEXRIC_LIBRARY_DIR" != /* ]]; then
    FULL_SM_DIR="$SCRIPT_DIR/../$FLEXRIC_LIBRARY_DIR"
else
    FULL_SM_DIR="$FLEXRIC_LIBRARY_DIR"
fi
if [[ "$FULL_SM_DIR" != */ ]]; then
    FULL_SM_DIR="${FULL_SM_DIR}/"
fi

if [ -d "$FULL_SM_DIR" ]; then
    MODIFIED_TIME=$(stat -c '%y' "$FULL_SM_DIR")
    FORMATTED=$(date -d "$MODIFIED_TIME" '+%a %b %d %Y, %I:%M:%S %p')

    MODIFIED_EPOCH=$(date -d "$MODIFIED_TIME" +%s)
    NOW_EPOCH=$(date +%s)
    DIFF=$((NOW_EPOCH - MODIFIED_EPOCH))

    DAYS=$((DIFF / 86400))
    HOURS=$(((DIFF % 86400) / 3600))
    MINUTES=$(((DIFF % 3600) / 60))

    echo "FlexRIC libraries were last modified: $FORMATTED"
    printf "    %d days %d hours %d minutes ago\n" "$DAYS" "$HOURS" "$MINUTES"
else
    echo "FlexRIC libraries do not exist: $FULL_SM_DIR"
fi

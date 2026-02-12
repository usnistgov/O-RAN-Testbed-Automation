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

if [ $# -lt 1 ] || [ $# -gt 2 ]; then # Input validation
    echo "Usage: $0 <UE_NUMBER> [PLMN]"
    echo "Output fields: UE_OPC, UE_IMEI, UE_IMSI, UE_KEY, UE_NAMESPACE"
    exit 1
fi

UE_NUMBER="$1"
PLMN="${2:-""}" # Optional PLMN parameter

# Validate that UE_NUMBER is a positive integer
if ! [[ "$UE_NUMBER" =~ ^[0-9]+$ ]] || [ "$UE_NUMBER" -lt 1 ]; then
    echo "ERROR: UE_NUMBER must be a positive integer."
    exit 1
fi

UE_OPC="63BFA50EE6523365FF14C1F45F88737D"
UE_IMEI=""
UE_IMSI=""
UE_KEY=""
UE_NAMESPACE=""

if [ "$UE_NUMBER" -eq 1 ]; then # Following the blueprint for UE 1: https://doi.org/10.6028/NIST.TN.2311
    UE_IMEI="353490069873319"
    UE_IMSI="001010123456780"
    UE_KEY="00112233445566778899AABBCCDDEEFF"
    UE_NAMESPACE="ue1"

elif [ "$UE_NUMBER" -eq 2 ]; then # Following the blueprint for UE 2: https://doi.org/10.6028/NIST.TN.2311
    UE_IMEI="353490069873318"
    UE_IMSI="001010123456790"
    UE_KEY="00112233445566778899AABBCCDDEF00"
    UE_NAMESPACE="ue2"

elif [ "$UE_NUMBER" -eq 3 ]; then # Following the blueprint for UE 3: https://doi.org/10.6028/NIST.TN.2311
    UE_IMEI="353490069873312"
    UE_IMSI="001010123456791"
    UE_KEY="00112233445566778899AABBCCDDEF01"
    UE_NAMESPACE="ue3"

elif [ "$UE_NUMBER" -gt 3 ]; then # Dynamic configurations for UE 4 and beyond
    UE_OFFSET=$((UE_NUMBER - 3))
    UE_IMEI=$(printf '%d' $((353490069873319 + UE_OFFSET)))
    UE_IMSI=$(printf '%015d' $((1010123456791 + UE_OFFSET)))
    UE_KEY="00112233445566778$(printf '%X' $((16#899AABBCCDDEF01 + UE_OFFSET)))"
    UE_NAMESPACE="ue$UE_NUMBER"
fi

# Ensure that the beginning of the IMSI is the correct PLMN
if [ ! -z "$PLMN" ]; then
    PLMN_LENGTH=${#PLMN}
    UE_IMSI="${PLMN}${UE_IMSI:$PLMN_LENGTH}"
fi

echo "$UE_OPC" "$UE_IMEI" "$UE_IMSI" "$UE_KEY" "$UE_NAMESPACE"

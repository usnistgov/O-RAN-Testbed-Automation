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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

E2AP_FILE="./ocudu/include/ocudu/asn1/e2ap/e2ap.h"
KPM_FILE="./ocudu/include/ocudu/asn1/e2sm/e2sm_kpm_ies.h"

echo "OCUDU E2AP File: $E2AP_FILE"
echo "OCUDU E2SM KPM File: $KPM_FILE"
echo

if [ ! -f "$E2AP_FILE" ]; then
    echo "OCUDU gNB: ERROR: E2AP header file not found"
else
    # Parse 3GPP TS ASN1 E2AP vXX.XX
    VERSION=$(grep -oP "E2AP v\K[0-9.]+" "$E2AP_FILE" | head -n1)
    if [ -z "$VERSION" ]; then
        echo "OCUDU gNB: ERROR: Could not parse E2AP version"
    else
        echo "OCUDU gNB: E2AP v${VERSION}"
    fi
fi

if [ ! -f "$KPM_FILE" ]; then
    echo "OCUDU gNB: ERROR: E2SM KPM header file not found"
else
    # Parse 3GPP TS ASN1 E2SM vXX.XX
    KPM_VERSION=$(grep -oP "E2SM v\K[0-9.]+" "$KPM_FILE" | head -n1)
    if [ -z "$KPM_VERSION" ]; then
        echo "OCUDU gNB: ERROR: Could not parse E2SM KPM version"
    else
        echo "OCUDU gNB: E2SM KPM v${KPM_VERSION}"
    fi
fi

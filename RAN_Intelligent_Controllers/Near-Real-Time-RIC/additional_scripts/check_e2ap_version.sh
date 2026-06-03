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

set -e

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

E2SIM_FILE=$(ls ./e2-interface/e2sim/asn1c/asn/v03/e2ap-epd-*.asn 2>/dev/null)
E2SIM_KPM_FILE=$(ls ./e2-interface/e2sim/asn1c/asn/v03/e2sm-kpm-*.asn 2>/dev/null)
KPIMON_FILE="./xApps/kpimon-go/e2ap/asn1/elementryProcedureDefinition.asn"
KPIMON_KPM_FILE="./xApps/kpimon-go/e2sm/asn1/kpm2_0.asn"

echo "E2 simuator E2AP file: $E2SIM_FILE"
echo "E2 simuator E2SM KPM file: $E2SIM_KPM_FILE"
echo "KPI monitor xApp E2AP file: $KPIMON_FILE"
echo "KPI monitor xApp E2SM KPM file: $KPIMON_KPM_FILE"
echo

if [ -z "$E2SIM_FILE" ]; then
    echo "E2 simulator: ERROR: E2AP ASN file not found"
else
    E2SIM_NAME=$(basename "$E2SIM_FILE")
    E2SIM_VERSION=${E2SIM_NAME#e2ap-epd-v}
    E2SIM_VERSION=${E2SIM_VERSION%.asn}
    if [ -z "$E2SIM_VERSION" ]; then
        echo "E2 simulator: ERROR: Could not parse E2AP version"
    else
        echo "E2 simulator: E2AP v${E2SIM_VERSION}"
    fi
fi

if [ -z "$E2SIM_KPM_FILE" ]; then
    echo "E2 simulator: ERROR: E2SM KPM ASN file not found"
else
    E2SIM_KPM_NAME=$(basename "$E2SIM_KPM_FILE")
    E2SIM_KPM_VERSION=${E2SIM_KPM_NAME#e2sm-kpm-v}
    E2SIM_KPM_VERSION=${E2SIM_KPM_VERSION%.asn}
    if [ -z "$E2SIM_KPM_VERSION" ]; then
        echo "E2 simulator: ERROR: Could not parse E2SM KPM version"
    else
        echo "E2 simulator: E2SM KPM v${E2SIM_KPM_VERSION}"
    fi
fi

if [ ! -f "$KPIMON_FILE" ]; then
    echo "KPI monitor xApp: ERROR: E2AP ASN file not found"
else
    OID_LINE=$(grep "e2ap-PDU-Descriptions" "$KPIMON_FILE" 2>/dev/null)
    KPIMON_NUM=$(echo "$OID_LINE" | grep -oP 'version\K[0-9]')
    if [ -z "$KPIMON_NUM" ]; then
        echo "KPI monitor xApp: ERROR: Could not parse E2AP version"
    else
        echo "KPI monitor xApp: E2AP v${KPIMON_NUM}.0"
    fi
fi

if [ ! -f "$KPIMON_KPM_FILE" ]; then
    echo "KPI monitor xApp: ERROR: E2SM KPM ASN file not found"
else
    KPIMON_KPM_NUM=$(grep -oP 'version\d+\(\K\d+' "$KPIMON_KPM_FILE" 2>/dev/null | head -n1)
    if [ -z "$KPIMON_KPM_NUM" ]; then
        echo "KPI monitor xApp: ERROR: Could not parse E2SM KPM version"
    else
        echo "KPI monitor xApp: E2SM KPM v${KPIMON_KPM_NUM}.0"
    fi
fi

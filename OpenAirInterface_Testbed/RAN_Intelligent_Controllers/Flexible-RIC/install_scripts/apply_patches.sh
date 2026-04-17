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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Apply patch to FlexRIC to add support for RSRP in the KPI report
cd flexric
git restore examples/xApp/c/monitor/xapp_kpm_moni.c
if [ ! -f "examples/xApp/c/monitor/xapp_kpm_moni.c.previous" ]; then
    cp examples/xApp/c/monitor/xapp_kpm_moni.c examples/xApp/c/monitor/xapp_kpm_moni.c.previous
    cp examples/xApp/c/monitor/xapp_kpm_moni.c.previous "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni.previous.c"
fi
echo "Patching xapp_kpm_moni.c..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni.c.patch"
cd ..

# Apply patch to FlexRIC to add slice (SST + SD) support in RC xApp
cd flexric
git restore examples/xApp/c/kpm_rc/xapp_kpm_rc.c
if [ ! -f "examples/xApp/c/kpm_rc/xapp_kpm_rc.c.previous" ]; then
    cp examples/xApp/c/kpm_rc/xapp_kpm_rc.c examples/xApp/c/kpm_rc/xapp_kpm_rc.c.previous
    cp examples/xApp/c/kpm_rc/xapp_kpm_rc.c.previous "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/kpm_rc/xapp_kpm_rc.previous.c"
fi
echo "Patching xapp_kpm_rc.c..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/kpm_rc/xapp_kpm_rc.c.patch"

git restore examples/xApp/c/kpm_rc/CMakeLists.txt
if [ ! -f "examples/xApp/c/kpm_rc/CMakeLists.txt.previous" ]; then
    cp examples/xApp/c/kpm_rc/CMakeLists.txt examples/xApp/c/kpm_rc/CMakeLists.txt.previous
    cp examples/xApp/c/kpm_rc/CMakeLists.txt.previous "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/kpm_rc/CMakeLists.previous.txt"
fi
echo "Patching CMakeLists.txt..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/kpm_rc/CMakeLists.txt.patch"
cd ..

echo "Adding metrics_factory.h..."
cp "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/metrics_factory.h" flexric/examples/xApp/c/

echo "Adding metrics_factory.c..."
cp "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/metrics_factory.c" flexric/examples/xApp/c/

echo "Adding xapp_kpm_moni_write_to_csv.c..."
cp "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv.c" flexric/examples/xApp/c/monitor/

echo "Adding xapp_kpm_moni_write_to_influxdb.c..."
cp "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni_write_to_influxdb.c" flexric/examples/xApp/c/monitor/

# Apply patch to add new xApp KPI monitor that logs output to logs/KPI_Metrics.csv
cd flexric
git restore examples/xApp/c/monitor/CMakeLists.txt
if [ ! -f "examples/xApp/c/monitor/CMakeLists.txt.previous" ]; then
    cp examples/xApp/c/monitor/CMakeLists.txt examples/xApp/c/monitor/CMakeLists.txt.previous
    cp examples/xApp/c/monitor/CMakeLists.txt.previous "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/CMakeLists.previous.txt"
fi
echo "Patching CMakeLists.txt..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/CMakeLists.txt.patch"

echo "Adding stale subscription cleanup support patch to FlexRIC..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/stale_subscription_cleanup_support.patch"
cd ..

# Append new intermediate metrics units to 28_552_kpm_meas.txt
cd flexric
if ! grep -q "^RSRP.Count" src/sm/kpm_sm/28_552_kpm_meas.txt; then
    cat >>src/sm/kpm_sm/28_552_kpm_meas.txt <<'EOF'
PHY.NPrbDl []
DRB.HarqMcsUl []
DRB.HarqMcsDl []
DRB.DerivedCQIDl []
PHY.CqiWb1TbDl []
PHY.CqiWb2TbDl []
PHY.DerivedRssiDl [dBm]
PHY.DerivedRsrqDl [dB]
PUSCH.Snr [dB]
PUCCH.Snr [dB]
DRB.HarqBlockErrorRateUl [%]
DRB.HarqBlockErrorRateDl [%]
DRB.MacSduRetransmissionRateUl [%]
DRB.MacSduRetransmissionRateDl [%]
DRB.MacSduErrorRateUl [%]
DRB.MacSduErrorRateDl [%]
EOF
fi

# Append CARR.PUSCHMCSDist [PUSCH_RBs] after CARR.PUSCHMCSDist.BinX.BinY.BinZ [] if not already present
if ! grep -q "^CARR\.PUSCHMCSDist \[PUSCH_RBs\]" src/sm/kpm_sm/28_552_kpm_meas.txt; then
    sed -i '/^CARR\.PUSCHMCSDist\.BinX\.BinY\.BinZ \[\]$/a CARR.PUSCHMCSDist [PUSCH_RBs]' src/sm/kpm_sm/28_552_kpm_meas.txt
fi

# Append CARR.WBCQIDist [] after CARR.WBCQIDist.BinX.BinY.BinZ [] if not already present
if ! grep -q "^CARR\.WBCQIDist \[\]" src/sm/kpm_sm/28_552_kpm_meas.txt; then
    sed -i '/^CARR\.WBCQIDist\.BinX\.BinY\.BinZ \[\]$/a CARR.WBCQIDist []' src/sm/kpm_sm/28_552_kpm_meas.txt
fi

# Append L1M.SS-RSRP [dBm] after L1M.SS-RSRP.Bin [] if not already present
if ! grep -q "^L1M\.SS-RSRP \[dBm\]" src/sm/kpm_sm/28_552_kpm_meas.txt; then
    sed -i '/^L1M\.SS-RSRP\.Bin \[\]$/a L1M.SS-RSRP [dBm]' src/sm/kpm_sm/28_552_kpm_meas.txt
fi

cd ..

echo "Successfully patched FlexRIC."

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
echo "Patching CMakeLists.txt to list the new xApps for building..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/examples/xApp/c/monitor/CMakeLists.txt.patch"

# echo "Adding stale subscription cleanup support patch to FlexRIC..."
# STALE_SUBSCRIPTION_PATCH_DIR="$PARENT_DIR/install_patch_files/flexric/stale_subscription_cleanup_support"
# mkdir -p "$STALE_SUBSCRIPTION_PATCH_DIR"
# STALE_SUBSCRIPTION_PATCH_FILES=(
#     "examples/xApp/c/ctrl/mac_ctrl.c"
#     "examples/xApp/c/helloworld/hw.c"
#     "examples/xApp/c/keysight/xapp_keysight_kpm_rc.c"
#     "examples/xApp/c/monitor/xapp_rc_moni.c"
#     "examples/xApp/c/orange/xapp_es_with_cell_util.c"
#     "examples/xApp/c/slice/xapp_slice_moni_ctrl.c"
#     "examples/xApp/c/tc/xapp_tc_all.c"
#     "examples/xApp/c/tc/xapp_tc_codel.c"
#     "examples/xApp/c/tc/xapp_tc_ecn.c"
#     "examples/xApp/c/tc/xapp_tc_partition.c"
#     "src/ric/iApp/map_ric_id.c"
#     "src/ric/iApp/map_ric_id.h"
#     "src/ric/iApp/msg_handler_iapp.c"
#     "src/xApp/e42_xapp.c"
#     "src/xApp/e42_xapp.h"
#     "src/xApp/e42_xapp_api.c"
#     "src/xApp/e42_xapp_api.h"
#     "src/xApp/msg_handler_xapp.c"
# )

# for FILE in "${STALE_SUBSCRIPTION_PATCH_FILES[@]}"; do
#     git restore "$FILE"
#     if [ ! -f "$FILE.previous" ]; then
#         cp "$FILE" "$FILE.previous"
#         mkdir -p "$(dirname "$STALE_SUBSCRIPTION_PATCH_DIR/$FILE")"
#         cp "$FILE.previous" "$STALE_SUBSCRIPTION_PATCH_DIR/$FILE.previous"
#     fi
# done
# git apply --verbose --ignore-whitespace "$STALE_SUBSCRIPTION_PATCH_DIR/patch.patch"

cd ..

# Apply patch to FlexRIC to add support for disabling the SQLite database with cmake .. -DXAPP_DB=NONE_XAPP
cd flexric
echo "Adding option to disable SQLite database..."
git restore README.md
if [ ! -f "README.previous.md" ]; then
    cp README.md README.previous.md
    cp README.previous.md "$PARENT_DIR/install_patch_files/flexric/disable_database_option/README.previous.md"
fi
git restore src/xApp/db/CMakeLists.txt
if [ ! -f "src/xApp/db/CMakeLists.txt.previous" ]; then
    cp src/xApp/db/CMakeLists.txt src/xApp/db/CMakeLists.txt.previous
    cp src/xApp/db/CMakeLists.txt.previous "$PARENT_DIR/install_patch_files/flexric/disable_database_option/src/xApp/db/CMakeLists.previous.txt"
fi
git restore src/xApp/db/db.h
if [ ! -f "src/xApp/db/db.h.previous" ]; then
    cp src/xApp/db/db.h src/xApp/db/db.h.previous
    cp src/xApp/db/db.h.previous "$PARENT_DIR/install_patch_files/flexric/disable_database_option/src/xApp/db/db.previous.h"
fi
git restore src/xApp/db/db_generic.h
if [ ! -f "src/xApp/db/db_generic.h.previous" ]; then
    cp src/xApp/db/db_generic.h src/xApp/db/db_generic.h.previous
    cp src/xApp/db/db_generic.h.previous "$PARENT_DIR/install_patch_files/flexric/disable_database_option/src/xApp/db/db_generic.previous.h"
fi
git restore src/xApp/e42_xapp.c
if [ ! -f "src/xApp/e42_xapp.c.previous" ]; then
    cp src/xApp/e42_xapp.c src/xApp/e42_xapp.c.previous
    cp src/xApp/e42_xapp.c.previous "$PARENT_DIR/install_patch_files/flexric/disable_database_option/src/xApp/e42_xapp.previous.c"
fi
# # Omit e42_xapp.c since the stale subscription patch already modified it
# cp $STALE_SUBSCRIPTION_PATCH_DIR/src/xApp/e42_xapp.c.previous src/xApp/e42_xapp.previous.c
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/disable_database_option/patch.patch"
cd ..

# Apply patch to FlexRIC to fix the E2 node ID
cd flexric
echo "Patching FlexRIC to fix E2 node IDs..."
git restore examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni.c
git restore examples/xApp/c/monitor/xapp_rc_moni.c
git restore examples/xApp/c/orange/xapp_es_with_cell_util.c
git restore examples/xApp/c/slice/xapp_slice_moni_ctrl.c
git restore examples/xApp/c/tc/xapp_tc_all.c
git restore src/xApp/act_proc.c
git restore src/xApp/act_proc.h
git restore src/xApp/e42_xapp_api.h
git restore src/xApp/msg_dispatcher_xapp.c
git restore src/xApp/msg_dispatcher_xapp.h
git restore src/xApp/msg_handler_xapp.c
if [ ! -f "examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni.c.previous" ]; then
    cp examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni.c examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni.c.previous
    cp examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni.previous.c"
fi
if [ ! -f "examples/xApp/c/monitor/xapp_rc_moni.c.previous" ]; then
    cp examples/xApp/c/monitor/xapp_rc_moni.c examples/xApp/c/monitor/xapp_rc_moni.c.previous
    cp examples/xApp/c/monitor/xapp_rc_moni.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/examples/xApp/c/monitor/xapp_rc_moni.previous.c"
fi
if [ ! -f "examples/xApp/c/orange/xapp_es_with_cell_util.c.previous" ]; then
    cp examples/xApp/c/orange/xapp_es_with_cell_util.c examples/xApp/c/orange/xapp_es_with_cell_util.c.previous
    cp examples/xApp/c/orange/xapp_es_with_cell_util.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/examples/xApp/c/orange/xapp_es_with_cell_util.previous.c"
fi
if [ ! -f "examples/xApp/c/slice/xapp_slice_moni_ctrl.c.previous" ]; then
    cp examples/xApp/c/slice/xapp_slice_moni_ctrl.c examples/xApp/c/slice/xapp_slice_moni_ctrl.c.previous
    cp examples/xApp/c/slice/xapp_slice_moni_ctrl.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/examples/xApp/c/slice/xapp_slice_moni_ctrl.previous.c"
fi
if [ ! -f "examples/xApp/c/tc/xapp_tc_all.c.previous" ]; then
    cp examples/xApp/c/tc/xapp_tc_all.c examples/xApp/c/tc/xapp_tc_all.c.previous
    cp examples/xApp/c/tc/xapp_tc_all.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/examples/xApp/c/tc/xapp_tc_all.previous.c"
fi
if [ ! -f "src/xApp/act_proc.c.previous" ]; then
    cp src/xApp/act_proc.c src/xApp/act_proc.c.previous
    cp src/xApp/act_proc.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/src/xApp/act_proc.previous.c"
fi
if [ ! -f "src/xApp/act_proc.h.previous" ]; then
    cp src/xApp/act_proc.h src/xApp/act_proc.h.previous
    cp src/xApp/act_proc.h.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/src/xApp/act_proc.previous.h"
fi
if [ ! -f "src/xApp/e42_xapp_api.h.previous" ]; then
    cp src/xApp/e42_xapp_api.h src/xApp/e42_xapp_api.h.previous
    cp src/xApp/e42_xapp_api.h.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/src/xApp/e42_xapp_api.previous.h"
fi
if [ ! -f "src/xApp/msg_dispatcher_xapp.c.previous" ]; then
    cp src/xApp/msg_dispatcher_xapp.c src/xApp/msg_dispatcher_xapp.c.previous
    cp src/xApp/msg_dispatcher_xapp.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/src/xApp/msg_dispatcher_xapp.previous.c"
fi
if [ ! -f "src/xApp/msg_dispatcher_xapp.h.previous" ]; then
    cp src/xApp/msg_dispatcher_xapp.h src/xApp/msg_dispatcher_xapp.h.previous
    cp src/xApp/msg_dispatcher_xapp.h.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/src/xApp/msg_dispatcher_xapp.previous.h"
fi
if [ ! -f "src/xApp/msg_handler_xapp.c.previous" ]; then
    cp src/xApp/msg_handler_xapp.c src/xApp/msg_handler_xapp.c.previous
    cp src/xApp/msg_handler_xapp.c.previous "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/src/xApp/msg_handler_xapp.previous.c"
fi
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/flexric/correcting_e2_node_id/patch.patch"
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

# Append MR.NRScSSSINR [dB] after MR.NRScSSSINR.BinX [] if not already present
if ! grep -q "^MR\.NRScSSSINR \[dB\]" src/sm/kpm_sm/28_552_kpm_meas.txt; then
    sed -i '/^MR\.NRScSSSINR\.BinX \[\]$/a MR.NRScSSSINR [dB]' src/sm/kpm_sm/28_552_kpm_meas.txt
fi

# Increase FR_CONF_FILE_LEN from 128 to 1024 to prevent buffer overflows with long paths
echo "Patching FlexRIC conf_file.h to prevent long path buffer overflow..."
sed -i 's/#define FR_CONF_FILE_LEN 128/#define FR_CONF_FILE_LEN 1024/g' src/util/conf_file.h

cd ..

echo "Successfully patched FlexRIC."

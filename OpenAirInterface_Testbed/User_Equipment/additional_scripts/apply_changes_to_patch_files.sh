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

# The script directory respects symbolic links so that the gNB and UE can patch their own openairinterface5g
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if [ ! -d openairinterface5g ]; then
    echo "Duranta directory not found. Please ensure you are in the correct parent directory, and that the oai/openairinterface5g repository has been cloned."
    exit 1
fi

if [ ! -d install_patch_files ]; then
    mkdir install_patch_files
fi

cd openairinterface5g

# Update the patch files
git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c >../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.patch
git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c >../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.patch
git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c >../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c.patch
git diff openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h >../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.patch
git diff openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c >../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c.patch
git diff openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c >../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.patch

# Update the previous versions of the files
git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.previous.c
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.patch

git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.previous.c
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.patch

git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.previous.c
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c.patch

git restore openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h
cp openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.previous.h
cp openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.previous
git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.patch

git restore openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c
cp openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.previous.c
cp openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c.patch

git restore openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c
cp openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.previous.c
cp openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.patch

# Preserve Duranta PHY/MAC SS-SINR through periodic UE RRC MeasurementReports
if git diff --quiet common/utils/nr/nr_common.c; then
    echo "No changes for common/utils/nr/nr_common.c"
else
    git diff common/utils/nr/nr_common.c >../install_patch_files/openairinterface5g/common/utils/nr/nr_common.c.patch
    git restore common/utils/nr/nr_common.c
    cp common/utils/nr/nr_common.c ../install_patch_files/openairinterface5g/common/utils/nr/nr_common.previous.c
    cp common/utils/nr/nr_common.c common/utils/nr/nr_common.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/common/utils/nr/nr_common.c.patch
fi

if git diff --quiet common/utils/nr/nr_common.h; then
    echo "No changes for common/utils/nr/nr_common.h"
else
    git diff common/utils/nr/nr_common.h >../install_patch_files/openairinterface5g/common/utils/nr/nr_common.h.patch
    git restore common/utils/nr/nr_common.h
    cp common/utils/nr/nr_common.h ../install_patch_files/openairinterface5g/common/utils/nr/nr_common.previous.h
    cp common/utils/nr/nr_common.h common/utils/nr/nr_common.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/common/utils/nr/nr_common.h.patch
fi

if git diff --quiet common/utils/nr/tests/test_nr_common.cpp; then
    echo "No changes for common/utils/nr/tests/test_nr_common.cpp"
else
    git diff common/utils/nr/tests/test_nr_common.cpp >../install_patch_files/openairinterface5g/common/utils/nr/tests/test_nr_common.cpp.patch
    git restore common/utils/nr/tests/test_nr_common.cpp
    cp common/utils/nr/tests/test_nr_common.cpp ../install_patch_files/openairinterface5g/common/utils/nr/tests/test_nr_common.previous.cpp
    cp common/utils/nr/tests/test_nr_common.cpp common/utils/nr/tests/test_nr_common.cpp.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/common/utils/nr/tests/test_nr_common.cpp.patch
fi

if git diff --quiet openair2/COMMON/mac_messages_types.h; then
    echo "No changes for openair2/COMMON/mac_messages_types.h"
else
    git diff openair2/COMMON/mac_messages_types.h >../install_patch_files/openairinterface5g/openair2/COMMON/mac_messages_types.h.patch
    git restore openair2/COMMON/mac_messages_types.h
    cp openair2/COMMON/mac_messages_types.h ../install_patch_files/openairinterface5g/openair2/COMMON/mac_messages_types.previous.h
    cp openair2/COMMON/mac_messages_types.h openair2/COMMON/mac_messages_types.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/COMMON/mac_messages_types.h.patch
fi

if git diff --quiet openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c; then
    echo "No changes for openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c"
else
    git diff openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c >../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c.patch
    git restore openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c
    cp openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.previous.c
    cp openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_UE/nr_ue_procedures.c.patch
fi

if git diff --quiet openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp; then
    echo "No changes for openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp"
else
    git diff openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp >../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp.patch
    git restore openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp
    cp openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.previous.cpp
    cp openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_UE/tests/test_nr_ue_ra_procedures.cpp.patch
fi

if git diff --quiet openair2/RRC/NR/MESSAGES/asn1_msg.c; then
    echo "No changes for openair2/RRC/NR/MESSAGES/asn1_msg.c"
else
    git diff openair2/RRC/NR/MESSAGES/asn1_msg.c >../install_patch_files/openairinterface5g/openair2/RRC/NR/MESSAGES/asn1_msg.c.patch
    git restore openair2/RRC/NR/MESSAGES/asn1_msg.c
    cp openair2/RRC/NR/MESSAGES/asn1_msg.c ../install_patch_files/openairinterface5g/openair2/RRC/NR/MESSAGES/asn1_msg.previous.c
    cp openair2/RRC/NR/MESSAGES/asn1_msg.c openair2/RRC/NR/MESSAGES/asn1_msg.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR/MESSAGES/asn1_msg.c.patch
fi

if git diff --quiet openair2/RRC/NR/MESSAGES/asn1_msg.h; then
    echo "No changes for openair2/RRC/NR/MESSAGES/asn1_msg.h"
else
    git diff openair2/RRC/NR/MESSAGES/asn1_msg.h >../install_patch_files/openairinterface5g/openair2/RRC/NR/MESSAGES/asn1_msg.h.patch
    git restore openair2/RRC/NR/MESSAGES/asn1_msg.h
    cp openair2/RRC/NR/MESSAGES/asn1_msg.h ../install_patch_files/openairinterface5g/openair2/RRC/NR/MESSAGES/asn1_msg.previous.h
    cp openair2/RRC/NR/MESSAGES/asn1_msg.h openair2/RRC/NR/MESSAGES/asn1_msg.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR/MESSAGES/asn1_msg.h.patch
fi

if git diff --quiet openair2/RRC/NR/nr_rrc_defs.h; then
    echo "No changes for openair2/RRC/NR/nr_rrc_defs.h"
else
    git diff openair2/RRC/NR/nr_rrc_defs.h >../install_patch_files/openairinterface5g/openair2/RRC/NR/nr_rrc_defs.h.patch
    git restore openair2/RRC/NR/nr_rrc_defs.h
    cp openair2/RRC/NR/nr_rrc_defs.h ../install_patch_files/openairinterface5g/openair2/RRC/NR/nr_rrc_defs.previous.h
    cp openair2/RRC/NR/nr_rrc_defs.h openair2/RRC/NR/nr_rrc_defs.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR/nr_rrc_defs.h.patch
fi

if git diff --quiet openair2/RRC/NR/rrc_gNB.c; then
    echo "No changes for openair2/RRC/NR/rrc_gNB.c"
else
    git diff openair2/RRC/NR/rrc_gNB.c >../install_patch_files/openairinterface5g/openair2/RRC/NR/rrc_gNB.c.patch
    git restore openair2/RRC/NR/rrc_gNB.c
    cp openair2/RRC/NR/rrc_gNB.c ../install_patch_files/openairinterface5g/openair2/RRC/NR/rrc_gNB.previous.c
    cp openair2/RRC/NR/rrc_gNB.c openair2/RRC/NR/rrc_gNB.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR/rrc_gNB.c.patch
fi

if git diff --quiet openair2/RRC/NR_UE/L2_interface_ue.c; then
    echo "No changes for openair2/RRC/NR_UE/L2_interface_ue.c"
else
    git diff openair2/RRC/NR_UE/L2_interface_ue.c >../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/L2_interface_ue.c.patch
    git restore openair2/RRC/NR_UE/L2_interface_ue.c
    cp openair2/RRC/NR_UE/L2_interface_ue.c ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/L2_interface_ue.previous.c
    cp openair2/RRC/NR_UE/L2_interface_ue.c openair2/RRC/NR_UE/L2_interface_ue.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/L2_interface_ue.c.patch
fi

if git diff --quiet openair2/RRC/NR_UE/L2_interface_ue.h; then
    echo "No changes for openair2/RRC/NR_UE/L2_interface_ue.h"
else
    git diff openair2/RRC/NR_UE/L2_interface_ue.h >../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/L2_interface_ue.h.patch
    git restore openair2/RRC/NR_UE/L2_interface_ue.h
    cp openair2/RRC/NR_UE/L2_interface_ue.h ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/L2_interface_ue.previous.h
    cp openair2/RRC/NR_UE/L2_interface_ue.h openair2/RRC/NR_UE/L2_interface_ue.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/L2_interface_ue.h.patch
fi

if git diff --quiet openair2/RRC/NR_UE/rrc_defs.h; then
    echo "No changes for openair2/RRC/NR_UE/rrc_defs.h"
else
    git diff openair2/RRC/NR_UE/rrc_defs.h >../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_defs.h.patch
    git restore openair2/RRC/NR_UE/rrc_defs.h
    cp openair2/RRC/NR_UE/rrc_defs.h ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_defs.previous.h
    cp openair2/RRC/NR_UE/rrc_defs.h openair2/RRC/NR_UE/rrc_defs.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_defs.h.patch
fi

if git diff --quiet openair2/RRC/NR_UE/rrc_proto.h; then
    echo "No changes for openair2/RRC/NR_UE/rrc_proto.h"
else
    git diff openair2/RRC/NR_UE/rrc_proto.h >../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_proto.h.patch
    git restore openair2/RRC/NR_UE/rrc_proto.h
    cp openair2/RRC/NR_UE/rrc_proto.h ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_proto.previous.h
    cp openair2/RRC/NR_UE/rrc_proto.h openair2/RRC/NR_UE/rrc_proto.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_proto.h.patch
fi

if git diff --quiet openair2/RRC/NR_UE/rrc_timers_and_constants.c; then
    echo "No changes for openair2/RRC/NR_UE/rrc_timers_and_constants.c"
else
    git diff openair2/RRC/NR_UE/rrc_timers_and_constants.c >../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_timers_and_constants.c.patch
    git restore openair2/RRC/NR_UE/rrc_timers_and_constants.c
    cp openair2/RRC/NR_UE/rrc_timers_and_constants.c ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_timers_and_constants.previous.c
    cp openair2/RRC/NR_UE/rrc_timers_and_constants.c openair2/RRC/NR_UE/rrc_timers_and_constants.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_timers_and_constants.c.patch
fi

if git diff --quiet openair2/RRC/NR_UE/rrc_UE.c; then
    echo "No changes for openair2/RRC/NR_UE/rrc_UE.c"
else
    git diff openair2/RRC/NR_UE/rrc_UE.c >../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_UE.c.patch
    git restore openair2/RRC/NR_UE/rrc_UE.c
    cp openair2/RRC/NR_UE/rrc_UE.c ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_UE.previous.c
    cp openair2/RRC/NR_UE/rrc_UE.c openair2/RRC/NR_UE/rrc_UE.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/RRC/NR_UE/rrc_UE.c.patch
fi

if git diff --quiet openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h; then
    echo "No changes for openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h"
else
    git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h >../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.patch
    git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.previous.h
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.patch
fi

cd ..

echo "Successfully updated patch files in the install_patch_files directory."

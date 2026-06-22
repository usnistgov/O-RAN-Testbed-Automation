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

# Apply patch to fix srsRAN_4G ZMQ log_trx_timeout parsing
cd srsRAN_4G
git restore lib/src/phy/rf/rf_zmq_imp.c
if [ ! -f "lib/src/phy/rf/rf_zmq_imp.c.previous" ]; then
    cp lib/src/phy/rf/rf_zmq_imp.c lib/src/phy/rf/rf_zmq_imp.c.previous
    cp lib/src/phy/rf/rf_zmq_imp.c.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/src/phy/rf/rf_zmq_imp.previous.c"
fi
echo "Patching rf_zmq_imp.c to fix log_trx_timeout usage..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/src/phy/rf/rf_zmq_imp.c.patch"

if grep -q 'parse_string(args, "log_trx_timeout", i, tmp);' lib/src/phy/rf/rf_zmq_imp.c; then
    echo "ERROR: Failed to apply the srsRAN_4G ZMQ log_trx_timeout parsing fix."
    exit 1
fi
if ! grep -q 'parse_string(args, "log_trx_timeout", i, tmp2);' lib/src/phy/rf/rf_zmq_imp.c; then
    echo "ERROR: Could not verify the srsRAN_4G ZMQ log_trx_timeout parsing fix."
    exit 1
fi
cd ..

# # Apply patch to derive a valid temporary PRACH frequency offset before SIB1
# cd srsRAN_4G
# git restore srsue/src/stack/rrc_nr/rrc_nr_procedures.cc
# if [ ! -f "srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.previous" ]; then
#     cp srsue/src/stack/rrc_nr/rrc_nr_procedures.cc srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.previous
#     cp srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.previous"
# fi
# echo "Patching rrc_nr_procedures.cc to derive temporary PRACH offset..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.patch"
# cd ..

# # Apply patch to parse NR SR prohibit timer from the correct ASN.1 field
# cd srsRAN_4G
# git restore srsue/src/stack/rrc_nr/rrc_nr.cc
# if [ ! -f "srsue/src/stack/rrc_nr/rrc_nr.cc.previous" ]; then
#     cp srsue/src/stack/rrc_nr/rrc_nr.cc srsue/src/stack/rrc_nr/rrc_nr.cc.previous
#     cp srsue/src/stack/rrc_nr/rrc_nr.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr.cc.previous"
# fi
# echo "Patching rrc_nr.cc to parse SR prohibit timer..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr.cc.patch"
# cd ..

# # Apply patch to use temporary C-RNTI semantics during random access
# cd srsRAN_4G
# git restore srsue/src/stack/mac_nr/mac_nr.cc
# if [ ! -f "srsue/src/stack/mac_nr/mac_nr.cc.previous" ]; then
#     cp srsue/src/stack/mac_nr/mac_nr.cc srsue/src/stack/mac_nr/mac_nr.cc.previous
#     cp srsue/src/stack/mac_nr/mac_nr.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/mac_nr.cc.previous"
# fi
# echo "Patching mac_nr.cc to handle temporary C-RNTI scheduling..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/mac_nr.cc.patch"
# cd ..

# # Apply patch to trigger BSR/SR when new NR data first appears
# cd srsRAN_4G
# git restore srsue/src/stack/mac_nr/proc_bsr_nr.cc
# if [ ! -f "srsue/src/stack/mac_nr/proc_bsr_nr.cc.previous" ]; then
#     cp srsue/src/stack/mac_nr/proc_bsr_nr.cc srsue/src/stack/mac_nr/proc_bsr_nr.cc.previous
#     cp srsue/src/stack/mac_nr/proc_bsr_nr.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr.cc.previous"
# fi
# echo "Patching proc_bsr_nr.cc to trigger BSR for first NR data arrival..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr.cc.patch"
# cd ..

# # Apply patch to select NR RA preambles within the configured count
# cd srsRAN_4G
# git restore srsue/src/stack/mac_nr/proc_ra_nr.cc
# if [ ! -f "srsue/src/stack/mac_nr/proc_ra_nr.cc.previous" ]; then
#     cp srsue/src/stack/mac_nr/proc_ra_nr.cc srsue/src/stack/mac_nr/proc_ra_nr.cc.previous
#     cp srsue/src/stack/mac_nr/proc_ra_nr.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc.previous"
# fi
# echo "Patching proc_ra_nr.cc to select valid RA preambles..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc.patch"
# cd ..

# # Apply patch to add NR SR diagnostics for broker-mode attach debugging
# cd srsRAN_4G
# git restore srsue/hdr/stack/mac_nr/proc_sr_nr.h
# if [ ! -f "srsue/hdr/stack/mac_nr/proc_sr_nr.h.previous" ]; then
#     cp srsue/hdr/stack/mac_nr/proc_sr_nr.h srsue/hdr/stack/mac_nr/proc_sr_nr.h.previous
#     cp srsue/hdr/stack/mac_nr/proc_sr_nr.h.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/hdr/stack/mac_nr/proc_sr_nr.h.previous"
# fi
# echo "Patching proc_sr_nr.h to support SR prohibit timer state..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/hdr/stack/mac_nr/proc_sr_nr.h.patch"
# cd ..

# cd srsRAN_4G
# git restore srsue/src/stack/mac_nr/proc_sr_nr.cc
# if [ ! -f "srsue/src/stack/mac_nr/proc_sr_nr.cc.previous" ]; then
#     cp srsue/src/stack/mac_nr/proc_sr_nr.cc srsue/src/stack/mac_nr/proc_sr_nr.cc.previous
#     cp srsue/src/stack/mac_nr/proc_sr_nr.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr.cc.previous"
# fi
# echo "Patching proc_sr_nr.cc to print SR diagnostics..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr.cc.patch"
# cd ..

# # Apply patch to cover NR BSR first-data handling in the unit test
# cd srsRAN_4G
# git restore srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc
# if [ ! -f "srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc.previous" ]; then
#     cp srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc.previous
#     cp srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr_test.cc.previous"
# fi
# echo "Patching proc_bsr_nr_test.cc to validate first NR data arrival..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr_test.cc.patch"
# cd ..

# # Apply patch to align the NR RA unit test with randomized preamble selection
# cd srsRAN_4G
# git restore srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc
# if [ ! -f "srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc.previous" ]; then
#     cp srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc.previous
#     cp srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr_test.cc.previous"
# fi
# echo "Patching proc_ra_nr_test.cc to validate randomized RA preambles..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr_test.cc.patch"
# cd ..

# # Apply patch to cover SR prohibit timer support in the NR SR unit test
# cd srsRAN_4G
# git restore srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc
# if [ ! -f "srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc.previous" ]; then
#     cp srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc.previous
#     cp srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr_test.cc.previous"
# fi
# echo "Patching proc_sr_nr_test.cc to validate SR prohibit timer support..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr_test.cc.patch"
# cd ..

# # Apply patch to search the RA search space for temporary C-RNTI contention resolution
# cd srsRAN_4G
# git restore lib/src/phy/ue/ue_dl_nr.c
# if [ ! -f "lib/src/phy/ue/ue_dl_nr.c.previous" ]; then
#     cp lib/src/phy/ue/ue_dl_nr.c lib/src/phy/ue/ue_dl_nr.c.previous
#     cp lib/src/phy/ue/ue_dl_nr.c.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/src/phy/ue/ue_dl_nr.c.previous"
# fi
# echo "Patching ue_dl_nr.c to search temporary C-RNTI in RA search space..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/src/phy/ue/ue_dl_nr.c.patch"
# cd ..

# # Apply patch to ACK downlink grants scheduled with temporary C-RNTI
# cd srsRAN_4G
# git restore srsue/src/phy/nr/cc_worker.cc
# if [ ! -f "srsue/src/phy/nr/cc_worker.cc.previous" ]; then
#     cp srsue/src/phy/nr/cc_worker.cc srsue/src/phy/nr/cc_worker.cc.previous
#     cp srsue/src/phy/nr/cc_worker.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/phy/nr/cc_worker.cc.previous"
# fi
# echo "Patching cc_worker.cc to ACK temporary C-RNTI grants..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/srsue/src/phy/nr/cc_worker.cc.patch"
# cd ..

# # Apply patch to use the NR default of 64 contention-based RA preambles
# cd srsRAN_4G
# git restore lib/src/asn1/rrc_nr_utils.cc
# if [ ! -f "lib/src/asn1/rrc_nr_utils.cc.previous" ]; then
#     cp lib/src/asn1/rrc_nr_utils.cc lib/src/asn1/rrc_nr_utils.cc.previous
#     cp lib/src/asn1/rrc_nr_utils.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/src/asn1/rrc_nr_utils.cc.previous"
# fi
# echo "Patching rrc_nr_utils.cc to use default NR RA preamble count..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/src/asn1/rrc_nr_utils.cc.patch"
# cd ..

# # Apply patch to cover NR RA preamble count conversion in the ASN.1 unit test
# cd srsRAN_4G
# git restore lib/test/asn1/rrc_nr_utils_test.cc
# if [ ! -f "lib/test/asn1/rrc_nr_utils_test.cc.previous" ]; then
#     cp lib/test/asn1/rrc_nr_utils_test.cc lib/test/asn1/rrc_nr_utils_test.cc.previous
#     cp lib/test/asn1/rrc_nr_utils_test.cc.previous "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/test/asn1/rrc_nr_utils_test.cc.previous"
# fi
# echo "Patching rrc_nr_utils_test.cc to validate NR RA preamble count conversion..."
# git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/srsRAN_4G/lib/test/asn1/rrc_nr_utils_test.cc.patch"
# cd ..

echo
echo "Successfully patched srsRAN_4G."

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

if [ ! -d srsRAN_4G ]; then
    echo "srsRAN_4G directory not found. Please ensure the repository has been cloned."
    exit 1
fi

mkdir -p install_patch_files/srsRAN_4G/lib/src/phy/rf
mkdir -p install_patch_files/srsRAN_4G/lib/src/phy/ue
mkdir -p install_patch_files/srsRAN_4G/lib/src/asn1
mkdir -p install_patch_files/srsRAN_4G/lib/test/asn1
mkdir -p install_patch_files/srsRAN_4G/srsue/src/phy/nr
mkdir -p install_patch_files/srsRAN_4G/srsue/hdr/stack/mac_nr
mkdir -p install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr
mkdir -p install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr

cd srsRAN_4G

# Update patch files from the current srsRAN_4G working tree.
git diff lib/src/phy/rf/rf_zmq_imp.c >../install_patch_files/srsRAN_4G/lib/src/phy/rf/rf_zmq_imp.c.patch
git diff lib/src/phy/ue/ue_dl_nr.c >../install_patch_files/srsRAN_4G/lib/src/phy/ue/ue_dl_nr.c.patch
git diff lib/src/asn1/rrc_nr_utils.cc >../install_patch_files/srsRAN_4G/lib/src/asn1/rrc_nr_utils.cc.patch
git diff lib/test/asn1/rrc_nr_utils_test.cc >../install_patch_files/srsRAN_4G/lib/test/asn1/rrc_nr_utils_test.cc.patch
git diff srsue/src/phy/nr/cc_worker.cc >../install_patch_files/srsRAN_4G/srsue/src/phy/nr/cc_worker.cc.patch
git diff srsue/hdr/stack/mac_nr/proc_sr_nr.h >../install_patch_files/srsRAN_4G/srsue/hdr/stack/mac_nr/proc_sr_nr.h.patch
git diff srsue/src/stack/mac_nr/mac_nr.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/mac_nr.cc.patch
git diff srsue/src/stack/mac_nr/proc_bsr_nr.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr.cc.patch
git diff srsue/src/stack/mac_nr/proc_ra_nr.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc.patch
git diff srsue/src/stack/mac_nr/proc_sr_nr.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr.cc.patch
git diff srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr_test.cc.patch
git diff srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr_test.cc.patch
git diff srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr_test.cc.patch
git diff srsue/src/stack/rrc_nr/rrc_nr.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr.cc.patch
git diff srsue/src/stack/rrc_nr/rrc_nr_procedures.cc >../install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.patch

# Update previous-file snapshots and reapply patches to preserve the working tree.
git restore lib/src/phy/rf/rf_zmq_imp.c
cp lib/src/phy/rf/rf_zmq_imp.c ../install_patch_files/srsRAN_4G/lib/src/phy/rf/rf_zmq_imp.previous.c
cp lib/src/phy/rf/rf_zmq_imp.c lib/src/phy/rf/rf_zmq_imp.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/lib/src/phy/rf/rf_zmq_imp.c.patch

git restore lib/src/phy/ue/ue_dl_nr.c
cp lib/src/phy/ue/ue_dl_nr.c ../install_patch_files/srsRAN_4G/lib/src/phy/ue/ue_dl_nr.c.previous
cp lib/src/phy/ue/ue_dl_nr.c lib/src/phy/ue/ue_dl_nr.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/lib/src/phy/ue/ue_dl_nr.c.patch

git restore lib/src/asn1/rrc_nr_utils.cc
cp lib/src/asn1/rrc_nr_utils.cc ../install_patch_files/srsRAN_4G/lib/src/asn1/rrc_nr_utils.cc.previous
cp lib/src/asn1/rrc_nr_utils.cc lib/src/asn1/rrc_nr_utils.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/lib/src/asn1/rrc_nr_utils.cc.patch

git restore lib/test/asn1/rrc_nr_utils_test.cc
cp lib/test/asn1/rrc_nr_utils_test.cc ../install_patch_files/srsRAN_4G/lib/test/asn1/rrc_nr_utils_test.cc.previous
cp lib/test/asn1/rrc_nr_utils_test.cc lib/test/asn1/rrc_nr_utils_test.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/lib/test/asn1/rrc_nr_utils_test.cc.patch

git restore srsue/src/phy/nr/cc_worker.cc
cp srsue/src/phy/nr/cc_worker.cc ../install_patch_files/srsRAN_4G/srsue/src/phy/nr/cc_worker.cc.previous
cp srsue/src/phy/nr/cc_worker.cc srsue/src/phy/nr/cc_worker.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/phy/nr/cc_worker.cc.patch

git restore srsue/hdr/stack/mac_nr/proc_sr_nr.h
cp srsue/hdr/stack/mac_nr/proc_sr_nr.h ../install_patch_files/srsRAN_4G/srsue/hdr/stack/mac_nr/proc_sr_nr.h.previous
cp srsue/hdr/stack/mac_nr/proc_sr_nr.h srsue/hdr/stack/mac_nr/proc_sr_nr.h.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/hdr/stack/mac_nr/proc_sr_nr.h.patch

git restore srsue/src/stack/mac_nr/mac_nr.cc
cp srsue/src/stack/mac_nr/mac_nr.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/mac_nr.cc.previous
cp srsue/src/stack/mac_nr/mac_nr.cc srsue/src/stack/mac_nr/mac_nr.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/mac_nr.cc.patch

git restore srsue/src/stack/mac_nr/proc_bsr_nr.cc
cp srsue/src/stack/mac_nr/proc_bsr_nr.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr.cc.previous
cp srsue/src/stack/mac_nr/proc_bsr_nr.cc srsue/src/stack/mac_nr/proc_bsr_nr.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr.cc.patch

git restore srsue/src/stack/mac_nr/proc_ra_nr.cc
cp srsue/src/stack/mac_nr/proc_ra_nr.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc.previous
cp srsue/src/stack/mac_nr/proc_ra_nr.cc srsue/src/stack/mac_nr/proc_ra_nr.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc.patch

git restore srsue/src/stack/mac_nr/proc_sr_nr.cc
cp srsue/src/stack/mac_nr/proc_sr_nr.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr.cc.previous
cp srsue/src/stack/mac_nr/proc_sr_nr.cc srsue/src/stack/mac_nr/proc_sr_nr.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr.cc.patch

git restore srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc
cp srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr_test.cc.previous
cp srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc srsue/src/stack/mac_nr/test/proc_bsr_nr_test.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr_test.cc.patch

git restore srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc
cp srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr_test.cc.previous
cp srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc srsue/src/stack/mac_nr/test/proc_ra_nr_test.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr_test.cc.patch

git restore srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc
cp srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr_test.cc.previous
cp srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc srsue/src/stack/mac_nr/test/proc_sr_nr_test.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr_test.cc.patch

git restore srsue/src/stack/rrc_nr/rrc_nr.cc
cp srsue/src/stack/rrc_nr/rrc_nr.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr.cc.previous
cp srsue/src/stack/rrc_nr/rrc_nr.cc srsue/src/stack/rrc_nr/rrc_nr.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr.cc.patch

git restore srsue/src/stack/rrc_nr/rrc_nr_procedures.cc
cp srsue/src/stack/rrc_nr/rrc_nr_procedures.cc ../install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.previous
cp srsue/src/stack/rrc_nr/rrc_nr_procedures.cc srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.previous
git apply --verbose --ignore-whitespace ../install_patch_files/srsRAN_4G/srsue/src/stack/rrc_nr/rrc_nr_procedures.cc.patch

cd ..

echo "Successfully updated srsRAN_4G patch files."

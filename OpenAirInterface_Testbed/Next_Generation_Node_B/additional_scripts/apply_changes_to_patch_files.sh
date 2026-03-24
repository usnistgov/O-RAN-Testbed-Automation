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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if [ ! -d openairinterface5g ]; then
    echo "OpenAirInterface directory not found. Please ensure you are in the correct parent directory, and that the oai/openairinterface5g repository has been cloned."
    exit 1
fi

if [ ! -d install_patch_files ]; then
    mkdir install_patch_files
fi

cd openairinterface5g
git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c >../install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.patch
git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c >../install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.patch
git diff openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h >../install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.patch
git diff openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c >../install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.patch
git diff openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c >../install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c.patch
git diff common/utils/telnetsrv/telnetsrv_o1.c >../install_patch_files/openairinterface/common/utils/telnetsrv/telnetsrv_o1.c.patch
cd ..

if [ -d o1-adapter ]; then
    cd o1-adapter
    git diff docker/Dockerfile.adapter >../install_patch_files/o1-adapter/docker/Dockerfile.adapter.patch
    git diff docker/scripts/get-yangs.sh >../install_patch_files/o1-adapter/docker/scripts/get-yangs.sh.patch
    git diff docker/scripts/install-yangs.sh >../install_patch_files/o1-adapter/docker/scripts/install-yangs.sh.patch
    cp docker/scripts/oai-handover.yang ../install_patch_files/o1-adapter/docker/scripts/oai-handover.yang
    git diff src/main.c >../install_patch_files/o1-adapter/src/main.c.patch
    git diff src/netconf/netconf_data.c >../install_patch_files/o1-adapter/src/netconf/netconf_data.c.patch
    git diff src/netconf/netconf_data.h >../install_patch_files/o1-adapter/src/netconf/netconf_data.h.patch
    git diff src/telnet/telnet.c >../install_patch_files/o1-adapter/src/telnet/telnet.c.patch
    git diff src/telnet/telnet.h >../install_patch_files/o1-adapter/src/telnet/telnet.h.patch
    cp handover_support.md ../install_patch_files/o1-adapter/handover_support.md
    cd ..
fi

echo "Successfully updated patch files in the install_patch_files directory."

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

E2AP_VERSION="E2AP_V2"  # E2AP_V1, E2AP_V2, E2AP_V3
KPM_VERSION="KPM_V2_03" # KPM_V2_03, KPM_V3_00

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Modify CMakeLists.txt to set E2AP_VERSION and KPM_VERSION (must match FlexRIC)
cd openairinterface5g
if [ -f "CMakeLists.txt" ]; then
    echo "Modifying CMakeLists.txt to set E2AP_VERSION to $E2AP_VERSION..."
    sed -i "s/set(E2AP_VERSION \"[^\"]*\"/set(E2AP_VERSION \"$E2AP_VERSION\"/" CMakeLists.txt
fi
if [ -f "CMakeLists.txt" ]; then
    echo "Modifying CMakeLists.txt to set KPM_VERSION to $KPM_VERSION..."
    sed -i "s/set(KPM_VERSION \"[^\"]*\"/set(KPM_VERSION \"$KPM_VERSION\"/" CMakeLists.txt
fi
cd ..

# Apply patches to OpenAirInterface to add support for additional metrics in the KPI report
cd openairinterface5g
git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c
if [ ! -f "openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.previous" ]; then
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.previous
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.previous "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.previous.c"
fi
echo "Patching ran_func_kpm.c..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.patch"
cd ..

cd openairinterface5g
git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h
if [ ! -f "openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.previous" ]; then
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.previous
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.previous "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.previous.h"
fi
echo "Patching ran_func_kpm_subs.h..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.patch"
cd ..

cd openairinterface5g
git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c
if [ ! -f "openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.previous" ]; then
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.previous
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.previous "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.previous.c"
fi
echo "Patching ran_func_kpm_subs.c..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.patch"
cd ..

cd openairinterface5g
git restore openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h
if [ ! -f "openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.previous" ]; then
    cp openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.previous
    cp openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.previous "$PARENT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.previous.h"
fi
echo "Patching nr_mac_gNB.h..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.patch"
cd ..

cd openairinterface5g
git restore openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c
if [ ! -f "openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.previous" ]; then
    cp openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.previous
    cp openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.previous "$PARENT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.previous.c"
fi
echo "Patching gNB_scheduler_dlsch.c..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.patch"
cd ..

cd openairinterface5g
git restore openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c
if [ ! -f "openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c.previous" ]; then
    cp openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c.previous
    cp openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c.previous "$PARENT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.previous.c"
fi
echo "Patching gNB_scheduler_uci.c..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_uci.c.patch"
cd ..

cd openairinterface5g
git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c
if [ ! -f "openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c.previous" ]; then
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c.previous
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c.previous "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.previous.c"
fi
echo "Patching ran_func_rc.c for handover support..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_rc.c.patch"
cd ..

# If using Linux Mint, add support for Linux Mint 20, 21, and 22 to OpenAirInterface
if grep -q "Linux Mint" /etc/os-release; then
    echo "Linux Mint detected, attempting to patching OpenAirInterface to support Linux Mint 20, 21, and 22..."
    cd openairinterface5g
    git restore cmake_targets/tools/build_helper
    if [ ! -f "cmake_targets/tools/build_helper.previous" ]; then
        cp cmake_targets/tools/build_helper cmake_targets/tools/build_helper.previous
        cp cmake_targets/tools/build_helper.previous "$PARENT_DIR/install_patch_files/openairinterface/cmake_targets/tools/build_helper.previous"
    fi
    echo "Patching build_helper to add Linux Mint support..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface/cmake_targets/tools/build_helper.patch"
    cd ..
    echo
fi

echo "Successfully patched OpenAirInterface."

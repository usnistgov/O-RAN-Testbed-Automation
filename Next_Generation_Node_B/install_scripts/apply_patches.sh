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
OVERRIDE_PCELL_EXECUTOR_PATCHES=""

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Apply patch to OCUDU to support kernel headers that do not define SCTP_SEND_FAILED_EVENT
cd ocudu
git restore lib/gateways/sctp_network_gateway_common_impl.cpp
if [ ! -f "lib/gateways/sctp_network_gateway_common_impl.cpp.previous" ]; then
    cp lib/gateways/sctp_network_gateway_common_impl.cpp lib/gateways/sctp_network_gateway_common_impl.cpp.previous
    cp lib/gateways/sctp_network_gateway_common_impl.cpp.previous "$PARENT_DIR/install_patch_files/ocudu/lib/gateways/sctp_network_gateway_common_impl.previous.cpp"
fi
echo "Patching sctp_network_gateway_common_impl.cpp..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ocudu/lib/gateways/sctp_network_gateway_common_impl.cpp.patch"
cd ..

# Apply patch to OCUDU to ensure yaml-cpp imported targets are globally visible before aliasing
cd ocudu
git restore cmake/modules/FindYAMLCPP.cmake
if [ ! -f "cmake/modules/FindYAMLCPP.cmake.previous" ]; then
    cp cmake/modules/FindYAMLCPP.cmake cmake/modules/FindYAMLCPP.cmake.previous
    cp cmake/modules/FindYAMLCPP.cmake.previous "$PARENT_DIR/install_patch_files/ocudu/cmake/modules/FindYAMLCPP.previous.cmake"
fi
echo "Patching FindYAMLCPP.cmake..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ocudu/cmake/modules/FindYAMLCPP.cmake.patch"
cd ..

# Apply patch to report all E2SM-KPM style 3 metrics in one indication
cd ocudu
git restore lib/e2/e2sm/e2sm_kpm/e2sm_kpm_report_service_impl.cpp
git restore tests/unittests/e2/e2sm_kpm_test.cpp
echo "Patching E2SM-KPM style 3 multi-metric reports..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ocudu/lib/e2/e2sm/e2sm_kpm/multi_metric_style3.patch"
cd ..

# Apply patches when the number of processors is low to allow OCUDU startup, UE attach, and PDU session establishment
# For more information, see https://gitlab.com/ocudu/ocudu/-/work_items/571
cd ocudu
git restore lib/mac/mac_dl/mac_cell_processor.cpp
if [ ! -f "lib/mac/mac_dl/mac_cell_processor.cpp.previous" ]; then
    cp lib/mac/mac_dl/mac_cell_processor.cpp lib/mac/mac_dl/mac_cell_processor.cpp.previous
    cp lib/mac/mac_dl/mac_cell_processor.cpp.previous "$PARENT_DIR/install_patch_files/ocudu/lib/mac/mac_dl/mac_cell_processor.cpp.previous"
fi
git restore lib/rlc/rlc_tx_tm_entity.cpp
if [ ! -f "lib/rlc/rlc_tx_tm_entity.cpp.previous" ]; then
    cp lib/rlc/rlc_tx_tm_entity.cpp lib/rlc/rlc_tx_tm_entity.cpp.previous
    cp lib/rlc/rlc_tx_tm_entity.cpp.previous "$PARENT_DIR/install_patch_files/ocudu/lib/rlc/rlc_tx_tm_entity.cpp.previous"
fi
git restore lib/rlc/rlc_tx_am_entity.cpp
if [ ! -f "lib/rlc/rlc_tx_am_entity.cpp.previous" ]; then
    cp lib/rlc/rlc_tx_am_entity.cpp lib/rlc/rlc_tx_am_entity.cpp.previous
    cp lib/rlc/rlc_tx_am_entity.cpp.previous "$PARENT_DIR/install_patch_files/ocudu/lib/rlc/rlc_tx_am_entity.cpp.previous"
fi
if [ "$(nproc)" -le 4 ] || [ "$OVERRIDE_PCELL_EXECUTOR_PATCHES" = "true" ]; then
    echo "Patching mac_cell_processor.cpp, rlc_tx_tm_entity.cpp, and rlc_tx_am_entity.cpp..."
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ocudu/lib/mac/mac_dl/mac_cell_processor.cpp.patch"
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ocudu/lib/rlc/rlc_tx_tm_entity.cpp.patch"
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ocudu/lib/rlc/rlc_tx_am_entity.cpp.patch"
else
    echo "Skipping patching mac_cell_processor.cpp, rlc_tx_tm_entity.cpp, and rlc_tx_am_entity.cpp since the number of processors is greater than 4."
fi
cd ..

echo
echo "Successfully patched OCUDU."

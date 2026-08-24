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
set -x

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if [ ! -d ocudu ]; then
    echo "OCUDU directory not found. Please ensure the OCUDU repository has been cloned."
    exit 1
fi

mkdir -p install_patch_files/ocudu/cmake/modules
mkdir -p install_patch_files/ocudu/lib/gateways
mkdir -p install_patch_files/ocudu/lib/mac/mac_dl
mkdir -p install_patch_files/ocudu/lib/rlc
mkdir -p install_patch_files/ocudu/lib/scheduler/ue_scheduling

cd ocudu

git diff cmake/modules/FindYAMLCPP.cmake >../install_patch_files/ocudu/cmake/modules/FindYAMLCPP.cmake.patch
git diff lib/gateways/sctp_network_gateway_common_impl.cpp >../install_patch_files/ocudu/lib/gateways/sctp_network_gateway_common_impl.cpp.patch
git diff lib/mac/mac_dl/mac_cell_processor.cpp >../install_patch_files/ocudu/lib/mac/mac_dl/mac_cell_processor.cpp.patch
git diff lib/rlc/rlc_tx_tm_entity.cpp >../install_patch_files/ocudu/lib/rlc/rlc_tx_tm_entity.cpp.patch
git diff lib/rlc/rlc_tx_am_entity.cpp >../install_patch_files/ocudu/lib/rlc/rlc_tx_am_entity.cpp.patch

git restore cmake/modules/FindYAMLCPP.cmake
cp cmake/modules/FindYAMLCPP.cmake ../install_patch_files/ocudu/cmake/modules/FindYAMLCPP.previous.cmake
cp cmake/modules/FindYAMLCPP.cmake cmake/modules/FindYAMLCPP.cmake.previous
git apply --verbose --ignore-whitespace ../install_patch_files/ocudu/cmake/modules/FindYAMLCPP.cmake.patch

git restore lib/gateways/sctp_network_gateway_common_impl.cpp
cp lib/gateways/sctp_network_gateway_common_impl.cpp ../install_patch_files/ocudu/lib/gateways/sctp_network_gateway_common_impl.previous.cpp
cp lib/gateways/sctp_network_gateway_common_impl.cpp lib/gateways/sctp_network_gateway_common_impl.cpp.previous
git apply --verbose --ignore-whitespace ../install_patch_files/ocudu/lib/gateways/sctp_network_gateway_common_impl.cpp.patch

git restore lib/mac/mac_dl/mac_cell_processor.cpp
cp lib/mac/mac_dl/mac_cell_processor.cpp ../install_patch_files/ocudu/lib/mac/mac_dl/mac_cell_processor.cpp.previous
cp lib/mac/mac_dl/mac_cell_processor.cpp lib/mac/mac_dl/mac_cell_processor.cpp.previous
git apply --verbose --ignore-whitespace ../install_patch_files/ocudu/lib/mac/mac_dl/mac_cell_processor.cpp.patch

git restore lib/rlc/rlc_tx_tm_entity.cpp
cp lib/rlc/rlc_tx_tm_entity.cpp ../install_patch_files/ocudu/lib/rlc/rlc_tx_tm_entity.cpp.previous
cp lib/rlc/rlc_tx_tm_entity.cpp lib/rlc/rlc_tx_tm_entity.cpp.previous
git apply --verbose --ignore-whitespace ../install_patch_files/ocudu/lib/rlc/rlc_tx_tm_entity.cpp.patch

git restore lib/rlc/rlc_tx_am_entity.cpp
cp lib/rlc/rlc_tx_am_entity.cpp ../install_patch_files/ocudu/lib/rlc/rlc_tx_am_entity.cpp.previous
cp lib/rlc/rlc_tx_am_entity.cpp lib/rlc/rlc_tx_am_entity.cpp.previous
git apply --verbose --ignore-whitespace ../install_patch_files/ocudu/lib/rlc/rlc_tx_am_entity.cpp.patch

cd ..

echo "Successfully updated OCUDU patch files."

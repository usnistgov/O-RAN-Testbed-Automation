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

# Script directory from the called path, including symlinks
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

# Prevent exhaustion of UEs by releasing one CBRA UE when the UE list is full
if git diff --quiet openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c; then
    echo "No changes for openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c"
else
    echo "Updating patch for mac_rrc_dl_handler.c..."
    git diff openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c >../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c.patch
    git restore openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c
    cp openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.previous.c
    cp openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c.patch
fi

# Adds support for Linux Mint and Ubuntu 20.04
if git diff --quiet cmake_targets/tools/build_helper; then
    echo "No changes for cmake_targets/tools/build_helper"
else
    echo "Updating patch for build_helper..."
    git diff cmake_targets/tools/build_helper >../install_patch_files/openairinterface5g/cmake_targets/tools/build_helper.patch
    git restore cmake_targets/tools/build_helper
    cp cmake_targets/tools/build_helper ../install_patch_files/openairinterface5g/cmake_targets/tools/build_helper.previous
    cp cmake_targets/tools/build_helper cmake_targets/tools/build_helper.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/cmake_targets/tools/build_helper.patch
fi

# Fixes the ZeroMQ bug where negative I/Q samples are not rounded in the wrong directions
if git diff --quiet radio/zmq/zmq_simd.h; then
    echo "No changes for radio/zmq/zmq_simd.h"
else
    echo "Updating patch for zmq_simd.h..."
    git diff radio/zmq/zmq_simd.h >../install_patch_files/openairinterface5g/radio/zmq/zmq_simd.h.patch
    git restore radio/zmq/zmq_simd.h
    cp radio/zmq/zmq_simd.h ../install_patch_files/openairinterface5g/radio/zmq/zmq_simd.previous.h
    cp radio/zmq/zmq_simd.h radio/zmq/zmq_simd.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/radio/zmq/zmq_simd.h.patch
fi

if git diff --quiet radio/zmq/tests/test_zmq_radio.cpp; then
    echo "No changes for radio/zmq/tests/test_zmq_radio.cpp"
else
    echo "Updating patch for test_zmq_radio.cpp..."
    git diff radio/zmq/tests/test_zmq_radio.cpp >../install_patch_files/openairinterface5g/radio/zmq/tests/test_zmq_radio.cpp.patch
    git restore radio/zmq/tests/test_zmq_radio.cpp
    cp radio/zmq/tests/test_zmq_radio.cpp ../install_patch_files/openairinterface5g/radio/zmq/tests/test_zmq_radio.previous.cpp
    cp radio/zmq/tests/test_zmq_radio.cpp radio/zmq/tests/test_zmq_radio.cpp.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/radio/zmq/tests/test_zmq_radio.cpp.patch
fi

# Adds C++11 compatibility to the ZeroMQ ring buffer code
if git diff --quiet radio/zmq/ring_buffer.cpp; then
    echo "No changes for radio/zmq/ring_buffer.cpp"
else
    echo "Updating patch for ring_buffer.cpp..."
    git diff radio/zmq/ring_buffer.cpp >../install_patch_files/openairinterface5g/radio/zmq/ring_buffer.cpp.patch
    git restore radio/zmq/ring_buffer.cpp
    cp radio/zmq/ring_buffer.cpp ../install_patch_files/openairinterface5g/radio/zmq/ring_buffer.previous.cpp
    cp radio/zmq/ring_buffer.cpp radio/zmq/ring_buffer.cpp.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/radio/zmq/ring_buffer.cpp.patch
fi

if git diff --quiet radio/zmq/zmq_imported.cpp; then
    echo "No changes for radio/zmq/zmq_imported.cpp"
else
    echo "Updating patch for zmq_imported.cpp..."
    git diff radio/zmq/zmq_imported.cpp >../install_patch_files/openairinterface5g/radio/zmq/zmq_imported.cpp.patch
    git restore radio/zmq/zmq_imported.cpp
    cp radio/zmq/zmq_imported.cpp ../install_patch_files/openairinterface5g/radio/zmq/zmq_imported.previous.cpp
    cp radio/zmq/zmq_imported.cpp radio/zmq/zmq_imported.cpp.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/radio/zmq/zmq_imported.cpp.patch
fi

if git diff --quiet radio/zmq/zmq_imported.h; then
    echo "No changes for radio/zmq/zmq_imported.h"
else
    echo "Updating patch for zmq_imported.h..."
    git diff radio/zmq/zmq_imported.h >../install_patch_files/openairinterface5g/radio/zmq/zmq_imported.h.patch
    git restore radio/zmq/zmq_imported.h
    cp radio/zmq/zmq_imported.h ../install_patch_files/openairinterface5g/radio/zmq/zmq_imported.previous.h
    cp radio/zmq/zmq_imported.h radio/zmq/zmq_imported.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/radio/zmq/zmq_imported.h.patch
fi

# Patch nr_nas_msg.c for OpenSSL 1.1.x build compatibility (Ubuntu 20.04)
if git diff --quiet openair3/NAS/NR_UE/nr_nas_msg.c; then
    echo "No changes for openair3/NAS/NR_UE/nr_nas_msg.c"
else
    echo "Updating patch for nr_nas_msg.c..."
    git diff openair3/NAS/NR_UE/nr_nas_msg.c >../install_patch_files/openairinterface5g/openair3/NAS/NR_UE/nr_nas_msg.c.patch
    git restore openair3/NAS/NR_UE/nr_nas_msg.c
    cp openair3/NAS/NR_UE/nr_nas_msg.c ../install_patch_files/openairinterface5g/openair3/NAS/NR_UE/nr_nas_msg.previous.c
    cp openair3/NAS/NR_UE/nr_nas_msg.c openair3/NAS/NR_UE/nr_nas_msg.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair3/NAS/NR_UE/nr_nas_msg.c.patch
fi

# Fixes gNB ID swapped with DU ID when sent over E2AP
if git diff --quiet executables/nr-softmodem.c; then
    echo "No changes for executables/nr-softmodem.c"
else
    echo "Updating patch for nr-softmodem.c..."
    git diff executables/nr-softmodem.c >../install_patch_files/openairinterface5g/executables/nr-softmodem.c.patch
    git restore executables/nr-softmodem.c
    cp executables/nr-softmodem.c ../install_patch_files/openairinterface5g/executables/nr-softmodem.previous.c
    cp executables/nr-softmodem.c executables/nr-softmodem.c.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/executables/nr-softmodem.c.patch
fi

if git diff --quiet openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h; then
    echo "No changes for openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h"
else
    echo "Updating patch for ran_func_kpm_subs.h..."
    git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h >../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.patch
    git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.previous.h
    cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.previous
    git apply --verbose --ignore-whitespace ../install_patch_files/openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.h.patch
fi

cd ..

echo "Successfully updated patch files in the install_patch_files directory."

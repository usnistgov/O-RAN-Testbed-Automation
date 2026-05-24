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

E2AP_VERSION="E2AP_V3"  # E2AP_V1, E2AP_V2, E2AP_V3
KPM_VERSION="KPM_V3_00" # KPM_V2_03, KPM_V3_00

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

# The script directory respects symbolic links so that the gNB and UE can patch their own openairinterface5g
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
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

# Apply patches to OpenAirInterface
# Support SST values greater than 4
cd openairinterface5g
git restore openair3/UICC/pdu_session.c
if [ ! -f "openair3/UICC/pdu_session.c.previous" ]; then
    cp openair3/UICC/pdu_session.c openair3/UICC/pdu_session.c.previous
    cp openair3/UICC/pdu_session.c.previous "$PARENT_DIR/install_patch_files/openairinterface5g/openair3/UICC/pdu_session.previous.c"
fi
echo "Patching pdu_session.c to support SST values greater than 4..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface5g/openair3/UICC/pdu_session.c.patch"
cd ..

# This patch adds support for Linux Mint and Ubuntu 20.04
cd openairinterface5g
git restore cmake_targets/tools/build_helper
if [ ! -f "cmake_targets/tools/build_helper.previous" ]; then
    cp cmake_targets/tools/build_helper cmake_targets/tools/build_helper.previous
    cp cmake_targets/tools/build_helper.previous "$PARENT_DIR/install_patch_files/openairinterface5g/cmake_targets/tools/build_helper.previous"
fi
echo "Patching build_helper to extend Linux support..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface5g/cmake_targets/tools/build_helper.patch"
cd ..

# This patch adds C++11 compatibility to the ZeroMQ ring buffer code
cd openairinterface5g
git restore radio/zmq/ring_buffer.cpp
if [ ! -f "radio/zmq/ring_buffer.cpp.previous" ]; then
    cp radio/zmq/ring_buffer.cpp radio/zmq/ring_buffer.cpp.previous
    cp radio/zmq/ring_buffer.cpp.previous "$PARENT_DIR/install_patch_files/openairinterface5g/radio/zmq/ring_buffer.previous.cpp"
fi
echo "Patching ring_buffer.cpp for C++11 compatibility..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface5g/radio/zmq/ring_buffer.cpp.patch"
cd ..

cd openairinterface5g
git restore radio/zmq/zmq_imported.cpp
if [ ! -f "radio/zmq/zmq_imported.cpp.previous" ]; then
    cp radio/zmq/zmq_imported.cpp radio/zmq/zmq_imported.cpp.previous
    cp radio/zmq/zmq_imported.cpp.previous "$PARENT_DIR/install_patch_files/openairinterface5g/radio/zmq/zmq_imported.previous.cpp"
fi
echo "Patching zmq_imported.cpp for C++11 compatibility..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface5g/radio/zmq/zmq_imported.cpp.patch"
cd ..

cd openairinterface5g
git restore radio/zmq/zmq_imported.h
if [ ! -f "radio/zmq/zmq_imported.h.previous" ]; then
    cp radio/zmq/zmq_imported.h radio/zmq/zmq_imported.h.previous
    cp radio/zmq/zmq_imported.h.previous "$PARENT_DIR/install_patch_files/openairinterface5g/radio/zmq/zmq_imported.previous.h"
fi
echo "Patching zmq_imported.h for C++11 compatibility..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface5g/radio/zmq/zmq_imported.h.patch"
cd ..

# Patch nr_nas_msg.c for OpenSSL 1.1.x build compatibility (Ubuntu 20.04)
cd openairinterface5g
git restore openair3/NAS/NR_UE/nr_nas_msg.c
if [ ! -f "openair3/NAS/NR_UE/nr_nas_msg.c.previous" ]; then
    cp openair3/NAS/NR_UE/nr_nas_msg.c openair3/NAS/NR_UE/nr_nas_msg.c.previous
    cp openair3/NAS/NR_UE/nr_nas_msg.c.previous "$PARENT_DIR/install_patch_files/openairinterface5g/openair3/NAS/NR_UE/nr_nas_msg.previous.c"
fi
echo "Patching nr_nas_msg.c for OpenSSL 1.1.x build compatibility..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface5g/openair3/NAS/NR_UE/nr_nas_msg.c.patch"
cd ..

# This patch fixes the bug where the gNB ID was swapped with the DU ID when sent over E2AP
cd openairinterface5g
git restore executables/nr-softmodem.c
if [ ! -f "executables/nr-softmodem.c.previous" ]; then
    cp executables/nr-softmodem.c executables/nr-softmodem.c.previous
    cp executables/nr-softmodem.c.previous "$PARENT_DIR/install_patch_files/openairinterface5g/executables/nr-softmodem.previous.c"
fi
echo "Patching nr-softmodem.c to fix bug with gNB ID handling for DUs and CUs..."
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/openairinterface5g/executables/nr-softmodem.c.patch"
cd ..

echo
echo "Successfully patched OpenAirInterface."

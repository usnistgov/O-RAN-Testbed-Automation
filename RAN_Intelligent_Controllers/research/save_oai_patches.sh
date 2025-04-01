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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR/../../OpenAirInterface_Testbed"

cd User_Equipment/openairinterface5g
git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c >../install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.patch
git diff openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c >../install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.patch
git diff openair2/LAYER2/NR_MAC_gNB/main.c >../install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/main.c.patch
git diff openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h >../install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.patch
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c "$SCRIPT_DIR/PATCHED_OAI_FILES"
cp openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c "$SCRIPT_DIR/PATCHED_OAI_FILES"
cp openair2/LAYER2/NR_MAC_gNB/main.c "$SCRIPT_DIR/PATCHED_OAI_FILES"
cp openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h "$SCRIPT_DIR/PATCHED_OAI_FILES"
cd ../..

cd RAN_Intelligent_Controllers/Flexible-RIC/flexric/
git diff examples/xApp/c/monitor/xapp_kpm_moni.c >../install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni.c.patch
git diff examples/xApp/c/monitor/CMakeLists.txt >../install_patch_files/flexric/examples/xApp/c/monitor/CMakeLists.txt.patch
cp examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv.c ../install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv.c
cp examples/xApp/c/monitor/xapp_kpm_moni.c "$SCRIPT_DIR/PATCHED_OAI_FILES"
cp examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv.c "$SCRIPT_DIR/PATCHED_OAI_FILES"
cp examples/xApp/c/monitor/CMakeLists.txt "$SCRIPT_DIR/PATCHED_OAI_FILES"

cd "$SCRIPT_DIR/../.."

# if [ ! -f "NIST Commercial Product Disclaimer.md" ]; then
#     echo "Wrong directory"
#     pwd
#     ls
#     exit
# fi

# # Apply global format

# if ! command -v shfmt &>/dev/null; then
#     echo "Package \"shfmt\" not found, installing..."
#     sudo apt-get install -y shfmt
# fi
# find . -type f -name "*.sh" -exec shfmt -i 4 -w {} +
# git restore *.previous.sh

# sudo apt-get install -y dos2unix
# find . -type f -exec dos2unix {} \;

# find . -exec chmod 775 {} \;
# chmod 644 "LICENSE"
# chmod 644 "NIST Commercial Product Disclaimer.md"
# chmod 644 "NIST Software Disclaimer.md"

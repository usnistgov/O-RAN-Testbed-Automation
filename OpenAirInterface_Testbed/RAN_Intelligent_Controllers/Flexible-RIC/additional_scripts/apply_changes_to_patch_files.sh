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
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if [ ! -d flexric ]; then
    echo "FlexRIC directory not found. Please ensure you are in the correct parent directory, and that the mosaic5g/flexric repository has been cloned."
    exit 1
fi

if [ ! -d install_patch_files ]; then
    mkdir install_patch_files
fi

cd flexric/

# Update the patch files
git diff examples/xApp/c/monitor/xapp_kpm_moni.c >../install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni.c.patch
git diff examples/xApp/c/monitor/CMakeLists.txt >../install_patch_files/flexric/examples/xApp/c/monitor/CMakeLists.txt.patch
cp examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv.c ../install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv.c
cp examples/xApp/c/monitor/xapp_kpm_moni_write_to_influxdb.c ../install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni_write_to_influxdb.c

# Update the previous versions of the files
git restore examples/xApp/c/monitor/xapp_kpm_moni.c
cp examples/xApp/c/monitor/xapp_kpm_moni.c ../install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni.previous.c
cp examples/xApp/c/monitor/xapp_kpm_moni.c examples/xApp/c/monitor/xapp_kpm_moni.c.previous
git apply --verbose --ignore-whitespace ../install_patch_files/flexric/examples/xApp/c/monitor/xapp_kpm_moni.c.patch

git restore examples/xApp/c/monitor/CMakeLists.txt
cp examples/xApp/c/monitor/CMakeLists.txt ../install_patch_files/flexric/examples/xApp/c/monitor/CMakeLists.previous.txt
cp examples/xApp/c/monitor/CMakeLists.txt examples/xApp/c/monitor/CMakeLists.txt.previous
git apply --verbose --ignore-whitespace ../install_patch_files/flexric/examples/xApp/c/monitor/CMakeLists.txt.patch

cd ..

echo "Successfully created patch files in the FlexRIC/install_patch_files directory."

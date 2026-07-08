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

APPLY_PATCHES=true
DEBUG_SYMBOLS=false
RUN_TESTS=false

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ ! -d "ocudu" ]; then
    echo "ERROR: OCUDU repository not found. Please run full_install.sh first."
    exit 1
fi

if [ "$APPLY_PATCHES" = true ]; then
    echo "Patching OCUDU..."
    ./install_scripts/apply_patches.sh
fi

echo
echo
echo "Rebuilding Next Generation Node B (OCUDU)..."

cd ocudu
mkdir -p build
cd build
CMAKE_FLAGS="-DENABLE_WERROR=OFF"
if [[ "$DEBUG_SYMBOLS" == "true" ]]; then
    CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Debug"
fi

if [[ "$RUN_TESTS" == "true" ]]; then
    CMAKE_FLAGS="$CMAKE_FLAGS -DBUILD_TESTING=ON"
else
    CMAKE_FLAGS="$CMAKE_FLAGS -DBUILD_TESTING=OFF"
fi

cmake ../ $CMAKE_FLAGS
cmake --build . -j"$(nproc)"
if [[ "$RUN_TESTS" == "true" ]]; then
    ctest -j$(nproc)
fi
sudo cmake --install .
sudo ldconfig

cd "$SCRIPT_DIR"

echo "Successfully rebuilt OCUDU gNodeB."

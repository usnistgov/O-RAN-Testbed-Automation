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

DEBUG_SYMBOLS=false
RUN_TESTS=false

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

echo
echo
echo "Rebuilding User Equipment (srsRAN_4G)..."

if [ ! -d "srsRAN_4G" ]; then
    echo "ERROR: srsRAN_4G source directory not found."
    echo "Run full_install.sh before running rebuild_code.sh."
    exit 1
fi

cd srsRAN_4G

BOOST_VERSION=$(dpkg -s libboost-dev | grep '^Version:' | awk '{print $2}' | cut -d. -f1,2)
if [[ $(echo -e "$BOOST_VERSION\n1.89" | sort -V | head -n1) == "1.89" ]]; then # If version 1.89 or higher
    # Remove system from list of components since no longer available (https://www.boost.org/doc/libs/latest/libs/system/doc/html/system.html#changes_in_boost_1_89)
    sed -i 's/list(APPEND BOOST_REQUIRED_COMPONENTS "system")/#list(APPEND BOOST_REQUIRED_COMPONENTS "system")/g' CMakeLists.txt
fi

mkdir -p build
cd build

SUPPRESS_WARNINGS="-Wno-error=array-bounds -Wno-error=unused-but-set-variable -Wno-error=unused-function -Wno-error=unused-parameter -Wno-error=unused-result -Wno-error=unused-variable -Wno-error=all -Wno-return-type"

CMAKE_FLAGS="-DENABLE_WERROR=OFF"
if [[ "$DEBUG_SYMBOLS" == "true" ]]; then
    CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Debug"
fi

if [[ "$RUN_TESTS" == "true" ]]; then
    CMAKE_FLAGS="$CMAKE_FLAGS -DBUILD_TESTING=ON"
else
    CMAKE_FLAGS="$CMAKE_FLAGS -DBUILD_TESTING=OFF"
fi

cmake .. -DCMAKE_CXX_FLAGS="$SUPPRESS_WARNINGS" $CMAKE_FLAGS
cmake --build . -j"$(nproc)"
if [[ "$RUN_TESTS" == "true" ]]; then
    ctest -j"$(nproc)"
fi
sudo cmake --install .
sudo ldconfig

cd "$SCRIPT_DIR"

echo "Successfully rebuilt srsRAN_4G User Equipment."
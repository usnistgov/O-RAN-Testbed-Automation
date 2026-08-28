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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLEXRIC_DIR="${FLEXRIC_DIR:-$SCRIPT_DIR/flexric}"
BUILD_DIR="${FLEXRIC_BUILD_DIR:-$FLEXRIC_DIR/build}"
TEST_PREFIX="${FLEXRIC_TEST_PREFIX:-$BUILD_DIR/flexric_libraries}"
JOBS="${JOBS:-$(nproc)}"
E2AP_VERSION="${E2AP_VERSION:-E2AP_V3}"
KPM_VERSION="${KPM_VERSION:-KPM_V3_00}"
XAPP_DB="${XAPP_DB:-NONE_XAPP}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
TEST_NEAR_RIC_IP="${FLEXRIC_TEST_NEAR_RIC_IP:-127.0.0.200}"

if [ ! -f "$FLEXRIC_DIR/CMakeLists.txt" ]; then
    echo "ERROR: FlexRIC CMakeLists.txt not found at $FLEXRIC_DIR" >&2
    exit 1
fi

CMAKE_ARGS=(
    -S "$FLEXRIC_DIR"
    -B "$BUILD_DIR"
    -DUNIT_TEST=TRUE
    -DXAPP_DB="$XAPP_DB"
    -DE2AP_VERSION="$E2AP_VERSION"
    -DKPM_VERSION="$KPM_VERSION"
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"
    -DCMAKE_INSTALL_PREFIX="$TEST_PREFIX"
)

ASN1C_PATH="${ASN1C_EXEC_PATH:-}"
if [ -z "$ASN1C_PATH" ] && [ -x /opt/asn1c/bin/asn1c ]; then
    ASN1C_PATH=/opt/asn1c/bin/asn1c
fi
if [ -z "$ASN1C_PATH" ]; then
    ASN1C_PATH="$(command -v asn1c || true)"
fi
if [ -n "$ASN1C_PATH" ]; then
    CMAKE_ARGS+=(
        -DASN1C_EXEC="$ASN1C_PATH"
        -DASN1C_EXEC_PATH="$ASN1C_PATH"
    )
fi

echo "Configuring FlexRIC tests in $BUILD_DIR..."
cmake "${CMAKE_ARGS[@]}"

echo "Building FlexRIC and its test targets with $JOBS jobs..."
cmake --build "$BUILD_DIR" --parallel "$JOBS"

echo "Installing test runtime files under $TEST_PREFIX..."
cmake --install "$BUILD_DIR"

# Configure the service model paths to assume system-wide /usr/local installation
INTEGRATION_TESTS='^(Unit_test_Agent_RIC_xApp|Unit_test_nearRT_RIC)$'
echo "Running the upstream FlexRIC CTest suite..."
(
    cd "$BUILD_DIR"
    ctest --parallel "$JOBS" --output-on-failure --exclude-regex "$INTEGRATION_TESTS"
)

CONF_FILE="$TEST_PREFIX/etc/flexric/flexric.conf"
SERVICE_MODEL_DIR="$TEST_PREFIX/lib/flexric/"
if [ ! -f "$CONF_FILE" ] || [ ! -d "$SERVICE_MODEL_DIR" ]; then
    echo "ERROR: FlexRIC test runtime files were not installed under $TEST_PREFIX" >&2
    exit 1
fi

TEST_WORK_DIR="$BUILD_DIR/test-runtime"
mkdir -p "$TEST_WORK_DIR"
TEST_CONF_FILE="$TEST_WORK_DIR/flexric.conf"
cp "$CONF_FILE" "$TEST_CONF_FILE"
sed -i "s/^NEAR_RIC_IP[[:space:]]*=.*/NEAR_RIC_IP = $TEST_NEAR_RIC_IP/" "$TEST_CONF_FILE"

echo "Running Unit_test_nearRT_RIC with the repository-local installation..."
(
    cd "$TEST_WORK_DIR"
    "$BUILD_DIR/test/agent-ric/test_near_ric" -c "$TEST_CONF_FILE" -p "$SERVICE_MODEL_DIR"
)

echo "Running Unit_test_Agent_RIC_xApp with the repository-local installation..."
(
    cd "$TEST_WORK_DIR"
    "$BUILD_DIR/test/agent-ric-xapp/test_ag_ric_xapp" -c "$TEST_CONF_FILE" -p "$SERVICE_MODEL_DIR"
)

# Also run the metrics factory test provided by the testbed
METRICS_FACTORY_TEST="$BUILD_DIR/examples/xApp/c/monitor/metrics_factory_test"
if [ ! -x "$METRICS_FACTORY_TEST" ]; then
    echo "ERROR: metrics_factory_test was not built at $METRICS_FACTORY_TEST" >&2
    exit 1
fi

echo "Running metrics_factory_test..."
"$METRICS_FACTORY_TEST"

echo
echo "Successfully passed all FlexRIC tests."

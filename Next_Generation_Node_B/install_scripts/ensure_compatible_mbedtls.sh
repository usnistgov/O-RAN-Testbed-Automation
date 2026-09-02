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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

MBEDTLS_MIN_VERSION="2.28.0"
MBEDTLS_TARGET_VERSION="2.28.10"
MBEDTLS_SOURCE_DIR="mbedtls-2.28.10"
MBEDTLS_INSTALL_DIR="/usr/local"

MBEDTLS_VERSION=$(dpkg-query -W -f='${Version}' libmbedtls-dev 2>/dev/null || true)

if [ -n "$MBEDTLS_VERSION" ] && dpkg --compare-versions "$MBEDTLS_VERSION" ge "$MBEDTLS_MIN_VERSION" && [ -f /usr/include/psa/crypto.h ]; then
    echo "Using system Mbed TLS ${MBEDTLS_VERSION}."
else
    if [ ! -f "${MBEDTLS_INSTALL_DIR}/include/psa/crypto.h" ]; then
        echo "Installing Mbed TLS ${MBEDTLS_TARGET_VERSION}..."

        sudo apt-get install -y git cmake build-essential
        rm -rf "$MBEDTLS_SOURCE_DIR"

        git clone --recursive --depth 1 --branch "mbedtls-${MBEDTLS_TARGET_VERSION}" https://github.com/Mbed-TLS/mbedtls.git "$MBEDTLS_SOURCE_DIR"

        cmake -S "$MBEDTLS_SOURCE_DIR" -B "$MBEDTLS_SOURCE_DIR/build" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${MBEDTLS_INSTALL_DIR}" -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF -DUSE_STATIC_MBEDTLS_LIBRARY=ON -DUSE_SHARED_MBEDTLS_LIBRARY=OFF
        cmake --build "$MBEDTLS_SOURCE_DIR/build" -j"$(nproc)"
        sudo cmake --install "$MBEDTLS_SOURCE_DIR/build"
    fi

    export MBEDTLS_DIR="${MBEDTLS_INSTALL_DIR}"
    echo "Using Mbed TLS ${MBEDTLS_TARGET_VERSION} from ${MBEDTLS_INSTALL_DIR}."
fi

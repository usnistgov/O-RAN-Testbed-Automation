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

echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

# Check if k9s is already installed
if command -v k9s &>/dev/null; then
    echo "Already installed k9s, skipping."
    exit 0
fi

echo "Downloading and extracting k9s..."

# Create and navigate to the installation directory
mkdir -p "$HOME/k9s-installation"
cd "$HOME/k9s-installation"

# Determine the processor architecture
ARCH_SUFFIX=""
case $(uname -m) in
"x86_64")
    ARCH_SUFFIX="Linux_amd64"
    ;;
"aarch64")
    ARCH_SUFFIX="Linux_arm64"
    ;;
"armv7l")
    ARCH_SUFFIX="Linux_armv7"
    ;;
"ppc64le")
    ARCH_SUFFIX="Linux_ppc64le"
    ;;
"s390x")
    ARCH_SUFFIX="Linux_s390x"
    ;;
*)
    echo "Unsupported architecture: $(uname -m)"
    ;;
esac

# Construct the download URL using the determined architecture suffix
DOWNLOAD_URL="https://github.com/derailed/k9s/releases/latest/download/k9s_${ARCH_SUFFIX}.tar.gz"

# Download and check if the curl command was successful
if curl -fLO "$DOWNLOAD_URL"; then
    tar -xzf k9s_${ARCH_SUFFIX}.tar.gz
    sudo mv k9s /usr/local/bin
    rm k9s_${ARCH_SUFFIX}.tar.gz
    echo "Successfully installed k9s."
else
    echo "Failed to download k9s for the architecture: ${ARCH_SUFFIX}"
    # Clean up the installation directory if the download fails
    cd ..
    rm -rf "$HOME/k9s-installation"
fi

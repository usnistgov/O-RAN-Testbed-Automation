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

# Uninstall yq with: sudo rm -rf /usr/bin/yq
if command -v yq &>/dev/null; then
    echo "Already installed yq, skipping."
    exit 0
fi

echo "Installing yq..."

# Determine the processor architecture
ARCH_SUFFIX=""
case $(uname -m) in
"x86_64")
    ARCH_SUFFIX="linux_amd64"
    ;;
"aarch64")
    ARCH_SUFFIX="linux_arm64"
    ;;
"armv7l" | "armv6l")
    ARCH_SUFFIX="linux_arm"
    ;;
"i386" | "i686")
    ARCH_SUFFIX="linux_386"
    ;;
"ppc64le")
    ARCH_SUFFIX="linux_ppc64le"
    ;;
"s390x")
    ARCH_SUFFIX="linux_s390x"
    ;;
"mips")
    ARCH_SUFFIX="linux_mips"
    ;;
"mips64")
    ARCH_SUFFIX="linux_mips64"
    ;;
"mips64el" | "mips64le")
    ARCH_SUFFIX="linux_mips64le"
    ;;
"mipsel" | "mipsle")
    ARCH_SUFFIX="linux_mipsle"
    ;;
*)
    echo "Unsupported architecture for yq: $(uname -m)"
    exit 1
    ;;
esac

YQ_URL="https://github.com/mikefarah/yq/releases/latest/download/yq_${ARCH_SUFFIX}.tar.gz"

# Create a temporary directory for the download
TEMP_DIR=$(mktemp -d)
TEMP_PATH="$TEMP_DIR/yq.tar.gz"

echo "Downloading yq from $YQ_URL..."
HTTP_STATUS=$(curl -L -w "%{http_code}" -o "$TEMP_PATH" "$YQ_URL")
if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "Extracting yq..."
    tar -xzf "$TEMP_PATH" -C "$TEMP_DIR"
    if [ -f "$TEMP_DIR/./yq_$ARCH_SUFFIX" ]; then
        sudo mv "$TEMP_DIR/./yq_$ARCH_SUFFIX" /usr/local/bin/yq
        sudo chmod +x /usr/local/bin/yq
        echo "Successfully installed yq."
    else
        echo "Failed to extract yq from the tar.gz."
        exit 1
    fi
else
    sudo rm -rf "$TEMP_DIR"
    echo "Failed to download yq for the architecture: ${ARCH_SUFFIX}, HTTP status was $HTTP_STATUS."
    exit 1
fi

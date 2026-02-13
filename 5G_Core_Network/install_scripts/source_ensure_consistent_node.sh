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

# Usage: source source_ensure_consistent_node.sh [NODE_MAJOR_VERSION]
# WARNING: This script is designed to be sourced to allow nvm environment changes to persist. If executed directly, it will run in a subshell and nvm changes will be lost.

NODE_MAJOR=${1:-22}
APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"

if ! [[ "$NODE_MAJOR" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Node version \"$NODE_MAJOR\" must be an integer (default is 22)." >&2
    return 1 2>/dev/null || exit 1
fi

# Check if nvm is installed and available
if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        source "$NVM_DIR/nvm.sh"
    fi
fi

# Detect Node.js version
CURRENT_VERSION=0
if command -v node &>/dev/null; then
    RAW_VERSION="$(node -p "process.versions.node" 2>/dev/null || true)"
    MAJOR_VERSION=$(echo "$RAW_VERSION" | cut -d. -f1)
    if [[ "$MAJOR_VERSION" =~ ^[0-9]+$ ]]; then # Ensure it is an integer
        CURRENT_VERSION="$MAJOR_VERSION"
    fi
fi

# Use nvm if available, otherwise use system packages
if [ "$(type -t nvm 2>/dev/null || true)" = "function" ]; then
    if [ "$CURRENT_VERSION" -lt "$NODE_MAJOR" ]; then
        echo "Node.js version ($CURRENT_VERSION) is less than $NODE_MAJOR and nvm detected. Installing with nvm..."
        nvm install "$NODE_MAJOR"
        nvm use "$NODE_MAJOR"
        nvm alias default "$NODE_MAJOR"
    else
        echo "Node.js is already at compliant version $CURRENT_VERSION (managed by nvm)."
    fi
else
    NEEDS_INSTALL=false
    if ! command -v node &>/dev/null; then
        echo "Node.js not found."
        NEEDS_INSTALL=true
    elif [ "$CURRENT_VERSION" -lt "$NODE_MAJOR" ]; then
        echo "Node.js version $CURRENT_VERSION is less than $NODE_MAJOR."
        NEEDS_INSTALL=true
    fi

    if [ "$NEEDS_INSTALL" = true ]; then
        echo "Installing Node.js $NODE_MAJOR..."

        if ! command -v curl &>/dev/null || ! command -v gpg &>/dev/null; then
            sudo env $APTVARS apt-get update
            if ! sudo env $APTVARS apt-get install -y ca-certificates curl gnupg; then
                echo "Failed to install prerequisites"
                return 1 2>/dev/null || exit 1
            fi
        fi

        if command -v node &>/dev/null; then # Remove old version
            sudo apt-get purge -y nodejs npm || true
        fi

        # Clean up conflicting repository definitions
        sudo rm -f /etc/apt/sources.list.d/nodesource.list

        # Setup NodeSource
        if ! (
            set -o pipefail
            curl -fsSL https://deb.nodesource.com/setup_$NODE_MAJOR.x | sudo -E bash -
        ); then
            echo "Failed to setup NodeSource"
            return 1 2>/dev/null || exit 1
        fi

        # Preference
        sudo tee /etc/apt/preferences.d/nodesource >/dev/null <<'EOF'
Package: nodejs
Pin: origin deb.nodesource.com
Pin-Priority: 1001
EOF
        sudo apt-get update
        if ! sudo env $APTVARS apt-get install -y nodejs; then
            echo "Failed to install nodejs"
            return 1 2>/dev/null || exit 1
        fi
    else
        echo "Node.js is already at compliant version $CURRENT_VERSION (system package)."
    fi
fi

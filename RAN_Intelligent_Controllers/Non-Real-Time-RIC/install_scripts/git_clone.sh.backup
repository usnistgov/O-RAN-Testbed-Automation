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

URL=$1  # Required
NAME=$2 # Optional

# Validate input parameters
if [[ -z "$URL" ]]; then
    echo "Error: No URL provided."
    echo "Usage: $0 <URL> [name]"
    exit 1
fi
if [[ ! "$URL" == *.git ]]; then
    echo "Error: URL must end in .git"
    exit 1
fi
if [[ -z "$NAME" ]]; then
    NAME=$(basename "$URL" .git)
fi

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

CURRENT_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
HOME_DIR=$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")

if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get install -y jq
fi

# First check the directory containing install_scripts/, otherwise, use the home directory
if [ -f "$PARENT_DIR/commit_hashes.json" ]; then
    JSON_FILE="$PARENT_DIR/commit_hashes.json"
else
    JSON_FILE="$HOME_DIR/commit_hashes.json"
fi

cd "$CURRENT_DIR"

# Create the JSON file if it does not exist
if [[ ! -f "$JSON_FILE" ]]; then
    echo "{}" >$JSON_FILE
fi

# Remove the repository if it exists and is not a git repository
if [[ -d "$NAME" && ! -d "$NAME/.git" ]]; then
    echo "Removing $NAME directory because it is not a git repository..."
    sudo rm -rf $NAME
fi

# Verify that the repository is on the correct commit hash
if jq -e ".\"$URL\"[1]" $JSON_FILE &>/dev/null; then
    BRANCH=$(jq -r ".\"$URL\"[0]" $JSON_FILE)
    TARGET_COMMIT_HASH=$(jq -r ".\"$URL\"[1]" $JSON_FILE)

    # If the repository does not exist, clone it
    if [[ ! -d "$NAME" ]]; then
        if [[ ! -z "$BRANCH" ]]; then
            echo "Cloning $URL at branch $BRANCH..."
            git clone "$URL" "$NAME" -b $BRANCH
        else
            echo "Cloning $URL..."
            git clone "$URL" "$NAME"
        fi
    fi
    cd "$NAME"
    CURRENT_COMMIT_HASH=$(git rev-parse HEAD)

    if [[ ! -z "$TARGET_COMMIT_HASH" ]]; then
        if [[ ! "$CURRENT_COMMIT_HASH" == "$TARGET_COMMIT_HASH" ]]; then
            echo "Commit hashes: $CURRENT_COMMIT_HASH != $TARGET_COMMIT_HASH, switching..."
            git checkout "$TARGET_COMMIT_HASH"
            echo "Switched to commit $TARGET_COMMIT_HASH."
            cd ..
        else
            echo "Already at commit $TARGET_COMMIT_HASH."
        fi
    fi
    cd ..
else
    # Repository not found in JSON file, if the repository does not exist, clone it
    if [[ ! -d "$NAME" ]]; then
        echo "Cloning $URL..."
        git clone "$URL" "$NAME"
    fi
fi

echo "Repository $URL is cloned to $CURRENT_DIR/$NAME."
echo

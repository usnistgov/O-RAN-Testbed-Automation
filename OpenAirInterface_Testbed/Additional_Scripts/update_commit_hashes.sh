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

# This script updates the commit hash for each repository in the JSON file. It respects the first field in each repository's entry, which is the branch name. If the branch name is "", it fetches the default branch's latest commit hash instead.

set -e

# Modifies the needrestart configuration to suppress interactive prompts
if [ -d /etc/needrestart ]; then
    sudo install -d -m 0755 /etc/needrestart/conf.d
    sudo tee /etc/needrestart/conf.d/99-no-auto-restart.conf >/dev/null <<'EOF'
# Disable automatic restarts during apt operations
$nrconf{restart} = 'l';
EOF
    echo "Configured needrestart to list-only (no service restarts)."
fi

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if ! command -v jq &>/dev/null; then
    sudo apt-get update

    echo "Installing jq..."
    sudo $APTVARS apt-get install -y jq
fi

JSON_FILE="commit_hashes.json"
JSON_CONTENTS=$(jq '.' "$JSON_FILE")

# Go through each repository and update the commit hash
for REPOSITORY in $(jq 'keys[]' "$JSON_FILE" | tr -d '"'); do
    if [[ "$REPOSITORY" != *".git" ]]; then
        REPOSITORY_NEW="${REPOSITORY}.git"
        JSON_CONTENTS=$(jq ".[\"$REPOSITORY_NEW\"] = .[\"$REPOSITORY\"] | del(.[\"$REPOSITORY\"])" <<<"$JSON_CONTENTS")
        REPOSITORY="$REPOSITORY_NEW"
    fi
    BRANCH=$(jq -r ".[\"$REPOSITORY\"][0]" <<<"$JSON_CONTENTS")
    PREV_COMMIT_HASH=$(jq -r ".[\"$REPOSITORY\"][1]" <<<"$JSON_CONTENTS")

    if [[ -z "$BRANCH" ]]; then
        # Fetch the default branch's latest commit
        echo "Updating commit hash for $REPOSITORY..."
        COMMIT_HASH=$(git ls-remote "$REPOSITORY" HEAD | awk '{ print $1 }')
    else
        # Fetch the specified branch's latest commit
        echo "Updating commit hash for $REPOSITORY on branch $BRANCH..."
        COMMIT_HASH=$(git ls-remote "$REPOSITORY" "refs/heads/$BRANCH" | awk '{ print $1 }')
    fi

    if [[ -n "$COMMIT_HASH" ]]; then
        # Update the commit hash in the JSON structure
        JSON_CONTENTS=$(jq ".[\"$REPOSITORY\"][1] = \"$COMMIT_HASH\"" <<<"$JSON_CONTENTS")
        echo "    $COMMIT_HASH"
    else
        echo "    Failed to retrieve commit hash, skipping."
        echo
    fi
done

# Format the JSON for easier reading
FORMATTED_JSON_CONTENTS=$(echo "$JSON_CONTENTS" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\[\n    /[/g')
FORMATTED_JSON_CONTENTS=$(echo "$FORMATTED_JSON_CONTENTS" | sed -e ':a' -e 'N' -e '$!ba' -e 's/,\n    /, /g')
FORMATTED_JSON_CONTENTS=$(echo "$FORMATTED_JSON_CONTENTS" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n  ]/]/g')

echo "$FORMATTED_JSON_CONTENTS" >"$JSON_FILE"
echo "Successfully updated commit hashes."

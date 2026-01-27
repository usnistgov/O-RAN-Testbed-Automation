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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ -z "$RUNNER_TOKEN" ]; then
    echo "ERROR: Environment variable RUNNER_TOKEN is not set."
    echo "Please set RUNNER_TOKEN to your GitLab runner registration token. The token can be created for your project by doing the following:"
    echo "    - On your GitLab project, go to Settings > CI/CD > Runners"
    echo "    - Click the \"Create project runner\" button"
    echo "    - Check \"Run untagged jobs\" and write a description (e.g., \"NIST CI Runner\")"
    echo "    - Proceed, and it will show you the registration token starting with \"glrt-...\""
    echo "    - Run the command: export RUNNER_TOKEN=..."
    exit 1
fi

echo "Checking for existing GitLab runners to unregister..."
RUNNERS=$(gitlab-runner list 2>&1 | grep -E 'Executor' | sed 's|Executor.*||' | awk '{ gsub(/\033\[[0-9;]*[[:alpha:]]/, ""); sub(/[[:space:]]+$/, ""); print }')
if [ -n "$RUNNERS" ]; then
    echo "Currently registered runners:"
    printf '%s\n' "$RUNNERS"
    # Unregister each runner by name, preserving names with spaces
    while IFS= read -r RUNNER; do
        if [ -n "$RUNNER" ]; then
            echo "Unregistering runner: \"$RUNNER\""
            sudo gitlab-runner unregister --name "$RUNNER" || true
        fi
    done <<<"$RUNNERS"
else
    echo "No runners are currently registered."
fi

echo "Creating symbolic link to config.toml in script directory..."
sudo rm -f config.toml
ln -s /etc/gitlab-runner/config.toml config.toml

if ! sudo grep -q "$RUNNER_TOKEN" config.toml; then
    sudo gitlab-runner register \
        --non-interactive \
        --url https://gitlab.nist.gov/gitlab \
        --token "$RUNNER_TOKEN" \
        --description "NIST CI Runner" \
        --executor "shell"
else
    echo "Runner with the provided token is already registered in config.toml."
fi

# Configure the runner to use 'sudo -n true' as a pre_build_script to ensure sudo permissions
if ! sudo grep -qE '^\s*pre_clone_script\s*=' /etc/gitlab-runner/config.toml; then
    echo "Adding pre_clone_script to config.toml..."
    sudo sed -i -E '1,/^[[:space:]]*executor = "shell"/{s/^([[:space:]]*)executor = "shell"/\1pre_clone_script = "sudo chown --recursive gitlab-runner:gitlab-runner . \&\& git config --global --add safe.directory '\''*'\''"\n\1executor = "shell"/}' /etc/gitlab-runner/config.toml
fi

if ! sudo grep -qE '^\s*pre_build_script\s*=' /etc/gitlab-runner/config.toml; then
    echo "Adding pre_build_script to config.toml..."
    sudo sed -i -E '1,/^\s*executor = "shell"/{s/^([[:space:]]*)executor = "shell"/\1pre_build_script = "sudo -n true"\n\1executor = "shell"/}' /etc/gitlab-runner/config.toml
fi

echo "Successfully registered GitLab runner."

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

# Stop any previous gitlab-runner instances
if pgrep -x "gitlab-runner" >/dev/null; then
    echo "Stopping all running gitlab-runner processes..."
    sudo pkill -9 gitlab-runner
fi

# Run a sudo command every minute to ensure script execution without user interaction
./start_sudo_refresh.sh

# Ensure the sudo timeout refresher is stopped on script exit
trap './stop_sudo_refresh.sh' EXIT SIGINT SIGTERM SIGQUIT

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Clean up previous artifacts
sudo rm -rf builds
sudo rm -rf cache

# Create sudoers file for gitlab-runner to allow the CI to run sudo interactively
SUDOERS_FILE="/etc/sudoers.d/90-gitlab-runner"
SUDOERS_LINE="gitlab-runner ALL=(ALL) NOPASSWD: ALL"
if ! sudo grep -Eqs '^\s*gitlab-runner\s+ALL=\(ALL\)\s+NOPASSWD:\s+ALL\s*$' "$SUDOERS_FILE" 2>/dev/null; then
    echo "$SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    sudo visudo -cf "$SUDOERS_FILE"
fi

# Configure git to avoid "fatal: detected dubious ownership in repository" errors
git config --global --add safe.directory '*'

echo "Starting GitLab Runner..."
sudo gitlab-runner run --config "/etc/gitlab-runner/config.toml"

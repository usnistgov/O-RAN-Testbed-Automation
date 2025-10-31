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

# Stop user-mode runner if running
systemctl --user stop gitlab-runner 2>/dev/null || true
pkill -f "gitlab-runner run" 2>/dev/null || true

# Stop and disable system service
sudo systemctl disable --now gitlab-runner 2>/dev/null || true

# Unregister all runners
sudo gitlab-runner unregister --all-runners 2>/dev/null || true
gitlab-runner unregister --all-runners 2>/dev/null || true

# Remove package and dependencies
sudo apt purge -y gitlab-runner
sudo apt autoremove -y

# Remove GitLab Runner apt repo and keys
sudo rm -f /etc/apt/sources.list.d/*gitlab-runner*.list
sudo rm -f /etc/apt/trusted.gpg.d/*gitlab*.gpg /etc/apt/keyrings/*gitlab*.gpg
sudo apt update

# Delete leftover data, config, and logs
sudo rm -rf /etc/gitlab-runner /var/lib/gitlab-runner /var/log/gitlab-runner
rm -rf ~/.gitlab-runner

# Remove service account
sudo userdel -r gitlab-runner 2>/dev/null || true

sudo rm -rf $HOME/.gitlab-runner
sudo rm -f $SCRIPT_DIR/config.toml

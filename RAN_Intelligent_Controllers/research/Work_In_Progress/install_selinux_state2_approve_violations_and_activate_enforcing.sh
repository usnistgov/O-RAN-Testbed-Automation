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

echo "# Script: $(realpath "$0") $@"

echo
echo "Currently active SELinux policy modules:"
sudo semodule -l | awk '{print $1}' | awk '{print length, $0}' | sort -nr | cut -d " " -f2 | awk '{printf "%s ", $0}'

echo
echo
echo "Collecting SELinux denials..."

# Prompt the user to name the SELinux policy module
read -p "Enter a unique name for the SELinux policy module (i.e. what you did and want to allow the system to no longer enforce, or type \"\" to skip): " MODULE_NAME

if [[ ! -z "$MODULE_NAME" ]]; then
    if [[ ! "$MODULE_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "Invalid or no module name entered. Names must be non-empty and can only contain letters, numbers, and underscores."
        exit 1
    fi

    # Generate the policy module with the given name and save it in the home directory
    mkdir -p $HOME/selinux_modules
    BACKUP_DIR=$(pwd)
    cd "$HOME/selinux_modules"
    sudo ausearch -m avc -ts recent --raw | audit2allow -M "${MODULE_NAME}"
    cd "$BACKUP_DIR"

    echo "Installing the generated SELinux policy module named ${MODULE_NAME}."
    sudo semodule -i $HOME/selinux_modules/${MODULE_NAME}.pp
fi

echo "Do you want to proceed to set SELinux to enforcing mode? (Y/n)"
read -r CONFIRM
CONFIRM=$(echo "${CONFIRM:-y}" | tr '[:upper:]' '[:lower:]')
if [[ "$CONFIRM" == "y" || "$CONFIRM" == "yes" ]]; then
    sudo setenforce 1
    sudo sed -i 's/^SELINUX=permissive$/SELINUX=enforcing/' /etc/selinux/config
    echo "SELinux has been set to enforcing mode."
else
    echo "SELinux remains in permissive mode. Run this script again when ready to switch to enforcing mode."
fi

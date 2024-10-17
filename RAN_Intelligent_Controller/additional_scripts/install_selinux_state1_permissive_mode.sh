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

# Check if SELinux is already installed and active
if command -v sestatus >/dev/null 2>&1; then
    selinux_status=$(sestatus | grep "SELinux status" | awk '{print $3}')
    if [ "$selinux_status" = "enabled" ]; then
        echo "Setting SELinux to permissive mode..."
        sudo setenforce 0
        if [ $? -ne 0 ]; then
            echo "Failed to set SELinux to permissive mode. Exiting."
            exit 1
        fi
        echo "SELinux was successfully set to permissive mode."
        exit 0
    fi
fi

# Disable AppArmor if it's active and enabled
if systemctl is-active --quiet apparmor && systemctl is-enabled --quiet apparmor; then
    echo "AppArmor is active and enabled. Disabling now..."
    sudo systemctl disable apparmor --now
    if [ $? -eq 0 ]; then
        echo "AppArmor has been disabled."
    else
        echo "Failed to disable AppArmor. Exiting."
        exit 1
    fi
fi

# Update package lists
sudo apt-get update
if [ $? -ne 0 ]; then
    echo "Failed to update package lists. Exiting."
    exit 1
fi

echo "Installing SELinux packages..."
sudo apt-get install -y policycoreutils selinux-utils selinux-basics
sudo apt-get install -y auditd # Linux Security Auditing Tool
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sddm # Simple Desktop Display Manager (used for GUI login)
if [ $? -ne 0 ]; then
    echo "Failed to install SELinux packages. Exiting."
    exit 1
fi

echo "Activating SELinux..."
sudo selinux-activate
if [ $? -ne 0 ]; then
    echo "Failed to activate SELinux. Exiting."
    exit 1
fi

echo "Setting SELinux to permissive mode..."
sudo setenforce 0
if [ $? -ne 0 ]; then
    echo "Failed to set SELinux to permissive mode. Exiting."
    exit 1
fi

echo "Checking current SELinux mode..."
CURRENT_MODE=$(getenforce)
if [ "$CURRENT_MODE" != "Permissive" ]; then
    echo "SELinux is not in permissive mode. Configuring to start in permissive mode on system boot..."
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sudo setenforce 0
else
    echo "SELinux is already in permissive mode."
fi

echo "SELinux installation and configuration complete. Please reboot your system."

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Path to the systemd service file for containerd
service_path="/etc/systemd/system/containerd.service"

# Check if the custom service file exists
if [ ! -f "$service_path" ]; then
    # Copy the default service file to /etc/systemd/system
    echo "Copying default containerd service file to /etc/systemd/system..."
    sudo cp /lib/systemd/system/containerd.service "$service_path"
fi

# Check if LimitNOFILE is already set
if grep -q "LimitNOFILE" "$service_path"; then
    echo "Updating existing LimitNOFILE setting..."
    # Update the existing LimitNOFILE setting
    sudo sed -i '/LimitNOFILE/c\LimitNOFILE=1048576' "$service_path"
else
    echo "Adding new LimitNOFILE setting..."
    # Add a new LimitNOFILE setting under the [Service] section
    sudo sed -i '/\[Service\]/a LimitNOFILE=1048576' "$service_path"
fi

# Reload systemd to apply changes and restart containerd
echo "Reloading systemd and restarting containerd service..."
sudo systemctl daemon-reload
sudo systemctl restart containerd

echo "containerd file descriptor limit updated successfully."

# Consider adding the following to /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#[Service]
#LimitNOFILE=1048576
# Then restart kubelet with the following:
# sudo systemctl daemon-reload
# sudo systemctl restart kubelet
# Monitor the logs with k9s
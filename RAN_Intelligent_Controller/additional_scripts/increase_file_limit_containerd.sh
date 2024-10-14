#!/bin/bash
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
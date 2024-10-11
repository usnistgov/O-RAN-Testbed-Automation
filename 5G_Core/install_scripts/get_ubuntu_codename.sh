#!/bin/bash
echo "# Script: $(realpath $0)..."

# Try to extract UBUNTU_CODENAME from /etc/os-release
UBUNTU_CODENAME=$(grep -oP '^UBUNTU_CODENAME=\K.*' /etc/os-release 2>/dev/null)

# If not found, try to extract VERSION_CODENAME as a fallback
if [[ -z "$UBUNTU_CODENAME" ]]; then
    UBUNTU_CODENAME=$(grep -oP '^VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null)
fi

# Check if UBUNTU_CODENAME is still empty
if [[ -z "$UBUNTU_CODENAME" ]]; then
    echo "Error: Ubuntu codename not found in /etc/os-release."
    exit 1
fi

echo "$UBUNTU_CODENAME"


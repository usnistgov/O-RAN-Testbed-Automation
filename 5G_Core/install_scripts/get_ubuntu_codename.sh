#!/bin/bash

# Try to extract UBUNTU_CODENAME from /etc/os-release
ubuntu_codename=$(grep -oP '^UBUNTU_CODENAME=\K.*' /etc/os-release 2>/dev/null)

# If not found, try to extract VERSION_CODENAME as a fallback
if [[ -z "$ubuntu_codename" ]]; then
    ubuntu_codename=$(grep -oP '^VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null)
fi

# Check if ubuntu_codename is still empty
if [[ -z "$ubuntu_codename" ]]; then
    echo "Error: Ubuntu codename not found in /etc/os-release."
    exit 1
fi

echo "$ubuntu_codename"


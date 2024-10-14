#!/bin/bash
echo "# Script: $(realpath $0)..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

echo "Updating system-wide file descriptor limits..."
# Update sysctl settings immediately
sysctl -w fs.file-max=1000000
sysctl -w fs.inotify.max_user_watches=524288

# Update security limits if not already set
if ! grep -q "* soft nofile" /etc/security/limits.conf; then
    echo "* soft nofile 1000000" >> /etc/security/limits.conf
fi
if ! grep -q "* hard nofile" /etc/security/limits.conf; then
    echo "* hard nofile 1000000" >> /etc/security/limits.conf
fi

# Apply file descriptor limits to all running shell sessions
for pid in $(pgrep -x bash); do
    prlimit --pid $pid --nofile=1000000:1000000
done

echo "System limits updated. Reboot or restart your services to ensure all limits are fully applied."

#!/bin/bash
echo "# Script: $(realpath $0)..."

# Simple script to keep sudo active by refreshing it every minute
while true; do
    sudo -v
    sleep 60
done
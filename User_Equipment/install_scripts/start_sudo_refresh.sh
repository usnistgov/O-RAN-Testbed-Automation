#!/bin/bash

if [ ! -f "full_install.sh" ]; then
    echo "You must run this script from the main directory with full_install.sh"
    exit 0
fi

# Check if the user is not root
if [ "$USER" != "root" ]; then
    # Start the sudo-stay-validated.sh script in the background
    nohup ./install_scripts/sudo_stay_validated.sh > /dev/null 2>&1 &
    echo "Sudo refresh process started with PID $!"
else
    echo "You are root, no need to refresh sudo timeout."
fi
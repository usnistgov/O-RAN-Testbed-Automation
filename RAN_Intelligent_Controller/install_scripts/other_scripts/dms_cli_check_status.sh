#!/bin/bash

# Check if there is a container running with the command /chartmuseum
if docker ps | grep "/chartmuseum" > /dev/null; then
    echo "The xApp onboarding tool, dms_cli, is RUNNING."
else
    echo "The xApp onboarding tool, dms_cli, is STOPPED."
fi

echo
docker ps
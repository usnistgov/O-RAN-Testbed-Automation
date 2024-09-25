#!/bin/bash

# Attempt to kill the process
pkill -f "sudo_stay_validated.sh" || echo "No process found to stop."
echo "Sudo refresh process stopped or was not running."
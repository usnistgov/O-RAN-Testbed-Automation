#!/bin/bash

if pgrep -x "srsue" > /dev/null; then
    echo "Already running srsue."
else
    if [ ! -f "configs/ue.conf" ]; then
        echo "Configuration was not found for srsUE. Please run ./generate_configurations.sh first."
        exit 1
    fi
    echo "Starting srsue..."
    sudo ./srsRAN_4G/build/srsue/src/srsue --config_file configs/ue.conf
fi

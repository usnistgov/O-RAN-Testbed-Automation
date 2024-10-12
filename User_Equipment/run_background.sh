#!/bin/bash

if ! ip netns list | grep -q "^ue1$"; then
    echo "Setting user equipment namespace..."
    sudo ip netns add ue1
fi

if pgrep -x "srsue" > /dev/null; then
    echo "Already running srsue."
else
    if [ ! -f "configs/ue.conf" ]; then
        echo "Configuration was not found for srsUE. Please run ./generate_configurations.sh first."
        exit 1
    fi
    echo "Starting srsue in background..."
    sudo nohup ./srsRAN_4G/build/srsue/src/srsue --config_file configs/ue.conf > logs/ue_stdout.txt 2>&1 &
    sleep 1
    ./is_running.sh
    sudo chown -R $USER:$USER logs
fi

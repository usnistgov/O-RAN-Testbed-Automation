#!/bin/bash

if pgrep -x "gnb" > /dev/null; then
    echo "Already running gnb."
else
    if [ ! -f "configs/gnb.yaml" ]; then
        echo "Configuration was not found for gNodeB. Please run ./generate_configurations.sh first."
        exit 1
    fi

    echo "Starting gnb in background..."
    mkdir -p logs
    sudo chown -R $USER:$USER logs
    sudo rm -rf logs/gnb.log
    sudo setsid srsRAN_Project/build/apps/gnb/gnb -c configs/gnb.yaml </dev/null >logs/gnb_stdout.txt 2>&1 &
    sleep 1
    ./is_running.sh
    sudo chown -R $USER:$USER logs
fi


#!/bin/bash

if pgrep -x "gnb" > /dev/null; then
    echo "Already running gnb."
else
    echo "Starting gnb..."
    mkdir -p logs
    sudo chown -R $USER:$USER logs
    sudo rm -rf /tmp/gnb.log
    srsRAN_Project/build/apps/gnb/gnb -c configs/gnb.yaml
fi


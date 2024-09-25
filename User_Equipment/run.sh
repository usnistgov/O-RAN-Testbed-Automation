#!/bin/bash

if pgrep -x "srsue" > /dev/null; then
    echo "Already running srsue."
else
    echo "Starting srsue..."
    sudo srsue --config_file configs/ue.conf
fi


#!/bin/bash

if pgrep -x "srsue" > /dev/null; then
    echo "User Equipment: RUNNING"
else
    echo "User Equipment: NOT RUNNING"
fi
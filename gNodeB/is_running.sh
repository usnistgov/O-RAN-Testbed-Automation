#!/bin/bash

if pgrep -x "gnb" > /dev/null; then
    echo "gNodeB: RUNNING"
else
    echo "gNodeB: NOT RUNNING"
fi
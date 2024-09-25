#!/bin/bash

echo "Checking status of 5G Core components..."
cd 5G_Core
./is_running.sh
cd ..

echo "Checking status of gNodeB..."
cd gNodeB
./is_running.sh
cd ..

echo "Checking status of User Equipment..."
cd User_Equipment
./is_running.sh
cd ..

echo "Script completed successfully."

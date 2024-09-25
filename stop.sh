#!/bin/bash

echo "Stopping User Equipment..."
cd User_Equipment
sudo ./stop.sh
cd ..

echo
echo "Stopping gNodeB..."
cd gNodeB
sudo ./stop.sh
cd ..

echo
echo "Stopping 5G Core components..."
cd 5G_Core
sudo ./stop.sh
cd ..

echo
echo "The stop script completed successfully."

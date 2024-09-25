#!/bin/bash

echo "Running 5G Core components..."
cd 5G_Core
./run.sh
cd ..

echo
echo "Running gNodeB..."
cd gNodeB
./run.sh
cd ..

echo
echo "Running User Equipment..."
cd User_Equipment
./run.sh
cd ..

#!/bin/bash

# Exit immediately if a command fails
set -e

echo "Generating Configurations for 5G Core components..."
cd 5G_Core
./generate_configurations.sh
cd ..

echo
echo "Generating Configuration for gNodeB..."
cd gNodeB
./generate_configurations.sh
cd ..

echo
echo "Generating Configuration for User Equipment..."
cd User_Equipment
./generate_configurations.sh
cd ..

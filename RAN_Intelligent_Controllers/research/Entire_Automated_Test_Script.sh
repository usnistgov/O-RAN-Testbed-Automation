#!/bin/bash
#
# NIST-developed software is provided by NIST as a public service. You may use,
# copy, and distribute copies of the software in any medium, provided that you
# keep intact this entire notice. You may improve, modify, and create derivative
# works of the software or any portion of the software, and you may copy and
# distribute such modifications or works. Modified works should carry a notice
# stating that you changed the software and should note the date and nature of
# any such change. Please explicitly acknowledge the National Institute of
# Standards and Technology as the source of the software.
#
# NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
# OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
# NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
# UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
# NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
# THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
# RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
#
# You are solely responsible for determining the appropriateness of using and
# distributing the software and you assume all risks associated with its use,
# including but not limited to the risks and costs of program errors, compliance
# with applicable laws, damage to or loss of data, programs or equipment, and
# the unavailability or interruption of operation. This software is not intended
# to be used in any situation where a failure could cause risk of injury or
# damage to property. The software developed by NIST employees is not subject to
# copyright protection within the United States.

# Exit immediately if a command fails
set -e

export DEBIAN_FRONTEND=noninteractive
# Modifies the needrestart configuration to suppress interactive prompts
if [ -f "/etc/needrestart/needrestart.conf" ]; then
    if ! grep -q "^\$nrconf{restart} = 'a';$" "/etc/needrestart/needrestart.conf"; then
        sudo sed -i "/\$nrconf{restart} = /c\$nrconf{restart} = 'a';" "/etc/needrestart/needrestart.conf"
        echo "Modified needrestart configuration to auto-restart services."
    fi
fi
export NEEDRESTART_SUSPEND=1

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git

# rm -rf O-RAN-Testbed-Init
if [ ! -d O-RAN-Testbed-Init ]; then
    git clone https://github.com/Simewu/O-RAN-Testbed-Init.git
fi
cd O-RAN-Testbed-Init

# # rm -rf O-RAN-Testbed-Automation
# if [ ! -d O-RAN-Testbed-Automation ]; then
#     git clone https://github.com/USNISTGOV/O-RAN-Testbed-Automation.git
# fi
# cd O-RAN-Testbed-Automation

# # rm -rf o-ran-testbed-init
# if [ ! -d o-ran-testbed-init ]; then
#     git clone https://gitlab.nist.gov/gitlab/wnd-oran/o-ran-testbed-init.git
# fi
# cd o-ran-testbed-init

# Update the commit hashes so that we're testing the latest version of each dependency
./Additional_Scripts/update_commit_hashes.sh

# Install the testbed
./full_install.sh -y

# Ensure that the components are stopped before running the tests
./stop.sh

echo
echo "Running tests for 5G_Core_Network..."
cd 5G_Core_Network/open5gs/build
if ! meson test -v; then
    echo "The Open5GS test cases failed."
    exit 1
fi
cd ../../..

echo
echo "Running tests for Next_Generation_Node_B..."
cd Next_Generation_Node_B/srsRAN_Project/build
if ! make test; then
    if ! ctest --rerun-failed --output-on-failure; then
        echo "The srsRAN_Project test cases failed."
        exit 1
    fi
fi
cd ../../..

echo
echo "Running tests for User_Equipment..."
cd User_Equipment/srsRAN_4G/build
if ! make test; then
    if ! ctest --rerun-failed --output-on-failure; then
        echo "The srsRAN_4G test cases failed."
        exit 1
    fi
fi
cd ../../..

echo
echo "Waiting for Near-RT RIC to be ready..."
cd RAN_Intelligent_Controllers/Near-Real-Time-RIC/install_scripts
./wait_for_ricplt_pods.sh
cd ../../..

./generate_configurations.sh

echo
echo "Starting the testbed components..."
cd 5G_Core_Network
./run.sh
cd ..
sleep 10

cd Next_Generation_Node_B
./run_background.sh
cd ..
sleep 10

cd User_Equipment
./run_background.sh
cd ..
sleep 10

if ./is_running.sh | grep -q "NOT RUNNING"; then
    echo "One or more components failed to start."
    exit 1
fi

# Now, we wait TIMEOUT_DURATION seconds for the UE to be successfully connected. If the waiting duration is exceeded, then an error occured.
LOG_FILE="User_Equipment/logs/ue1_stdout.txt"
TIMEOUT_DURATION=1800 # 30 minutes
START_TIME=$(date +%s)
while true; do
    echo
    echo "Waiting for UE to connect..."
    tail -n 4 $LOG_FILE || true
    if [ -f "$LOG_FILE" ] && grep -q "RRC NR reconfiguration successful" "$LOG_FILE"; then
        echo "Test successful: RRC NR reconfiguration successful."
        break
    fi
    ELAPSED_TIME=$(($(date +%s) - START_TIME))
    if [ $ELAPSED_TIME -ge $TIMEOUT_DURATION ]; then
        echo "Timeout reached: Test did not confirm successful UE connection within the 30 minutes."
        ./stop.sh
        exit 1
    fi
    sleep 5
done

./stop.sh

echo "Successfully passed all tests! Pushing updated commit_hashes.json..."

# git add commit_hashes.json
# git commit -m "Update commit hashes for dependencies ($(date '+%Y-%m-%d %H:%M:%S'))"
# git push

echo "OK"

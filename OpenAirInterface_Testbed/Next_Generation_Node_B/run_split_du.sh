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

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Parse arguments
RFSIM_SERVER=1
while [[ $# -gt 0 ]]; do
    case "$1" in
    [0-9]*)
        DU_NUMBER="$1"
        shift
        ;;
    --no-rfsim-server)
        RFSIM_SERVER=0
        shift
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done
if [ -z "$DU_NUMBER" ]; then
    echo "ERROR: A DU number must be provided as an argument."
    echo "    For example, $0 1 [--no-rfsim-server]"
    exit 1
fi
if ! [[ $DU_NUMBER =~ ^[0-9]+$ ]]; then
    echo "ERROR: DU number must be a number."
    exit 1
fi
if [ $DU_NUMBER -lt 1 ]; then
    echo "ERROR: DU number must be greater than or equal to 1."
    exit 1
fi

# Only DU 1 can be the RF simulator server
if [ "$DU_NUMBER" -ne 1 ]; then
    RFSIM_SERVER=0
fi

HOSTNAME_IP=$(hostname -I | awk '{print $1}')
RFSIM_SERVER_ARG="--rfsimulator.serveraddr $HOSTNAME_IP"
if [ "$RFSIM_SERVER" -ne 0 ]; then
    echo "RF simulator server mode enabled."
    RFSIM_SERVER_ARG="--rfsimulator.serveraddr server"
fi

# ADDITIONAL_FLAGS=""
# if [ -f "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build/libtelnetsrv.so" ]; then
#     echo "Found telnet server library. Enabling telnet server..."
#     TELNET_ADDRESS=127.0.0.1
#     TELNET_PORT=9099
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.shrmod ci,o1"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenaddr $TELNET_ADDRESS"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenport $TELNET_PORT"
#     ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --telnetsrv.listenstdin 1"
# fi

cd "$SCRIPT_DIR"

DU_CONFIG="$SCRIPT_DIR/configs/split_du$DU_NUMBER.conf"
if [ ! -f "$DU_CONFIG" ]; then
    echo "Generating configuration for DU $DU_NUMBER..."
    ./install_scripts/generate_du_configuration.sh "$DU_NUMBER"
fi

mkdir -p logs
>logs/split_du${DU_NUMBER}_stdout.txt

# Ensure the following command runs with sudo privileges
sudo ls >/dev/null

# Give the DU its own network namespace and configure it to access the host network
sudo ./install_scripts/setup_du_namespace.sh "$DU_NUMBER"

cd "$SCRIPT_DIR/openairinterface5g/cmake_targets/ran_build/build"

HOSTNAME_IP=$(hostname -I | awk '{print $1}')

# Code from (https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/develop/doc/handover-tutorial.md#run-the-setup):
# sudo ./nr-softmodem -O "$DU_CONFIG" --rfsim $RFSIM_SERVER_ARG --rfsimulator.options chanmod --gNBs.[0].min_rxtxtime 6 $ADDITIONAL_FLAGS
sudo script -q -f -c "./nr-softmodem -O \"$DU_CONFIG\" --rfsim $RFSIM_SERVER_ARG --rfsimulator.options chanmod --gNBs.[0].min_rxtxtime 6 $ADDITIONAL_FLAGS" "$SCRIPT_DIR/logs/split_du${DU_NUMBER}_stdout.txt"

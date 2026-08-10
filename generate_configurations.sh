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
cd "$SCRIPT_DIR"

USE_FLEXRIC=false
USE_ZMQ_CHANNEL_EMULATOR=true

CELL_NUMBERS_STR="1"   # Default cells
UE_NUMBERS_STR="1,2,3" # Default UEs
GNB_ARGS=()

usage() {
    echo "Usage: $0 [--cells <cell_numbers>] [--ues <ue_numbers>] [--disable-e2-term] [--e2-term-address <address>]"
    echo "    For example: $0 --ues 4,5,6 --cells 1,2"
}

while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --cells)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --cells requires comma-separated cell numbers."
            usage
            exit 1
        fi
        CELL_NUMBERS_STR="$2"
        shift 2
        ;;
    --ues)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --ues requires comma-separated UE numbers."
            usage
            exit 1
        fi
        UE_NUMBERS_STR="$2"
        shift 2
        ;;
    --disable-e2-term)
        GNB_ARGS+=(--disable-e2-term)
        shift
        ;;
    --e2-term-address)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --e2-term-address requires an address."
            usage
            exit 1
        fi
        GNB_ARGS+=(--e2-term-address "$2")
        shift 2
        ;;
    *)
        echo "ERROR: Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
done

IFS=',' read -r -a UE_CONFIG_ARGS <<<"$UE_NUMBERS_STR"

echo "Generating Configurations for 5G Core components..."
cd 5G_Core_Network
./generate_configurations.sh "${UE_CONFIG_ARGS[@]}"
cd ..

if [ "$USE_FLEXRIC" = "true" ]; then
    echo
    echo "Generating Configuration for FlexRIC..."
    cd OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC
    ./generate_configurations.sh
    cd "$SCRIPT_DIR"
fi

echo
echo "Generating Configuration for OCUDU Next Generation Node B..."
cd Next_Generation_Node_B
./generate_configurations.sh "${GNB_ARGS[@]}" --cells "$CELL_NUMBERS_STR" --ues "$UE_NUMBERS_STR"
cd ..

echo
echo "Generating Configuration for srsRAN User Equipment..."
cd User_Equipment
./generate_configurations.sh "${UE_CONFIG_ARGS[@]}"
cd "$SCRIPT_DIR"

# echo
# echo "Generating Configuration for Duranta User Equipment..."
# cd OpenAirInterface_Testbed/User_Equipment
# ./generate_configurations.sh "${UE_CONFIG_ARGS[@]}"
# cd "$SCRIPT_DIR"

if [ "$USE_ZMQ_CHANNEL_EMULATOR" = "true" ]; then
    echo "Verifying ZeroMQ channel emulator configuration..."
    Next_Generation_Node_B/install_scripts/validate_zmq_channel_emulator_config.sh --ues "$UE_NUMBERS_STR" --cells "$CELL_NUMBERS_STR"
fi

echo
echo "Successfully configured testbed components."

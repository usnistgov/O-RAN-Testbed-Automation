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

# This script will remove the untracked 5G_Core_Network, Next_Generation_Node_B, User_Equipment and RAN_Intelligent_Controllers repositories that were downloaded.

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"

# Echo every command as it is ran
set -x

# Main Testbed Repositories
sudo rm -rf 5G_Core_Network/open5gs
sudo rm -rf 5G_Core_Network/logs
sudo rm -rf 5G_Core_Network/configs
sudo rm -rf 5G_Core_Network/install_time.txt

sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/5gdeploy
sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/compose
sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/logs
sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/configs
sudo rm -rf 5G_Core_Network/Additional_Cores_5GDeploy/install_time.txt

sudo rm -rf User_Equipment/srsRAN_4G
sudo rm -rf User_Equipment/czmq
sudo rm -rf User_Equipment/libzmq
sudo rm -rf User_Equipment/logs
sudo rm -rf User_Equipment/configs
sudo rm -rf User_Equipment/install_time.txt

sudo rm -rf Next_Generation_Node_B/ocudu
sudo rm -rf Next_Generation_Node_B/ocudu_o1_adapter
sudo rm -rf Next_Generation_Node_B/ocudu_netconf
sudo rm -rf Next_Generation_Node_B/zmq_broker
sudo rm -rf Next_Generation_Node_B/czmq
sudo rm -rf Next_Generation_Node_B/libzmq
sudo rm -rf Next_Generation_Node_B/logs
sudo rm -rf Next_Generation_Node_B/configs
sudo rm -rf Next_Generation_Node_B/install_time.txt

sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/ric-dep
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/appmgr
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/e2-interface
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/charts
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/xApps
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/logs
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/influxdb
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/influxdb_auth_token.json
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/additional_scripts/pod_pcaps
sudo rm -rf RAN_Intelligent_Controllers/Near-Real-Time-RIC/install_time.txt

sudo rm -rf RAN_Intelligent_Controllers/Non-Real-Time-RIC/dep
sudo rm -rf RAN_Intelligent_Controllers/Non-Real-Time-RIC/rappmanager
sudo rm -rf RAN_Intelligent_Controllers/Non-Real-Time-RIC/nonrtric-controlpanel
sudo rm -rf RAN_Intelligent_Controllers/Non-Real-Time-RIC/rApps
sudo rm -rf RAN_Intelligent_Controllers/Non-Real-Time-RIC/logs
sudo rm -rf RAN_Intelligent_Controllers/Non-Real-Time-RIC/configs
sudo rm -rf RAN_Intelligent_Controllers/Non-Real-Time-RIC/install_time.txt

# OpenAirInterface_Testbed Repositories
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/open5gs
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/logs
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/configs
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/install_time.txt

sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/Additional_Cores_5GDeploy/5gdeploy
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/Additional_Cores_5GDeploy/compose
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/Additional_Cores_5GDeploy/logs
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/Additional_Cores_5GDeploy/configs
sudo rm -rf OpenAirInterface_Testbed/5G_Core_Network/Additional_Cores_5GDeploy/install_time.txt

sudo rm -rf OpenAirInterface_Testbed/User_Equipment/openairinterface5g
sudo rm -rf OpenAirInterface_Testbed/User_Equipment/logs
sudo rm -rf OpenAirInterface_Testbed/User_Equipment/configs
sudo rm -rf OpenAirInterface_Testbed/User_Equipment/install_time.txt

sudo rm -rf OpenAirInterface_Testbed/Next_Generation_Node_B/openairinterface5g
sudo rm -rf OpenAirInterface_Testbed/Next_Generation_Node_B/o1-adapter
sudo rm -rf OpenAirInterface_Testbed/Next_Generation_Node_B/logs
sudo rm -rf OpenAirInterface_Testbed/Next_Generation_Node_B/configs
sudo rm -rf OpenAirInterface_Testbed/Next_Generation_Node_B/install_time.txt

sudo rm -rf OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC/swig
sudo rm -rf OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC/flexric
sudo rm -rf OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC/logs
sudo rm -rf OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC/configs
sudo rm -rf OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC/install_time.txt

# Echo every command as it is ran
set +x

echo "Repositories were removed successfully."

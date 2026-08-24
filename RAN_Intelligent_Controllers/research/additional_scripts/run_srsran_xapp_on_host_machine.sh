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

################################################################################
# There are xApps released by the OCUDU that can be run in the RIC:
# https://github.com/srsran/oran-sc-ric/tree/main/xApps/python
# This script will ask the user to select an xApp to run, then install it on the
# host machine and run it, using the Kubernetes e2mgr pod for RMR communication.
################################################################################

# Exit immediately if a command fails
set -e

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

echo "# Script: $(realpath "$0") $@"

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if ! command -v git &>/dev/null; then
    echo
    echo "Installing git..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y git
fi

mkdir -p "$SCRIPT_DIR/srsran_xapps"
cd "$SCRIPT_DIR/srsran_xapps"

if [ ! -d oran-sc-ric ]; then
    echo
    echo "Cloning srsran/oran-sc-ric..."
    git clone https://github.com/srsran/oran-sc-ric.git
fi

################################################################################
# Ask the user to select an xApp to run
################################################################################

cd "$SCRIPT_DIR/srsran_xapps/oran-sc-ric/xApps/python"

# Store all *.py files in the current directory into an array
PYTHON_FILES=(*.py)
if [ ${#PYTHON_FILES[@]} -eq 0 ]; then
    echo "No Python files found in the current directory."
    exit 1
fi
echo
echo "List of available xApps to run:"
INDEX=1
for FILE in "${PYTHON_FILES[@]}"; do
    echo "    $INDEX. $FILE"
    ((INDEX++))
done
echo
read -p "Please type the index of the xApp you wish to run: " USER_INPUT

# Validate the input
if ! [[ "$USER_INPUT" =~ ^[0-9]+$ ]] || [ "$USER_INPUT" -lt 1 ] || [ "$USER_INPUT" -gt ${#PYTHON_FILES[@]} ]; then
    echo "Invalid selection. Please enter a number between 1 and ${#PYTHON_FILES[@]}."
    exit 1
fi

SELECTED_XAPP_PATH="${PYTHON_FILES[$((USER_INPUT - 1))]}"
echo "Selected xApp: $SELECTED_XAPP_PATH"
echo

################################################################################
# Select an E2 node ID by fetching the list of connected E2 nodes from submgr
################################################################################

if ! command -v curl &>/dev/null; then
    echo "Installing curl..."
    sudo env $APTVARS apt-get install -y curl
fi
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo env $APTVARS apt-get install -y jq
fi

SUBMGR_IP="null"
RMR_PORT="null"
# Loop through the arguments
for ARG in "$@"; do
    if [[ $ARG == --submgr_ip=* ]]; then
        SUBMGR_IP="${ARG#*=}"
    elif [[ $ARG == --rmr_port=* ]]; then
        RMR_PORT="${ARG#*=}"
    fi
done

if [ "$SUBMGR_IP" = "null" ]; then
    SUBMGR_IP=$(kubectl get pods -A -o jsonpath='{.items[?(@.metadata.labels.app=="ricplt-submgr")].status.podIP}')
    if [ -z "$SUBMGR_IP" ]; then
        echo "No submgr pod found. Exiting."
        exit 1
    fi
fi

if [ "$RMR_PORT" = "null" ]; then
    RMR_SERVICE_INFO=$(kubectl get service -n ricplt | grep service-ricplt-submgr-rmr)
    if [ -z "$RMR_SERVICE_INFO" ]; then
        echo "No submgr service found. Exiting."
        exit 1
    fi
    RMR_PORT=$(echo "$RMR_SERVICE_INFO" | awk '{print $5}' | cut -d ',' -f1 | cut -d '/' -f1)
fi

# Get the list of E2 node IDs
E2_IDS_JSON=$(curl -X GET "http://$SUBMGR_IP:8080/ric/v1/get_all_e2nodes")
if [ "$E2_IDS_JSON" = "null" ]; then
    E2_IDS_JSON="[]" # Default E2_Node_ID
fi
E2_IDS=($(echo $E2_IDS_JSON | jq -r '.[]'))
NUM_E2_IDS=${#E2_IDS[@]}
if [ $NUM_E2_IDS -eq 0 ]; then
    echo "(The submgr responsed that no E2 nodes were found)."
fi
echo
echo "List of available E2 Nodes:"
echo "    0. Type E2 Node ID Manually"
INDEX=1
for NODE_ID in "${E2_IDS[@]}"; do
    echo "    $INDEX. $NODE_ID"
    ((INDEX++))
done
echo
read -p "Please type the index of the E2 node you wish to use or type '0' to enter manually: " USER_INPUT

# Handle manual input option
if [ "$USER_INPUT" -eq 0 ]; then
    read -p "Please enter the E2 Node ID (default: gnbd_001_001_00019b_0): " MANUAL_INPUT
    E2_NODE_ID="${MANUAL_INPUT:-gnbd_001_001_00019b_0}"
    echo "Selected E2 Node ID: $E2_NODE_ID"
    echo
else
    # Validate the input
    if ! [[ "$USER_INPUT" =~ ^[0-9]+$ ]] || [ "$USER_INPUT" -lt 1 ] || [ "$USER_INPUT" -gt $NUM_E2_IDS ]; then
        echo "Invalid selection. Please enter a number between 1 and $NUM_E2_IDS."
        exit 1
    fi
    # Select the E2 node based on the user's input
    E2_NODE_ID=${E2_IDS[$((USER_INPUT - 1))]}
    echo "Selected E2 Node ID: $E2_NODE_ID"
    echo
fi
echo

################################################################################
# Type the UE ID (RNTI) if needed
################################################################################

UE_ID=0 # 4601
if [[ "$SELECTED_XAPP_PATH" == "kpm_mon_xapp.py" ]] || [[ "$SELECTED_XAPP_PATH" == "simple_mon_xapp.py" ]] || [[ "$SELECTED_XAPP_PATH" == "simple_ricsimple_xapp.py" ]]; then
    echo "Please enter the UE ID (known as RNTI; from the srsue or srsgnb console, press 't' and then enter, type \"\" for 0): "
    read -r UE_ID_INPUT
    if [[ -n "$UE_ID_INPUT" ]]; then
        UE_ID="$UE_ID_INPUT"
    fi
fi

################################################################################
# Install the xapp-frame-py
################################################################################

cd "$SCRIPT_DIR/srsran_xapps"
if [ ! -d ric-plt-xapp-frame-py ]; then
    echo "Cloning o-ran-sc/ric-plt-xapp-frame-py..."
    # The release J has a memory leak in get_constants(): https://gerrit.o-ran-sc.org/r/c/ric-plt/xapp-frame-py/+/7209
    # git clone https://gerrit.o-ran-sc.org/r/ric-plt/xapp-frame-py --branch j-release ric-plt-xapp-frame-py
    git clone https://gerrit.o-ran-sc.org/r/ric-plt/xapp-frame-py --branch master ric-plt-xapp-frame-py
fi

cd "$SCRIPT_DIR/srsran_xapps"

# Install dependencies if not already installed
if ! command -v python3.8 &>/dev/null; then
    echo "Python 3.8 is not installed. Installing..."
    sudo apt-get update
    sudo env $APTVARS apt-get install -y software-properties-common
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt-get update
    sudo apt-get update
    sudo env $APTVARS apt-get install -y python3.8 python3.8-dev
fi
if ! command -v pip &>/dev/null; then
    echo "Installing pip..."
    sudo env $APTVARS apt-get install -y python3-pip
fi

sudo env $APTVARS apt-get install -y python3.8-venv

# Create a virtual environment with Python 3.8 if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating a new virtual environment with Python 3.8..."
    python3.8 -m venv venv
fi

# Activate the virtual environment
source venv/bin/activate

# Ensure the virtual environment uses Python 3.8
PYTHON_VERSION=$(python3.8 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
if [[ "$PYTHON_VERSION" != "3.8" ]]; then
    echo "Virtual environment is not using Python 3.8. Exiting."
    deactivate
    exit 1
fi

################################################################################
# Install libraries librmr_si.so and libriclibe2ap.so
################################################################################

RMR_VERSION=4.9.4
E2AP_VERSION=1.1.0

if ! command -v wget &>/dev/null; then
    echo "Installing wget..."
    sudo env $APTVARS apt-get install -y wget
fi
if ! command -v gcc &>/dev/null; then
    echo "Installing gcc..."
    sudo env $APTVARS apt-get install -y gcc
fi
if ! dpkg -s musl-dev &>/dev/null; then
    echo "Installing musl-dev..."
    sudo env $APTVARS apt-get install -y musl-dev
fi

if [ ! -f /usr/local/lib/librmr_si.so ]; then
    echo "Downloading librmr_si.so..."
    PREV_DIR=$(pwd)
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    wget -nv --content-disposition https://packagecloud.io/o-ran-sc/release/packages/debian/stretch/rmr_${RMR_VERSION}_amd64.deb/download.deb
    wget -nv --content-disposition https://packagecloud.io/o-ran-sc/release/packages/debian/stretch/rmr-dev_${RMR_VERSION}_amd64.deb/download.deb
    sudo dpkg -i rmr_${RMR_VERSION}_amd64.deb
    sudo dpkg -i rmr-dev_${RMR_VERSION}_amd64.deb
    LIB_PATH=$(dpkg -L rmr_${RMR_VERSION} | grep librmr_si.so | head -n 1)
    if [ ! -f /usr/local/lib/librmr_si.so ]; then
        if [ -n "$LIB_PATH" ] && [ -f "$LIB_PATH" ]; then
            sudo cp "$LIB_PATH" /usr/local/lib/librmr_si.so
        else
            echo "librmr_si.so not found after package installation."
            exit 1
        fi
    fi
    cd "$PREV_DIR"
    rm -rf "$TEMP_DIR"
fi

if [ ! -f /usr/local/lib/libriclibe2ap.so ]; then
    echo "Downloading libriclibe2ap.so..."
    PREV_DIR=$(pwd)
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    wget -nv --content-disposition https://packagecloud.io/o-ran-sc/release/packages/debian/stretch/riclibe2ap_${E2AP_VERSION}_amd64.deb/download.deb
    wget -nv --content-disposition https://packagecloud.io/o-ran-sc/release/packages/debian/stretch/riclibe2ap-dev_${E2AP_VERSION}_amd64.deb/download.deb
    sudo dpkg -i riclibe2ap_${E2AP_VERSION}_amd64.deb
    sudo dpkg -i riclibe2ap-dev_${E2AP_VERSION}_amd64.deb
    LIB_PATH=$(dpkg -L riclibe2ap | grep libriclibe2ap.so | head -n 1)
    if [ ! -f /usr/local/lib/libriclibe2ap.so ]; then
        if [ -n "$LIB_PATH" ] && [ -f "$LIB_PATH" ]; then
            sudo cp "$LIB_PATH" /usr/local/lib/libriclibe2ap.so
        else
            echo "libriclibe2ap.so not found after package installation."
            exit 1
        fi
    fi
    cd "$PREV_DIR"
    rm -rf "$TEMP_DIR"
fi

# Add the library path to the bashrc file
if ! grep -q 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' ~/.bashrc; then
    echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >>~/.bashrc
fi
source ~/.bashrc
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

pip install --upgrade pip setuptools wheel
pip install tox
pip install certifi six python_dateutil setuptools urllib3 inotify_simple mdclogpy
pip install asn1tools

cd "$SCRIPT_DIR/srsran_xapps/ric-plt-xapp-frame-py"
pip install -e .

################################################################################
# Set the arguments for the selected xApp
################################################################################

# E2 Nodes (null if none)
# SUBMGR_IP=$(kubectl get pods -A -o jsonpath='{.items[?(@.metadata.labels.app=="ricplt-submgr")].status.podIP}')# E2_IDS=$(curl -X GET "http://$SUBMGR_IP:8080/ric/v1/get_all_e2nodes")
# E2_IDS=$(curl -X GET "http://$SUBMGR_IP:8080/ric/v1/get_all_e2nodes")

HTTP_SERVER_PORT=8092

SELECTED_APP_ARGS=""
if [ "$SELECTED_XAPP_PATH" = "kpm_mon_xapp.py" ]; then
    # parser.add_argument("--config", type=str, default='', help="xApp config file path")
    # parser.add_argument("--http_server_port", type=int, default=8092, help="HTTP server listen port")
    # parser.add_argument("--rmr_port", type=int, default=4562, help="RMR port")
    # parser.add_argument("--e2_node_id", type=str, default='gnbd_001_001_00019b_0', help="E2 Node ID")
    # parser.add_argument("--ran_func_id", type=int, default=2, help="RAN function ID")
    # parser.add_argument("--kpm_report_style", type=int, default=1, help="xApp config file path")
    # parser.add_argument("--ue_ids", type=str, default='0', help="UE ID")
    # parser.add_argument("--metrics", type=str, default='DRB.UEThpUl,DRB.UEThpDl', help="Metrics name as comma-separated string")
    SELECTED_APP_ARGS="--ran_func_id 1 --metrics=DRB.UEThpDl,DRB.UEThpUl --kpm_report_style=4 --ue_ids $UE_ID --http_server_port=$HTTP_SERVER_PORT --rmr_port=$RMR_PORT --e2_node_id=$E2_NODE_ID"

elif [ "$SELECTED_XAPP_PATH" = "simple_mon_xapp.py" ]; then
    # parser.add_argument("--config", type=str, default='', help="xApp config file path")
    # parser.add_argument("--http_server_port", type=int, default=8091, help="HTTP server listen port")
    # parser.add_argument("--rmr_port", type=int, default=4561, help="RMR port")
    # parser.add_argument("--e2_node_id", type=str, default='gnbd_001_001_00019b_0', help="E2 Node ID")
    # parser.add_argument("--ran_func_id", type=int, default=2, help="RAN function ID")
    # parser.add_argument("--metrics", type=str, default='DRB.UEThpDl', help="Metrics name as comma-separated string")
    SELECTED_APP_ARGS="--ran_func_id 1 --metrics=DRB.UEThpDl,DRB.UEThpUl --http_server_port=$HTTP_SERVER_PORT --rmr_port=$RMR_PORT --e2_node_id=$E2_NODE_ID"

elif [ "$SELECTED_XAPP_PATH" = "simple_rc_xapp.py" ]; then
    # parser.add_argument("--config", type=str, default='', help="xApp config file path")
    # parser.add_argument("--http_server_port", type=int, default=8090, help="HTTP server listen port")
    # parser.add_argument("--rmr_port", type=int, default=4560, help="RMR port")
    # parser.add_argument("--e2_node_id", type=str, default='gnbd_001_001_00019b_0', help="E2 Node ID")
    # parser.add_argument("--ran_func_id", type=int, default=3, help="E2SM RC RAN function ID")
    # parser.add_argument("--ue_id", type=int, default=0, help="UE ID")
    SELECTED_APP_ARGS="--ran_func_id 1 --ue_id $UE_ID --http_server_port=$HTTP_SERVER_PORT --rmr_port=$RMR_PORT --e2_node_id=$E2_NODE_ID"

elif [ "$SELECTED_XAPP_PATH" = "simple_ricsimple_xapp.py" ]; then
    # parser.add_argument("--http_server_port", type=int, default=8090, help="HTTP server listen port")
    # parser.add_argument("--rmr_port", type=int, default=4560, help="RMR port")
    # parser.add_argument("--e2_node_id", type=str, default='gnbd_001_001_00019b_0', help="E2 Node ID")
    # parser.add_argument("--ran_func_id", type=int, default=2, help="RAN function ID")
    # parser.add_argument("--kpm_report_style", type=int, default=4, help="KPM Report Style ID")
    # parser.add_argument("--ue_ids", type=str, default='0', help="UE ID")
    # parser.add_argument("--metrics", type=str, default='DRB.RlcSduTransmittedVolumeDL', help="Metrics name as comma-separated string")
    SELECTED_APP_ARGS="--ran_func_id 1 --metrics=DRB.RlcSduTransmittedVolumeDL,DRB.RlcSduTransmittedVolumeUL --kpm_report_style=4 --ue_id $UE_ID --http_server_port=$HTTP_SERVER_PORT --rmr_port=$RMR_PORT --e2_node_id=$E2_NODE_ID"
fi

################################################################################
# Run the xApp
################################################################################

cd "$SCRIPT_DIR/srsran_xapps"
source venv/bin/activate

cd oran-sc-ric/xApps/python
echo
echo "Running the selected xApp: \"$SELECTED_XAPP_PATH $SELECTED_APP_ARGS\""
python3 "$SELECTED_XAPP_PATH" $SELECTED_APP_ARGS

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

set +e

NUM_SAMPLES=100

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
BASE_DIR=$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")

cd "$BASE_DIR"

CSV_FILE="$SCRIPT_DIR/install_experiment.csv"
if [ ! -f "$CSV_FILE" ]; then
    CSV_HEADER=""
    CSV_HEADER+="Timestamp,"
    CSV_HEADER+="UNIX Epoch,"
    CSV_HEADER+="Open5GS (m),"
    CSV_HEADER+="5GDeploy Cores (m),"
    CSV_HEADER+="OAI UE (m),"
    CSV_HEADER+="OAI gNB (m),"
    CSV_HEADER+="FlexRIC (m),"
    CSV_HEADER+="srsRAN_Project (m),"
    CSV_HEADER+="srsRAN_UE (m),"
    CSV_HEADER+="O-SC Near-RT RIC (m)\n"
    echo -e "$CSV_HEADER" >"$CSV_FILE"
fi

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    cd "$BASE_DIR/5G_Core_Network"
    sudo "install_scripts/./install_yq.sh"
fi

for I in $(seq 1 $NUM_SAMPLES); do
    echo
    echo
    echo "Running Install Iteration $I"
    echo
    echo

    cd "$BASE_DIR/5G_Core_Network"
    yq eval -i '.core_to_use = "open5gs"' options.yaml

    # Install Open5GS, OAI UE, OAI gNB, FlexRIC
    cd "$BASE_DIR/OpenAirInterface"
    ./full_install.sh -n

    # Install 5GDeploy Cores
    cd "$BASE_DIR/5G_Core_Network"
    yq eval -i '.core_to_use = "5gdeploy-oai"' options.yaml

    # Install srsRAN_Project, srsRAN_UE, and O-SC Near-RT RIC
    cd "$BASE_DIR"
    ./full_install.sh -y

    OPEN5GS_FILE="$BASE_DIR/5G_Core_Network/install_time.txt"
    if [ -f "$OPEN5GS_FILE" ]; then
        OPEN5GS_INSTALL_TIME=$(head -n 1 5G_Core_Network/install_time.txt | awk '{print $1}')
    else
        OPEN5GS_INSTALL_TIME=""
    fi

    NIST5GDEPLOY_FILE="$BASE_DIR/5G_Core_Network/Additional_Cores_5GDeploy/install_time.txt"
    if [ -f "$NIST5GDEPLOY_FILE" ]; then
        NIST5GDEPLOY_INSTALL_TIME=$(head -n 1 "$NIST5GDEPLOY_FILE" | awk '{print $1}')
    else
        NIST5GDEPLOY_INSTALL_TIME=""
    fi

    OAI_UE_FILE="$BASE_DIR/OpenAirInterface/User_Equipment/install_time.txt"
    if [ -f "$OAI_UE_FILE" ]; then
        OAI_UE_INSTALL_TIME=$(head -n 1 "$OAI_UE_FILE" | awk '{print $1}')
    else
        OAI_UE_INSTALL_TIME=""
    fi

    OAI_GNB_FILE="$BASE_DIR/OpenAirInterface/Next_Generation_Node_B/install_time.txt"
    if [ -f "$OAI_GNB_FILE" ]; then
        OAI_GNB_INSTALL_TIME=$(head -n 1 "$OAI_GNB_FILE" | awk '{print $1}')
    else
        OAI_GNB_INSTALL_TIME=""
    fi

    FLEXRIC_FILE="$BASE_DIR/RAN_Intelligent_Controllers/FlexRIC/install_time.txt"
    if [ -f "$FLEXRIC_FILE" ]; then
        FLEXRIC_INSTALL_TIME=$(head -n 1 "$FLEXRIC_FILE" | awk '{print $1}')
    else
        FLEXRIC_INSTALL_TIME=""
    fi

    SRSRAN_GNB_FILE="$BASE_DIR/Next_Generation_Node_B/install_time.txt"
    if [ -f "$SRSRAN_GNB_FILE" ]; then
        SRSRAN_GNB_INSTALL_TIME=$(head -n 1 "$SRSRAN_GNB_FILE" | awk '{print $1}')
    else
        SRSRAN_GNB_INSTALL_TIME=""
    fi

    SRSRAN_UE_FILE="$BASE_DIR/User_Equipment/install_time.txt"
    if [ -f "$SRSRAN_UE_FILE" ]; then
        SRSRAN_UE_INSTALL_TIME=$(head -n 1 "$SRSRAN_UE_FILE" | awk '{print $1}')
    else
        SRSRAN_UE_INSTALL_TIME=""
    fi

    ORAN_RIC_FILE="$BASE_DIR/RAN_Intelligent_Controllers/Near-Real-Time-RIC/install_time.txt"
    if [ -f "$ORAN_RIC_FILE" ]; then
        ORAN_RIC_INSTALL_TIME=$(head -n 1 "$ORAN_RIC_FILE" | awk '{print $1}')
    else
        ORAN_RIC_INSTALL_TIME=""
    fi

    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    UNIX_EPOCH=$(date +%s)
    CSV_LINE=""
    CSV_LINE+="$TIMESTAMP,"
    CSV_LINE+="$UNIX_EPOCH,"
    CSV_LINE+="$OPEN5GS_INSTALL_TIME,"
    CSV_LINE+="$NIST5GDEPLOY_INSTALL_TIME,"
    CSV_LINE+="$OAI_UE_INSTALL_TIME,"
    CSV_LINE+="$OAI_GNB_INSTALL_TIME,"
    CSV_LINE+="$FLEXRIC_INSTALL_TIME,"
    CSV_LINE+="$SRSRAN_GNB_INSTALL_TIME,"
    CSV_LINE+="$SRSRAN_UE_INSTALL_TIME,"
    CSV_LINE+="$ORAN_RIC_INSTALL_TIME,"
    echo -e "$CSV_LINE" >>"$CSV_FILE\n"
    echo "    Wrote Iteration $I to $CSV_FILE."

    cd "$BASE_DIR"
    ./full_uninstall.sh bypass_confirmation

    cd "$BASE_DIR/5G_Core_Network"
    yq eval -i '.core_to_use = "open5gs"' options.yaml
    ./full_uninstall.sh bypass_confirmation

    cd "$BASE_DIR/OpenAirInterface"
    ./full_uninstall.sh bypass_confirmation
done

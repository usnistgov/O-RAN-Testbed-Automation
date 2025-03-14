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

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo "$SCRIPT_DIR/install_scripts/./install_yq.sh"
fi

echo "Downloading configuration file example..."
rm -rf "$SCRIPT_DIR/configs"
mkdir "$SCRIPT_DIR/configs"
rm -rf "$SCRIPT_DIR/logs"
wget https://raw.githubusercontent.com/srsran/srsRAN/master/srsue/ue.conf.example -O configs/ue1.conf

# Function to update or add configuration properties in .conf files, considering sections and uncommenting if needed
update_conf() {
    echo "update_conf($1, $2, $3, $4)"
    local FILE_PATH="$1"
    local SECTION="$2"
    local PROPERTY="$3"
    local VALUE="$4"

    # Ensure the section exists; if not, add it at the end
    if ! grep -q "^\[$SECTION\]" "$FILE_PATH"; then
        echo -e "\n[$SECTION]" >>"$FILE_PATH"
    fi
    # Remove any existing entries of the property in the section (including commented ones)
    sed -i "/^\[$SECTION\]/,/^\s*\[/{/^[# ]*\s*$PROPERTY\s*=.*/d}" "$FILE_PATH"
    # Append the new property=value after the section header
    sed -i "/^\[$SECTION\]/a $PROPERTY = $VALUE" "$FILE_PATH"
}

UE1_TX_PORT=2001 # 2101
UE1_RX_PORT=2000 # 2100

# Update configuration values for RF front-end device
update_conf "configs/ue1.conf" "rf" "device_name" "zmq"
update_conf "configs/ue1.conf" "rf" "device_args" "tx_port=tcp://127.0.0.1:$UE1_TX_PORT,rx_port=tcp://127.0.0.1:$UE1_RX_PORT,base_srate=23.04e6"
update_conf "configs/ue1.conf" "rf" "nof_antennas" "1"
update_conf "configs/ue1.conf" "rf" "tx_gain" "50"
update_conf "configs/ue1.conf" "rf" "rx_gain" "40"
update_conf "configs/ue1.conf" "rf" "srate" "23.04e6"
update_conf "configs/ue1.conf" "rf" "freq_offset" "0"

# Update configuration values for RAT (EUTRA)
update_conf "configs/ue1.conf" "rat.eutra" "nof_carriers" "0" # Disabled EUTRA (LTE) since we are using NR (5G)
update_conf "configs/ue1.conf" "rat.eutra" "dl_earfcn" "2850"

# Update configuration values for RAT (NR)
update_conf "configs/ue1.conf" "rat.nr" "nof_carriers" "1"
update_conf "configs/ue1.conf" "rat.nr" "bands" "3"
update_conf "configs/ue1.conf" "rat.nr" "max_nof_prb" "106"
update_conf "configs/ue1.conf" "rat.nr" "nof_prb" "106"

# Update configuration values for PCAP
update_conf "configs/ue1.conf" "pcap" "enable" "none"
# Uncomment for log files:
# update_conf "configs/ue1.conf" "pcap" "enable" "mac,mac_nr,nas"
update_conf "configs/ue1.conf" "pcap" "mac_filename" "$SCRIPT_DIR/logs/ue1_mac.pcap"
update_conf "configs/ue1.conf" "pcap" "mac_nr_filename" "$SCRIPT_DIR/logs/ue1_mac_nr.pcap"
update_conf "configs/ue1.conf" "pcap" "nas_filename" "$SCRIPT_DIR/logs/ue1_nas.pcap"

# Update configuration values for Logging
update_conf "configs/ue1.conf" "log" "all_level" "info" #warning
update_conf "configs/ue1.conf" "log" "phy_lib_level" "none"
update_conf "configs/ue1.conf" "log" "all_hex_limit" "32"
update_conf "configs/ue1.conf" "log" "filename" "$SCRIPT_DIR/logs/ue1.txt"
update_conf "configs/ue1.conf" "log" "file_max_size" "-1"

# Update configuration values for Metrics
update_conf "configs/ue1.conf" "general" "metrics_period_secs" "1"
update_conf "configs/ue1.conf" "general" "metrics_csv_enable" "false"
update_conf "configs/ue1.conf" "general" "metrics_csv_filename" "$SCRIPT_DIR/logs/ue1_metrics.csv"
update_conf "configs/ue1.conf" "general" "metrics_json_enable" "false"
update_conf "configs/ue1.conf" "general" "metrics_json_filename" "$SCRIPT_DIR/logs/ue_metrics.json"
update_conf "configs/ue1.conf" "general" "tracing_enable" "true"
update_conf "configs/ue1.conf" "general" "tracing_filename" "$SCRIPT_DIR/logs/ue1_tracing.txt"
update_conf "configs/ue1.conf" "general" "tracing_buffcapacity" "1000000"

# Update configuration values for USIM
update_conf "configs/ue1.conf" "usim" "mode" "soft"
update_conf "configs/ue1.conf" "usim" "algo" "milenage"
update_conf "configs/ue1.conf" "usim" "opc" "63BFA50EE6523365FF14C1F45F88737D"
update_conf "configs/ue1.conf" "usim" "k" "00112233445566778899aabbccddeeff"
update_conf "configs/ue1.conf" "usim" "imsi" "001010123456780"
update_conf "configs/ue1.conf" "usim" "imei" "353490069873319"

# Update configuration values for RRC
update_conf "configs/ue1.conf" "rrc" "release" "15"
update_conf "configs/ue1.conf" "rrc" "ue_category" "4"

# Update configuration values for NAS
update_conf "configs/ue1.conf" "nas" "apn" "srsapn"
update_conf "configs/ue1.conf" "nas" "apn_protocol" "ipv4"

# Update configuration values for Gateway
update_conf "configs/ue1.conf" "gw" "netns" "ue1"
update_conf "configs/ue1.conf" "gw" "ip_devname" "tun_srsue"
update_conf "configs/ue1.conf" "gw" "ip_netmask" "255.255.255.0"

# Update configuration values for GUI
update_conf "configs/ue1.conf" "gui" "enable" "false"

mkdir -p logs
sudo chown $USER:$USER -R logs

echo "Successfully configured the UE. The configuration file is located in the configs/ directory."

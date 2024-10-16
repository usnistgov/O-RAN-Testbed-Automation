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

if ! command -v yq &> /dev/null; then
    YQ_PATH="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    sudo wget $YQ_PATH -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
    # Uninstall with: sudo rm -rf /usr/bin/yq
fi

baseDirectory=$(pwd)

echo "Downloading configuration file example..."
rm -rf configs
mkdir configs
wget https://raw.githubusercontent.com/srsran/srsRAN/master/srsue/ue.conf.example -O configs/ue.conf

echo
echo
echo "Configuring UE..."

# Function to update or add configuration properties in .conf files, considering sections and uncommenting if needed
update_conf() {
    echo "update_conf($1, $2, $3, $4)"
    local FILE_PATH="$1"
    local SECTION="$2"
    local PROPERTY="$3"
    local VALUE="$4"

    # Ensure the section exists; if not, add it at the end
    if ! grep -q "^\[$SECTION\]" "$FILE_PATH"; then
        echo -e "\n[$SECTION]" >> "$FILE_PATH"
    fi
    # Remove any existing entries of the property in the section (including commented ones)
    sed -i "/^\[$SECTION\]/,/^\s*\[/{/^[# ]*\s*$PROPERTY\s*=.*/d}" "$FILE_PATH"
    # Append the new property=value after the section header
    sed -i "/^\[$SECTION\]/a $PROPERTY=$VALUE" "$FILE_PATH"
}

mkdir -p logs

# Update configuration values for RF front-end device
update_conf configs/ue.conf "rf" "device_name" "zmq"
update_conf configs/ue.conf "rf" "device_args" "tx_port=tcp://127.0.0.1:2001,rx_port=tcp://127.0.0.1:2000,base_srate=23.04e6"
update_conf configs/ue.conf "rf" "nof_antennas" "1"
update_conf configs/ue.conf "rf" "srate" "23.04e6"
update_conf configs/ue.conf "rf" "tx_gain" "50"
update_conf configs/ue.conf "rf" "rx_gain" "40"
update_conf configs/ue.conf "rf" "freq_offset" "0"

# Update configuration values for RAT (EUTRA)
update_conf configs/ue.conf "rat.eutra" "nof_carriers" "0"
update_conf configs/ue.conf "rat.eutra" "dl_earfcn" "2850"

# Update configuration values for RAT (NR)
update_conf configs/ue.conf "rat.nr" "nof_carriers" "1"
update_conf configs/ue.conf "rat.nr" "bands" "3"
update_conf configs/ue.conf "rat.nr" "max_nof_prb" "106"
update_conf configs/ue.conf "rat.nr" "nof_prb" "106"

# Update configuration values for PCAP
update_conf configs/ue.conf "pcap" "enable" "none"
update_conf configs/ue.conf "pcap" "mac_filename" "logs/ue_mac.pcap"
update_conf configs/ue.conf "pcap" "mac_nr_filename" "logs/ue_mac_nr.pcap"
update_conf configs/ue.conf "pcap" "nas_filename" "logs/ue_nas.pcap"

# Update configuration values for Logging
update_conf configs/ue.conf "log" "all_level" "info"
update_conf configs/ue.conf "log" "phy_lib_level" "none"
update_conf configs/ue.conf "log" "all_hex_limit" "32"
update_conf configs/ue.conf "log" "filename" "logs/ue.log"
update_conf configs/ue.conf "log" "file_max_size" "-1"

# Update configuration values for Metrics
update_conf configs/ue.conf "general" "metrics_csv_enable" "true"
update_conf configs/ue.conf "general" "metrics_period_secs" "1"
update_conf configs/ue.conf "general" "metrics_csv_filename" "logs/ue_metrics.csv"
#update_conf configs/ue.conf "general" "have_tti_time_stats" "true"
update_conf configs/ue.conf "general" "tracing_enable" "true"
update_conf configs/ue.conf "general" "tracing_filename" "logs/ue_tracing.log"
update_conf configs/ue.conf "general" "tracing_buffcapacity" "1000000"
update_conf configs/ue.conf "general" "metrics_json_enable" "true"
update_conf configs/ue.conf "general" "metrics_json_filename" "logs/ue_metrics.json"

# Update configuration values for USIM
update_conf configs/ue.conf "usim" "mode" "soft"
update_conf configs/ue.conf "usim" "algo" "milenage"
update_conf configs/ue.conf "usim" "opc" "63BFA50EE6523365FF14C1F45F88737D"
update_conf configs/ue.conf "usim" "k" "00112233445566778899aabbccddeeff"
update_conf configs/ue.conf "usim" "imsi" "001010123456780"
update_conf configs/ue.conf "usim" "imei" "353490069873319"

# Update configuration values for RRC
update_conf configs/ue.conf "rrc" "release" "15"
update_conf configs/ue.conf "rrc" "ue_category" "4"

# Update configuration values for NAS
update_conf configs/ue.conf "nas" "apn" "srsapn"
update_conf configs/ue.conf "nas" "apn_protocol" "ipv4"

# Update configuration values for Gateway
update_conf configs/ue.conf "gw" "netns" "ue1"
update_conf configs/ue.conf "gw" "ip_devname" "tun_srsue"
update_conf configs/ue.conf "gw" "ip_netmask" "255.255.255.0"

# Update configuration values for GUI
update_conf configs/ue.conf "gui" "enable" "false"

mkdir -p logs
sudo chown $USER:$USER -R logs

echo "Successfully configured the UE. The configuration file is located in the configs/ directory."

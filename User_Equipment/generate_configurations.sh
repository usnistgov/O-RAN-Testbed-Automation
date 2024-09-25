#!/bin/bash

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
    local file_path="$1"
    local section="$2"
    local property="$3"
    local value="$4"

    # Ensure the section exists; if not, add it at the end
    if ! grep -q "^\[$section\]" "$file_path"; then
        echo -e "\n[$section]" >> "$file_path"
    fi
    # Remove any existing entries of the property in the section (including commented ones)
    sed -i "/^\[$section\]/,/^\s*\[/{/^[# ]*\s*$property\s*=.*/d}" "$file_path"
    # Append the new property=value after the section header
    sed -i "/^\[$section\]/a $property=$value" "$file_path"
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

echo "Successfully configured the UE. The configuration file is located in the configs/ directory."





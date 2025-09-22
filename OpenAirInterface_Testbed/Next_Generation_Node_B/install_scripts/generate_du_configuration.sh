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
PARENT_DIR=$(dirname "$SCRIPT_DIR")

DU_NUMBER="$1"

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

cd "$PARENT_DIR"

# Function to comment out a line in a file
comment_out() {
    local FILE_PATH="$1"
    local STRING="$2"
    sed -i "s|^\(\s*\)$STRING|#\1$STRING|" "$FILE_PATH"
}

DU_CONF="$PARENT_DIR/configs/split_du${DU_NUMBER}.conf"
if [ ! -f "$PARENT_DIR/configs/split_du1.conf" ]; then
    echo "ERROR: Base configuration file split_du1.conf not found in configs/ directory."
    exit 1
fi
if [ "$DU_NUMBER" -ne 1 ]; then
    cp "$PARENT_DIR/configs/split_du1.conf" "$DU_CONF"
fi

echo "Generating configuration for DU $DU_NUMBER..."

# Set Active_gNBs = ... to Active_gNBs = ( "du${DU_NUMBER}-rfsim");
sed -i "s|^\([[:space:]]*\)Active_gNBs\s*=.*|\1Active_gNBs = ( \"du${DU_NUMBER}-rfsim\" );|" "$DU_CONF"

HEX=$(printf '%x' $((0xe00 + DU_NUMBER - 1)))

# Set unique gNB_ID, gNB_DU_ID, gNB_name, nr_cellid, physCellId, local_n_address, and remote_n_address
sed -i "s|^\([[:space:]]*\)gNB_ID\s*=.*|\1gNB_ID = 0x$HEX;|" "$DU_CONF"
sed -i "s|^\([[:space:]]*\)gNB_DU_ID\s*=.*|\1gNB_DU_ID = 0x$HEX;|" "$DU_CONF"
awk -v hex="$HEX" '
FNR==NR { if ($0 ~ /^\s*gNB_DU_ID\s*=/) found=1; next }
{
    print
    if (!found && $0 ~ /^\s*gNB_ID\s*=/) {
        sub(/[^ ].*$/, "", $0)
        print $0 "gNB_DU_ID = 0x" hex ";"
        found=1
    }
}
' "$DU_CONF" "$DU_CONF" >"$DU_CONF.tmp" && mv "$DU_CONF.tmp" "$DU_CONF"
sed -i "s|^\([[:space:]]*\)gNB_name\s*=.*|\1gNB_name = \"du${DU_NUMBER}-rfsim\";|" "$DU_CONF"
sed -i "s|^\([[:space:]]*\)nr_cellid\s*=.*|\1nr_cellid = $((11111111 + DU_NUMBER - 1))L;|" "$DU_CONF"
sed -i "s|^\([[:space:]]*\)physCellId\s*=.*|\1physCellId = $((DU_NUMBER - 1));|" "$DU_CONF"

if ! command -v python3 &>/dev/null; then
    echo "Python is not installed. Installing Python..."
    sudo apt-get update
    sudo apt-get install -y python3
fi

DU_IP_INDEX=$((DU_NUMBER + 99)) # The CU is 127.0.0.100, and DU 1 is 127.0.0.101
LOCAL_N_ADDRESS="$(python3 install_scripts/fetch_nth_ip.py "127.0.0.0/24" "$DU_IP_INDEX")"
REMOTE_N_ADDRESS="127.0.0.3"

# Set local_n_address and remote_n_address inside the MACRLCs section
awk -v local_addr="$LOCAL_N_ADDRESS" -v remote_addr="$REMOTE_N_ADDRESS" '
    /^[[:space:]]*MACRLCs[[:space:]]*=\s*\(/ { in_m=1; ins=0; tnp_ins=0 }
    in_m && /^[[:space:]]*\)\s*;/ { print; in_m=0; next }
    in_m && /^[[:space:]]*(local_n_address|remote_n_address)[[:space:]]*=/ { next }
    in_m && /^[[:space:]]*tr_n_preference[[:space:]]*=/ {
    if (tnp_ins) { next }
    match($0, /^[[:space:]]*/); ind=substr($0,1,RLENGTH)
    printf "%str_n_preference             = \"f1\";\n", ind
    if (!ins) {
        printf "%slocal_n_address             = \"%s\";\n%sremote_n_address            = \"%s\";\n", ind, local_addr, ind, remote_addr
        ins=1
    }
    next
    }
    in_m && !ins && /^[[:space:]]*num_cc[[:space:]]*=/ {
    print
    match($0, /^[[:space:]]*/); ind=substr($0,1,RLENGTH)
    printf "%str_n_preference             = \"f1\";\n%slocal_n_address             = \"%s\";\n%sremote_n_address            = \"%s\";\n", ind, ind, local_addr, ind, remote_addr
    ins=1
    tnp_ins=1
    next
    }
    { print }
' "$DU_CONF" >"$DU_CONF.tmp" && mv "$DU_CONF.tmp" "$DU_CONF"

comment_out "$DU_CONF" "amf_ip_address"

# Comment out the entire security section since the CU handles security
awk '
    BEGIN { in_sec=0 }
    /^[[:space:]]*security[[:space:]]*=[[:space:]]*{[[:space:]]*$/ { print "#"$0; in_sec=1; next }
    in_sec && /^[[:space:]]*}[[:space:]]*;[[:space:]]*$/ { print "#"$0; in_sec=0; next }
    in_sec { print "#"$0; next }
    { print }
' "$DU_CONF" >"$DU_CONF.tmp" && mv "$DU_CONF.tmp" "$DU_CONF"

comment_out "$DU_CONF" "serveraddr"

echo "    Configured DU $DU_NUMBER."

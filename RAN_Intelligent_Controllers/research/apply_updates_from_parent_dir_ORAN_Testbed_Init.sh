#!/bin/bash

echo
echo
echo

set -e
set -x

if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

PATCH_FILES="$SCRIPT_DIR/PATCHED_OAI_FILES"
FERNANDO_OAI="$HOME/Desktop/FERNANDO_PUBLICSAFETY_REPOS/oai5G"
FERNANDO_FLEXRIC="$HOME/Desktop/FERNANDO_PUBLICSAFETY_REPOS/flexric_e2sm_radio_metrics"

if [ ! -d "$FERNANDO_OAI" ]; then
    echo "Path doesn't exist: $FERNANDO_OAI"
    exit 1
fi
if [ ! -d "$FERNANDO_FLEXRIC" ]; then
    echo "Path doesn't exist: $FERNANDO_FLEXRIC"
    exit 1
fi

# FLEXRIC
cp $PATCH_FILES/xapp_kpm_moni.c $FERNANDO_FLEXRIC/examples/xApp/c/monitor/xapp_kpm_moni.c
cp $PATCH_FILES/xapp_kpm_moni_write_to_csv.c $FERNANDO_FLEXRIC/examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv.c
#cp $PATCH_FILES/FLEXRIC_CMakeLists.txt $FERNANDO_FLEXRIC/examples/xApp/c/monitor/CMakeLists.txt

# OAI
cp $PATCH_FILES/ran_func_kpm.c $FERNANDO_OAI/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c
cp $PATCH_FILES/ran_func_kpm_subs.c $FERNANDO_OAI/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c
cp $PATCH_FILES/main.c $FERNANDO_OAI/openair2/LAYER2/NR_MAC_gNB/main.c
cp $PATCH_FILES/nr_mac_gNB.h $FERNANDO_OAI/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h
cp $PATCH_FILES/gNB_scheduler_dlsch.c $FERNANDO_OAI/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c
# Handled elsewhere? cp $PATCH_FILES/OAI_CMakeLists.txt $FERNANDO_OAI/CMakeLists.txt

echo "SUCCESS."

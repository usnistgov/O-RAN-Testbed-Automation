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
cd "$FERNANDO_FLEXRIC"
git pull
sudo rm -rf install_patch_files
cp -r "$SCRIPT_DIR/../../OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC/install_patch_files/" install_patch_files
./apply_patches.sh

# OAI
# cp $PATCH_FILES/ran_func_kpm.c $FERNANDO_OAI/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c
# cp $PATCH_FILES/ran_func_kpm_subs.c $FERNANDO_OAI/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c
# cp $PATCH_FILES/main.c $FERNANDO_OAI/openair2/LAYER2/NR_MAC_gNB/main.c
# cp $PATCH_FILES/nr_mac_gNB.h $FERNANDO_OAI/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h
# cp $PATCH_FILES/gNB_scheduler_dlsch.c $FERNANDO_OAI/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c
# # Handled elsewhere? cp $PATCH_FILES/OAI_CMakeLists.txt $FERNANDO_OAI/CMakeLists.txt

cd "$SCRIPT_DIR"

cd "$FERNANDO_OAI"
git pull
sudo rm -rf install_patch_files
cp -r "$SCRIPT_DIR/../../OpenAirInterface_Testbed/User_Equipment/install_patch_files/" install_patch_files
./apply_patches.sh

# # Apply patches to OpenAirInterface to add support for additional metrics in the KPI report
# cp openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.previous
# echo
# echo "Patching ran_func_kpm.c..."
# cd openairinterface5g
# git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c
# git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm.c.patch"
# cd ..

# cp openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c openairinterface5g/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.previous
# echo
# echo "Patching ran_func_kpm_subs.c..."
# cd openairinterface5g
# git restore openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c
# git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/E2AP/RAN_FUNCTION/O-RAN/ran_func_kpm_subs.c.patch"
# cd ..

# cp openairinterface5g/openair2/LAYER2/NR_MAC_gNB/main.c openairinterface5g/openair2/LAYER2/NR_MAC_gNB/main.c.previous
# echo
# echo "Patching main.c..."
# cd openairinterface5g
# git restore openair2/LAYER2/NR_MAC_gNB/main.c
# git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/main.c.patch"
# cd ..

# cp openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h openairinterface5g/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.previous
# echo
# echo "Patching nr_mac_gNB.h..."
# cd openairinterface5g
# git restore openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h
# git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/nr_mac_gNB.h.patch"
# cd ..

# cp openairinterface5g/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c openairinterface5g/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.previous
# echo
# echo "Patching gNB_scheduler_dlsch.c..."
# cd openairinterface5g
# git restore openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c
# git apply --verbose --ignore-whitespace "$SCRIPT_DIR/install_patch_files/openairinterface/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c.patch"
# cd ..


echo "SUCCESS."

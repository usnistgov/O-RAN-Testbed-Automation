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

UE_NUMBER=1
if [ "$#" -eq 1 ]; then
    UE_NUMBER=$1
fi
if ! [[ $UE_NUMBER =~ ^[0-9]+$ ]]; then
    echo "ERROR: UE number must be a number."
    exit 1
fi
if [ $UE_NUMBER -lt 1 ]; then
    echo "ERROR: UE number must be greater than or equal to 1."
    exit 1
fi

validate_srsue_binary() {
    SRSUE_BIN="srsRAN_4G/build/srsue/src/srsue"
    if [ ! -f "$SRSUE_BIN" ]; then
        echo "ERROR: srsue binary was not found. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -q 'rach_cfg_nr->nof_preambles[[:space:]]*=[[:space:]]*64;' "srsRAN_4G/lib/src/asn1/rrc_nr_utils.cc"; then
        echo "ERROR: srsRAN_4G source is missing the NR RA preamble default patch. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -q 'get_nof_cb_preambles_per_ssb' "srsRAN_4G/lib/src/asn1/rrc_nr_utils.cc"; then
        echo "ERROR: srsRAN_4G source is missing the NR RA CB-preambles-per-SSB patch. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -q 'srsran_random_uniform_int_dist(random_gen, 0, rach_cfg.nof_preambles - 1)' "srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc"; then
        echo "ERROR: srsRAN_4G source is missing the valid NR RA preamble range patch. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -q 'rach_cfg.nof_preambles[[:space:]]*=[[:space:]]*64;' "srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc"; then
        echo "ERROR: srsRAN_4G source is missing the NR RA preamble fallback patch. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -q 'static_cast<uint32_t>(getpid())' "srsRAN_4G/srsue/src/stack/mac_nr/proc_ra_nr.cc"; then
        echo "ERROR: srsRAN_4G source is missing the NR RA random seed patch. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -q 'old_lcg_it' "srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr.cc"; then
        echo "ERROR: srsRAN_4G source is missing the NR BSR first-data patch. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -Fq 'lcg_priorities[priority] = new_lcg;' "srsRAN_4G/srsue/src/stack/mac_nr/proc_bsr_nr.cc"; then
        echo "ERROR: srsRAN_4G source is missing the NR BSR LCID priority patch. Please run ./full_install.sh."
        exit 1
    fi

    if ! grep -q 'sr_prohibit_counter' "srsRAN_4G/srsue/hdr/stack/mac_nr/proc_sr_nr.h"; then
        echo "ERROR: srsRAN_4G source is missing the NR SR prohibit timer state patch. Please run ./full_install.sh."
        exit 1
    fi

    if grep -q "sr-ProhibitTimer isn't supported" "srsRAN_4G/srsue/src/stack/mac_nr/proc_sr_nr.cc"; then
        echo "ERROR: srsRAN_4G source still rejects NR SR prohibit timer. Please run ./full_install.sh."
        exit 1
    fi

    if command -v strings >/dev/null 2>&1; then
        if ! strings "$SRSUE_BIN" | grep -q 'RAR timeout: preamble_index='; then
            echo "ERROR: srsue binary is missing the NR RA timeout diagnostic patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
        if ! strings "$SRSUE_BIN" | grep -q 'Invalid NR RA preamble count'; then
            echo "ERROR: srsue binary is missing the NR RA preamble fallback diagnostic patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
        if ! strings "$SRSUE_BIN" | grep -q 'Random Access Transmission: prach_occasion=%d, preamble_index=%d, nof_preambles=%d'; then
            echo "ERROR: srsue binary is missing the NR RA preamble count console patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
        if ! strings "$SRSUE_BIN" | grep -q 'BSR:   New data available for LCG=%d old=%d new=%d'; then
            echo "ERROR: srsue binary is missing the NR BSR first-data diagnostic patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
        if ! strings "$SRSUE_BIN" | grep -q 'RRC NR PUCCH SR resource:'; then
            echo "ERROR: srsue binary is missing the NR PUCCH SR diagnostic patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
        if ! strings "$SRSUE_BIN" | grep -q 'SR: signalling tti='; then
            echo "ERROR: srsue binary is missing the NR SR signalling diagnostic patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
        if ! strings "$SRSUE_BIN" | grep -q 'NR UL PUCCH UCI:'; then
            echo "ERROR: srsue binary is missing the NR PUCCH UCI diagnostic patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
        if ! strings "$SRSUE_BIN" | grep -q 'NR UL PUSCH grant:'; then
            echo "ERROR: srsue binary is missing the NR PUSCH grant diagnostic patch. Please rebuild with ./full_install.sh."
            exit 1
        fi
    fi

    if [ -d "install_patch_files/srsRAN_4G" ] &&
        find install_patch_files/srsRAN_4G -type f -newer "$SRSUE_BIN" | grep -q .; then
        echo "ERROR: srsue binary is older than the local srsRAN_4G patch files. Please run ./full_install.sh."
        exit 1
    fi
}

write_srsue_launch_stamp() {
    SRSUE_BIN="srsRAN_4G/build/srsue/src/srsue"
    {
        echo "Using srsue binary: $SCRIPT_DIR/$SRSUE_BIN"
        echo "srsue binary timestamp: $(date -r "$SRSUE_BIN" '+%Y-%m-%d %H:%M:%S %z')"
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$SRSUE_BIN"
        fi
    } >>"logs/ue${UE_NUMBER}_stdout.txt"
}

UE_CONF_PATH="configs/ue$UE_NUMBER.conf"
if [ ! -f "$UE_CONF_PATH" ]; then
    echo "Configuration file for UE $UE_NUMBER not found, creating..."
    ./generate_configurations.sh "$UE_NUMBER"
    if [ ! -f "$UE_CONF_PATH" ]; then
        echo "Configuration file for UE $UE_NUMBER still not found after generation."
        exit 1
    fi
fi

validate_srsue_binary

echo "Using srsue binary: $SCRIPT_DIR/srsRAN_4G/build/srsue/src/srsue"
echo "Starting User Equipment in background..."
mkdir -p logs
>logs/ue${UE_NUMBER}_stdout.txt
sudo chown --recursive "${SUDO_USER:-$USER}" logs
write_srsue_launch_stamp

sudo -v # Ensure sudo session is active
sudo setsid bash -c "stdbuf -oL -eL \"$SCRIPT_DIR/run.sh\" $UE_NUMBER >/dev/null 2>&1" </dev/null &

ATTEMPT=0
while ! ./is_running.sh | grep -q "ue$UE_NUMBER"; do
    sleep 0.5
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 120 ]; then
        echo "UE did not start after 60 seconds, exiting..."
        exit 1
    fi
done

./is_running.sh

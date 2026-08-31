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

echo "# Script: $(realpath "$0") $@"

# Exit immediately if a command fails
set -e

OUTPUT="zmq_channel_emulator/zmq_channel_emulator.py"
SAMPLE_RATE_HZ="23040000"
SLOW_DOWN_RATIO="1"
CELL_NUMBERS=()
UE_NUMBERS=()
UE_IPS=()
VALIDATED_CELL_NUMBERS=()

usage() {
    echo "Usage: $0 --cells <cell_numbers> --ues <ue_numbers> [--output FILE] [--sample-rate-hz HZ] [--slow-down-ratio N]"
}

# Script directory from the called path, including symlinks
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
PARENT_DIR=$(dirname "$SCRIPT_DIR")
case "$(basename "$PARENT_DIR")" in
Next_Generation_Node_B)
    UE_NAMESPACE_SCRIPT="$PARENT_DIR/../User_Equipment/install_scripts/get_ue_namespace_ip.sh"
    ;;
User_Equipment)
    UE_NAMESPACE_SCRIPT="$PARENT_DIR/install_scripts/get_ue_namespace_ip.sh"
    ;;
OpenAirInterface_UE)
    UE_NAMESPACE_SCRIPT="$PARENT_DIR/../../User_Equipment/install_scripts/get_ue_namespace_ip.sh"
    ;;
*)
    echo "ERROR: Unable to find get_ue_namespace_ip.sh from $PARENT_DIR." >&2
    exit 1
    ;;
esac
if [ ! -x "$UE_NAMESPACE_SCRIPT" ]; then
    echo "ERROR: UE namespace address script not found: $UE_NAMESPACE_SCRIPT" >&2
    exit 1
fi
cd "$PARENT_DIR"

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! python3 -c 'import numpy as np; import sys; sys.exit(0 if int(np.__version__.split(".", 1)[0]) < 2 else 1)' >/dev/null 2>&1; then
    echo "Installing NumPy via pip..."
    if ! python3 -m pip install --user 'numpy<2'; then
        echo
        echo "Installing NumPy via apt-get, since pip install failed..."
        sudo apt-get update
        sudo env $APTVARS apt-get install -y python3-numpy
    fi
fi

if ! python3 -m pip show PyQt5 >/dev/null 2>&1; then
    echo "Installing PyQt5 via pip..."
    if ! python3 -m pip install --user PyQt5; then
        echo
        echo "Installing PyQt5 via apt-get, since pip install failed..."
        sudo apt-get update
        sudo env $APTVARS apt-get install -y python3-pyqt5
    fi
fi

if ! python3 -c 'from gnuradio import blocks' >/dev/null 2>&1; then
    echo "Installing GNU Radio via apt-get..."
    APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
    sudo apt-get update
    sudo env $APTVARS apt-get install -y gnuradio
fi

while [ $# -gt 0 ]; do
    case "$1" in
    --output)
        OUTPUT="$2"
        shift 2
        ;;
    --sample-rate-hz)
        SAMPLE_RATE_HZ="$2"
        shift 2
        ;;
    --slow-down-ratio)
        SLOW_DOWN_RATIO="$2"
        shift 2
        ;;
    --cells)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --cells requires comma-separated cell numbers."
            usage
            exit 1
        fi
        IFS=',' read -r -a PARSED_CELL_NUMBERS <<<"$2"
        CELL_NUMBERS+=("${PARSED_CELL_NUMBERS[@]}")
        shift 2
        ;;
    --ues)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
            echo "ERROR: --ues requires comma-separated UE numbers."
            usage
            exit 1
        fi
        IFS=',' read -r -a PARSED_UE_NUMBERS <<<"$2"
        for UE_NUMBER in "${PARSED_UE_NUMBERS[@]}"; do
            if ! [[ "$UE_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
                echo "ERROR: --ues must contain positive integers ($UE_NUMBER)."
                exit 1
            fi
            for EXISTING_UE in "${UE_NUMBERS[@]}"; do
                if [ "$EXISTING_UE" = "$UE_NUMBER" ]; then
                    echo "ERROR: UE $UE_NUMBER was provided more than once."
                    exit 1
                fi
            done
            UE_NUMBERS+=("$UE_NUMBER")
        done
        shift 2
        ;;
    *)
        echo "ERROR: Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
done

if [ ${#UE_NUMBERS[@]} -eq 0 ] || [ ${#CELL_NUMBERS[@]} -eq 0 ]; then
    usage
    exit 1
fi
if ! [[ "$SAMPLE_RATE_HZ" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: --sample-rate-hz must be a positive integer ($SAMPLE_RATE_HZ)."
    exit 1
fi
if ! [[ "$SLOW_DOWN_RATIO" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: --slow-down-ratio must be a positive integer ($SLOW_DOWN_RATIO)."
    exit 1
fi

for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
    if ! [[ "$CELL_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: --cells must contain positive integers ($CELL_NUMBER)."
        exit 1
    fi
    for EXISTING_CELL in "${VALIDATED_CELL_NUMBERS[@]}"; do
        if [ "$EXISTING_CELL" = "$CELL_NUMBER" ]; then
            echo "ERROR: Cell $CELL_NUMBER was provided more than once."
            exit 1
        fi
    done
    VALIDATED_CELL_NUMBERS+=("$CELL_NUMBER")
    CELL_RX_PORT=$((2000 + (CELL_NUMBER - 1) * 2))
    CELL_TX_PORT=$((CELL_RX_PORT + 1))
    if [ "$CELL_TX_PORT" -gt 65535 ]; then
        echo "ERROR: Cell $CELL_NUMBER has a ZeroMQ port above 65535."
        exit 1
    fi
done

for UE_NUMBER in "${UE_NUMBERS[@]}"; do
    UE_RX_PORT=$((2000 + UE_NUMBER * 100))
    UE_TX_PORT=$((UE_RX_PORT + 1))
    if [ "$UE_TX_PORT" -gt 65535 ]; then
        echo "ERROR: UE $UE_NUMBER has a ZeroMQ port above 65535."
        exit 1
    fi

    for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
        CELL_RX_PORT=$((2000 + (CELL_NUMBER - 1) * 2))
        CELL_TX_PORT=$((2001 + (CELL_NUMBER - 1) * 2))
        if [ "$CELL_RX_PORT" -eq "$UE_RX_PORT" ] || [ "$CELL_RX_PORT" -eq "$UE_TX_PORT" ] ||
            [ "$CELL_TX_PORT" -eq "$UE_RX_PORT" ] || [ "$CELL_TX_PORT" -eq "$UE_TX_PORT" ]; then
            echo "ERROR: Cell $CELL_NUMBER and UE $UE_NUMBER produce colliding ZeroMQ ports ($CELL_RX_PORT/$CELL_TX_PORT and $UE_RX_PORT/$UE_TX_PORT)."
            exit 1
        fi
    done
    UE_IP=$("$UE_NAMESPACE_SCRIPT" ue "$UE_NUMBER")
    UE_IPS+=("$UE_IP")
done

ZMQ_DIR="$(dirname "$OUTPUT")"
mkdir -p "$ZMQ_DIR"
rm -f "$ZMQ_DIR/multi_ue_scenario.grc" "$ZMQ_DIR/multi_ue_scenario.grc.license" \
    "$ZMQ_DIR/multi_ue_scenario.grc.tmp" "$ZMQ_DIR/multi_ue_scenario.grc.license.tmp"

cat >"$OUTPUT" <<EOF
#!/usr/bin/env python3
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

# WARNING: Auto-generated ZeroMQ Channel Emulator, overwritten with the script: ./Next_Generation_Node_B/install_scripts/generate_nist_zmq_channel_emulator.sh

EOF

CELL_COUNT=0
for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
    CELL_RX_PORT=$((2000 + (CELL_NUMBER - 1) * 2))
    CELL_TX_PORT=$((2001 + (CELL_NUMBER - 1) * 2))
    echo "# CELL_CONFIG: $CELL_NUMBER $CELL_RX_PORT $CELL_TX_PORT" >>"$OUTPUT"
done

for INDEX in "${!UE_NUMBERS[@]}"; do
    UE_NUMBER="${UE_NUMBERS[$INDEX]}"
    UE_RX_PORT=$((2000 + UE_NUMBER * 100))
    UE_TX_PORT=$((2001 + UE_NUMBER * 100))
    echo "# UE_CONFIG: $UE_NUMBER $UE_RX_PORT $UE_TX_PORT ${UE_IPS[$INDEX]}" >>"$OUTPUT"
done

cat >>"$OUTPUT" <<EOF

import ctypes
import json
import signal
import sys

import numpy as np

from PyQt5 import Qt
from PyQt5 import QtCore

from gnuradio import analog
from gnuradio import blocks
from gnuradio import gr
from gnuradio import qtgui
from gnuradio import zeromq

if sys.platform.startswith("linux"):
    try:
        ctypes.cdll.LoadLibrary("libX11.so").XInitThreads()
        # ctypes.cdll.LoadLibrary("libX11.so.6").XInitThreads()
    except Exception:
        print("Warning: failed to XInitThreads()")

CELL_CONFIGS = [
EOF

for CELL_NUMBER in "${CELL_NUMBERS[@]}"; do
    CELL_RX_PORT=$((2000 + (CELL_NUMBER - 1) * 2))
    CELL_TX_PORT=$((2001 + (CELL_NUMBER - 1) * 2))
    echo "    {'number': $CELL_NUMBER, 'rx_port': $CELL_RX_PORT, 'tx_port': $CELL_TX_PORT}," >>"$OUTPUT"
done

cat >>"$OUTPUT" <<EOF
]
UE_CONFIGS = [
EOF

for INDEX in "${!UE_NUMBERS[@]}"; do
    UE_NUMBER="${UE_NUMBERS[$INDEX]}"
    UE_RX_PORT=$((2000 + UE_NUMBER * 100))
    UE_TX_PORT=$((2001 + UE_NUMBER * 100))
    echo "    {'number': $UE_NUMBER, 'rx_port': $UE_RX_PORT, 'tx_port': $UE_TX_PORT, 'ue_ip': '${UE_IPS[$INDEX]}'}," >>"$OUTPUT"
done

cat >>"$OUTPUT" <<'EOF'
]
SAMPLE_RATE_HZ = __SAMPLE_RATE_HZ__
SLOW_DOWN_RATIO = __SLOW_DOWN_RATIO__
PATH_LOSS_WARNING_DB = 12.0
PATH_LOSS_RED_DB = 50.0
PATH_LOSS_MAX_DB = 100.0
ZMQ_TIMEOUT = 100
ZMQ_HIGH_WATER_MARK = -1
DL_AWGN_SNR_DB = 30.0
UL_AWGN_SNR_DB = 30.0
AWGN_SNR_MIN_DB = -30.0
AWGN_SNR_MAX_DB = 100.0
PATH_ENABLED = True
PATH_LOSS_LINKED = True
DL_AWGN_ENABLED = False
UL_AWGN_ENABLED = True


class awgn_mix_cc(gr.sync_block):
    def __init__(self, snr_db, enabled=True):
        gr.sync_block.__init__(
            self,
            name="Complex AWGN Mixer",
            in_sig=[np.complex64, np.complex64],
            out_sig=[np.complex64],
        )
        self.enabled = bool(enabled)
        self.snr_gain = np.float32(10.0 ** (-float(snr_db) / 20.0))

    def set_snr_db(self, snr_db):
        self.snr_gain = np.float32(10.0 ** (-float(snr_db) / 20.0))

    def set_enabled(self, enabled):
        self.enabled = bool(enabled)

    def work(self, input_items, output_items):
        signal_samples = input_items[0]
        noise_samples = input_items[1]
        output_samples = output_items[0]
        sample_count = len(output_samples)

        if sample_count == 0:
            return 0

        if not self.enabled:
            np.copyto(output_samples, signal_samples)
            return sample_count

        signal_power = float(np.vdot(signal_samples, signal_samples).real) / sample_count
        if signal_power <= 0.0 or not np.isfinite(signal_power):
            np.copyto(output_samples, signal_samples)
            return sample_count

        noise_gain = np.float32(np.sqrt(signal_power)) * self.snr_gain
        np.multiply(noise_samples, noise_gain, out=output_samples)
        np.add(signal_samples, output_samples, out=output_samples)
        return sample_count


class awgn_cc(gr.hier_block2):
    def __init__(self, snr_db, enabled=True):
        gr.hier_block2.__init__(
            self,
            "Complex AWGN",
            gr.io_signature(1, 1, gr.sizeof_gr_complex),
            gr.io_signature(1, 1, gr.sizeof_gr_complex),
        )
        self.enabled = False
        self.snr_db = 0.0
        self.mixer = awgn_mix_cc(0.0, False)
        self.noise_source = analog.fastnoise_source_c(
            analog.GR_GAUSSIAN,
            1.0,
            int(np.random.randint(1, 2**31 - 1)),
            8192,
        )

        self.connect(self, (self.mixer, 0))
        self.connect(self.noise_source, (self.mixer, 1))
        self.connect(self.mixer, self)

        self.set_snr_db(snr_db)
        self.set_enabled(enabled)

    def set_snr_db(self, snr_db):
        snr_db = float(snr_db)
        if not np.isfinite(snr_db):
            return
        self.snr_db = min(max(snr_db, AWGN_SNR_MIN_DB), AWGN_SNR_MAX_DB)
        self.mixer.set_snr_db(self.snr_db)

    def set_enabled(self, enabled):
        self.enabled = bool(enabled)
        self.mixer.set_enabled(self.enabled)


class SliderSpinBox(Qt.QWidget):
    valueChanged = QtCore.pyqtSignal(float)

    def __init__(self, minimum, maximum, step, value):
        Qt.QWidget.__init__(self)
        self.minimum = float(minimum)
        self.maximum = float(maximum)
        self.step = float(step)

        layout = Qt.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self.slider = Qt.QSlider(QtCore.Qt.Horizontal)
        self.slider.setRange(0, int(round((maximum - minimum) / step)))
        self.slider.setTracking(False)
        self.spin_box = Qt.QDoubleSpinBox()
        self.spin_box.setRange(minimum, maximum)
        self.spin_box.setSingleStep(step)
        self.spin_box.setDecimals(1)
        self.spin_box.setKeyboardTracking(False)
        self.spin_box.setMinimumWidth(90)
        layout.addWidget(self.slider, 1)
        layout.addWidget(self.spin_box)

        self.slider.valueChanged.connect(self._slider_changed)
        self.spin_box.valueChanged.connect(self._spin_box_changed)
        self.set_value(value, emit=False)

    def _slider_changed(self, slider_value):
        value = self.minimum + slider_value * self.step
        self.spin_box.blockSignals(True)
        self.spin_box.setValue(value)
        self.spin_box.blockSignals(False)
        self.valueChanged.emit(float(value))

    def _spin_box_changed(self, value):
        self.slider.blockSignals(True)
        self.slider.setValue(int(round((value - self.minimum) / self.step)))
        self.slider.blockSignals(False)
        self.valueChanged.emit(float(value))

    def set_value(self, value, emit=True):
        value = float(value)
        if not np.isfinite(value):
            return
        value = min(max(value, self.minimum), self.maximum)
        changed = abs(self.spin_box.value() - value) > 1e-9
        self.slider.blockSignals(True)
        self.spin_box.blockSignals(True)
        self.slider.setValue(int(round((value - self.minimum) / self.step)))
        self.spin_box.setValue(value)
        self.slider.blockSignals(False)
        self.spin_box.blockSignals(False)
        if emit and changed:
            self.valueChanged.emit(value)


class zmq_channel_emulator(gr.top_block, Qt.QWidget):
    def __init__(self):
        try:
            gr.top_block.__init__(
                self, "ZeroMQ Channel Emulator", catch_exceptions=True
            )
        except TypeError:
            gr.top_block.__init__(self, "ZeroMQ Channel Emulator")
        Qt.QWidget.__init__(self)
        self.setWindowTitle("ZeroMQ Channel Emulator")
        self.resize(540, 600)
        qtgui.util.check_set_qss()

        self.top_layout = Qt.QVBoxLayout()
        self.top_layout.setContentsMargins(6, 6, 6, 6)
        self.top_layout.setSpacing(4)
        self.setLayout(self.top_layout)
        self.settings = Qt.QSettings("GNU Radio", "zmq_channel_emulator")
        try:
            self.restoreGeometry(self.settings.value("geometry"))
        except Exception:
            pass

        self.samp_rate = SAMPLE_RATE_HZ
        self.slow_down_ratio = SLOW_DOWN_RATIO
        self.dl_awgn_snr_db = DL_AWGN_SNR_DB
        self.ul_awgn_snr_db = UL_AWGN_SNR_DB

        self.dl_path_loss_db = {}
        self.ul_path_loss_db = {}
        self.path_enabled = {}
        self.path_loss_linked = {}
        self.dl_awgn_enabled = {}
        self.dl_awgn_snr_db_by_path = {}
        self.ul_awgn_enabled = {}
        self.ul_awgn_snr_db_by_cell = {}
        self.default_link_settings = {}
        self.default_cell_settings = {}
        for cell_index, cell in enumerate(CELL_CONFIGS):
            cell_number = cell["number"]
            self.ul_awgn_enabled[cell_number] = UL_AWGN_ENABLED
            self.ul_awgn_snr_db_by_cell[cell_number] = UL_AWGN_SNR_DB
            self.default_cell_settings[cell_number] = {
                "ul_awgn_enabled": UL_AWGN_ENABLED,
                "ul_awgn_snr_db": UL_AWGN_SNR_DB,
            }
            for ue in UE_CONFIGS:
                ue_number = ue["number"]
                if cell_index == (ue_number - 1) % len(CELL_CONFIGS):
                    path_loss_db = 0
                else:
                    path_loss_db = 12

                path_key = (cell_number, ue_number)
                self.dl_path_loss_db[path_key] = path_loss_db
                self.ul_path_loss_db[path_key] = path_loss_db
                self.path_enabled[path_key] = PATH_ENABLED
                self.path_loss_linked[path_key] = PATH_LOSS_LINKED
                self.dl_awgn_enabled[path_key] = DL_AWGN_ENABLED
                self.dl_awgn_snr_db_by_path[path_key] = DL_AWGN_SNR_DB
                self.default_link_settings[path_key] = {
                    "path_enabled": PATH_ENABLED,
                    "path_loss_linked": PATH_LOSS_LINKED,
                    "dl_path_loss_db": path_loss_db,
                    "ul_path_loss_db": path_loss_db,
                    "dl_awgn_enabled": DL_AWGN_ENABLED,
                    "dl_awgn_snr_db": DL_AWGN_SNR_DB,
                }

        self.gnb_dl_sources = {}
        self.gnb_ul_sinks = {}
        self.dl_throttles = {}
        self.ue_dl_sinks = {}
        self.ue_ul_sources = {}
        self.ue_dl_adds = {}
        self.cell_ul_adds = {}
        self.dl_awgn = {}
        self.cell_ul_awgn = {}
        self.dl_gains = {}
        self.ul_gains = {}
        self.path_enabled_checkboxes = {}
        self.path_loss_linked_checkboxes = {}
        self.dl_path_loss_controls = {}
        self.ul_path_loss_controls = {}
        self.dl_awgn_enabled_checkboxes = {}
        self.dl_awgn_snr_controls = {}
        self.ul_awgn_enabled_checkboxes = {}
        self.ul_awgn_snr_controls = {}
        self.topology_items = {}
        self.cell_scroll_areas = {}
        self.link_groups = {}
        self.selected_topology_path = None
        self.highlighted_link_group = None

        status = (
            f"ZeroMQ Channel Emulator sample_rate={SAMPLE_RATE_HZ} "
            f"slow_down_ratio={SLOW_DOWN_RATIO} cells={len(CELL_CONFIGS)} "
            f"ues={len(UE_CONFIGS)}"
        )
        print(status, flush=True)

        for cell in CELL_CONFIGS:
            cell_number = cell["number"]
            status = (
                f"ZeroMQ Channel Emulator Cell{cell_number} gNB DL source "
                f"tcp://127.0.0.1:{cell['rx_port']} UL sink "
                f"tcp://127.0.0.1:{cell['tx_port']}"
            )
            print(status, flush=True)
            self.gnb_dl_sources[cell_number] = zeromq.req_source(
                gr.sizeof_gr_complex,
                1,
                f"tcp://127.0.0.1:{cell['rx_port']}",
                ZMQ_TIMEOUT,
                False,
                ZMQ_HIGH_WATER_MARK,
            )
            self.gnb_ul_sinks[cell_number] = zeromq.rep_sink(
                gr.sizeof_gr_complex,
                1,
                f"tcp://127.0.0.1:{cell['tx_port']}",
                ZMQ_TIMEOUT,
                False,
                ZMQ_HIGH_WATER_MARK,
            )
            self.dl_throttles[cell_number] = blocks.throttle(
                gr.sizeof_gr_complex, self.samp_rate / self.slow_down_ratio, True
            )
            self.cell_ul_adds[cell_number] = blocks.add_vcc(1)
            self.cell_ul_awgn[cell_number] = awgn_cc(
                self.ul_awgn_snr_db_by_cell[cell_number],
                self.ul_awgn_enabled[cell_number],
            )

        for ue in UE_CONFIGS:
            ue_number = ue["number"]
            status = (
                f"ZeroMQ Channel Emulator UE{ue_number} DL sink "
                f"tcp://*:{ue['rx_port']} UL source "
                f"tcp://{ue['ue_ip']}:{ue['tx_port']}"
            )
            print(status, flush=True)
            self.ue_dl_adds[ue_number] = blocks.add_vcc(1)
            self.dl_awgn[ue_number] = awgn_cc(
                self.dl_awgn_snr_db,
                DL_AWGN_ENABLED,
            )
            self.ue_dl_sinks[ue_number] = zeromq.rep_sink(
                gr.sizeof_gr_complex,
                1,
                f"tcp://*:{ue['rx_port']}",
                ZMQ_TIMEOUT,
                False,
                ZMQ_HIGH_WATER_MARK,
            )
            self.ue_ul_sources[ue_number] = zeromq.req_source(
                gr.sizeof_gr_complex,
                1,
                f"tcp://{ue['ue_ip']}:{ue['tx_port']}",
                ZMQ_TIMEOUT,
                False,
                ZMQ_HIGH_WATER_MARK,
            )

        for cell in CELL_CONFIGS:
            cell_number = cell["number"]
            self.connect(
                (self.gnb_dl_sources[cell_number], 0),
                (self.dl_throttles[cell_number], 0),
            )
            self.connect(
                (self.cell_ul_adds[cell_number], 0),
                (self.cell_ul_awgn[cell_number], 0),
            )
            self.connect(
                (self.cell_ul_awgn[cell_number], 0),
                (self.gnb_ul_sinks[cell_number], 0),
            )

        for ue in UE_CONFIGS:
            ue_number = ue["number"]
            self.connect(
                (self.ue_dl_adds[ue_number], 0),
                (self.dl_awgn[ue_number], 0),
            )
            self.connect(
                (self.dl_awgn[ue_number], 0),
                (self.ue_dl_sinks[ue_number], 0),
            )

        for ue_index, ue in enumerate(UE_CONFIGS):
            ue_number = ue["number"]
            for cell_index, cell in enumerate(CELL_CONFIGS):
                cell_number = cell["number"]
                path_key = (cell_number, ue_number)
                if self.path_enabled[path_key]:
                    dl_gain = self.path_loss_db_to_iq_gain(
                        self.dl_path_loss_db[path_key]
                    )
                    ul_gain = self.path_loss_db_to_iq_gain(
                        self.ul_path_loss_db[path_key]
                    )
                else:
                    dl_gain = 0.0
                    ul_gain = 0.0
                self.dl_gains[path_key] = blocks.multiply_const_cc(dl_gain)
                self.ul_gains[path_key] = blocks.multiply_const_cc(ul_gain)

                self.connect(
                    (self.dl_throttles[cell_number], 0), (self.dl_gains[path_key], 0)
                )
                self.connect(
                    (self.dl_gains[path_key], 0),
                    (self.ue_dl_adds[ue_number], cell_index),
                )
                self.connect(
                    (self.ue_ul_sources[ue_number], 0), (self.ul_gains[path_key], 0)
                )
                self.connect(
                    (self.ul_gains[path_key], 0),
                    (self.cell_ul_adds[cell_number], ue_index),
                )

        self.build_interface()

    def build_interface(self):
        self.topology_table = Qt.QTableWidget(len(UE_CONFIGS), len(CELL_CONFIGS) + 1)
        topology_font = self.topology_table.font()
        topology_font.setPointSize(8)
        topology_font.setBold(False)
        self.topology_table.setFont(topology_font)
        self.topology_table.horizontalHeader().setFont(topology_font)
        self.topology_table.setHorizontalHeaderLabels(
            [""] + [f"Cell {cell['number']}" for cell in CELL_CONFIGS]
        )
        for column in range(len(CELL_CONFIGS) + 1):
            header_item = self.topology_table.horizontalHeaderItem(column)
            header_item.setFont(topology_font)
        self.topology_table.verticalHeader().setVisible(False)
        self.topology_table.setEditTriggers(Qt.QAbstractItemView.NoEditTriggers)
        self.topology_table.setSelectionMode(Qt.QAbstractItemView.NoSelection)
        self.topology_table.cellClicked.connect(self.show_topology_item)
        self.topology_table.horizontalHeader().setSectionsClickable(True)
        self.topology_table.horizontalHeader().sectionClicked.connect(
            self.show_topology_cell
        )
        self.topology_table.setWordWrap(True)
        self.topology_table.setTextElideMode(QtCore.Qt.ElideNone)
        self.topology_table.horizontalHeader().setSectionResizeMode(
            Qt.QHeaderView.Stretch
        )
        self.topology_table.horizontalHeader().setSectionResizeMode(
            0, Qt.QHeaderView.Fixed
        )
        self.topology_table.verticalHeader().setSectionResizeMode(Qt.QHeaderView.Fixed)
        self.topology_table.horizontalHeader().setFixedHeight(24)
        self.topology_table.setColumnWidth(0, 72)
        for column in range(1, len(CELL_CONFIGS) + 1):
            self.topology_table.setColumnWidth(column, 200)
        for row, ue in enumerate(UE_CONFIGS):
            self.topology_table.setRowHeight(row, 45)
            ue_item = Qt.QTableWidgetItem(f"UE {ue['number']}")
            ue_item.setTextAlignment(QtCore.Qt.AlignCenter)
            ue_font = ue_item.font()
            ue_font.setPointSize(8)
            ue_item.setFont(ue_font)
            ue_item.setBackground(Qt.QColor(240, 240, 240))
            self.topology_table.setItem(row, 0, ue_item)
        self.topology_table.setFixedHeight(min(224, 26 + len(UE_CONFIGS) * 45))
        topology_layout = Qt.QHBoxLayout()
        topology_layout.setContentsMargins(0, 0, 0, 0)
        topology_layout.addStretch(10)
        topology_layout.addWidget(self.topology_table, 90)
        topology_layout.addStretch(10)
        self.top_layout.addLayout(topology_layout)

        general_layout = Qt.QHBoxLayout()
        general_layout.setContentsMargins(0, 0, 0, 0)
        self.slow_down_ratio_control = SliderSpinBox(1, 20, 0.5, self.slow_down_ratio)
        self.slow_down_ratio_control.valueChanged.connect(self.set_slow_down_ratio)
        general_layout.addWidget(Qt.QLabel("Time slowdown ratio"))
        general_layout.addWidget(self.slow_down_ratio_control, 1)
        actions_button = Qt.QToolButton()
        actions_button.setText("More Actions")
        actions_button.setPopupMode(Qt.QToolButton.InstantPopup)
        actions_menu = Qt.QMenu(actions_button)

        copy_ue_menu = actions_menu.addMenu("Copy Selected UE Settings to")
        self.copy_ue_actions = {}
        for ue in UE_CONFIGS:
            action = copy_ue_menu.addAction(f"UE {ue['number']}")
            self.copy_ue_actions[ue["number"]] = action
            action.triggered.connect(
                lambda checked=False, ue_number=ue["number"]: self.copy_selected_ue(
                    ue_number
                )
            )

        copy_cell_menu = actions_menu.addMenu("Copy Current Cell to")
        self.copy_cell_actions = {}
        for cell in CELL_CONFIGS:
            action = copy_cell_menu.addAction(f"Cell {cell['number']}")
            self.copy_cell_actions[cell["number"]] = action
            action.triggered.connect(
                lambda checked=False, cell_number=cell[
                    "number"
                ]: self.copy_current_cell(cell_number)
            )

        actions_menu.addAction(
            "Set Path Loss for Current Cell", self.set_current_cell_path_loss
        )
        actions_menu.addSeparator()
        self.awgn_action = actions_menu.addAction("")
        self.awgn_action.triggered.connect(self.toggle_current_cell_awgn)
        self.path_loss_link_action = actions_menu.addAction("")
        self.path_loss_link_action.triggered.connect(
            self.toggle_current_cell_path_loss_linked
        )
        actions_menu.aboutToShow.connect(self.update_actions_menu)
        actions_button.setMenu(actions_menu)
        general_layout.addWidget(actions_button)
        self.top_layout.insertLayout(0, general_layout)

        self.cell_tabs = Qt.QTabWidget()
        self.top_layout.addWidget(self.cell_tabs, 1)
        for cell in CELL_CONFIGS:
            self.build_cell_tab(cell["number"])

        action_layout = Qt.QHBoxLayout()
        action_layout.setContentsMargins(0, 0, 0, 0)
        save_button = Qt.QPushButton("Save")
        save_button.clicked.connect(lambda checked=False: self.save_scenario())
        action_layout.addWidget(save_button, 2)

        load_button = Qt.QPushButton("Load")
        load_button.clicked.connect(lambda checked=False: self.load_scenario())
        action_layout.addWidget(load_button, 2)

        reset_all_button = Qt.QPushButton("Reset All")
        reset_all_button.clicked.connect(lambda checked=False: self.reset_all())
        action_layout.addWidget(reset_all_button, 2)

        self.reset_cell_button = Qt.QPushButton()
        self.reset_cell_button.clicked.connect(
            lambda checked=False: self.reset_current_cell()
        )
        action_layout.addWidget(self.reset_cell_button, 3)
        action_font = save_button.font()
        action_font.setPointSize(9)
        for button in (
            save_button,
            load_button,
            reset_all_button,
            self.reset_cell_button,
        ):
            button.setFont(action_font)
            button.setSizePolicy(Qt.QSizePolicy.Ignored, Qt.QSizePolicy.Fixed)
        self.top_layout.addLayout(action_layout)

        self.cell_tabs.currentChanged.connect(self.update_reset_cell_button)
        self.update_reset_cell_button(self.cell_tabs.currentIndex())
        self.update_topology()

    def build_cell_tab(self, cell_number):
        tab = Qt.QWidget()
        tab_layout = Qt.QVBoxLayout(tab)
        scroll_area = Qt.QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        self.cell_scroll_areas[cell_number] = scroll_area
        scroll_content = Qt.QWidget()
        controls_layout = Qt.QVBoxLayout(scroll_content)

        receiver_group = Qt.QGroupBox("Uplink")
        receiver_layout = Qt.QGridLayout(receiver_group)
        receiver_layout.setColumnStretch(1, 1)
        ul_awgn_enabled = Qt.QCheckBox(
            "Enable uplink Additive White Gaussian Noise (AWGN)"
        )
        ul_awgn_font = ul_awgn_enabled.font()
        ul_awgn_font.setPointSize(9)
        ul_awgn_enabled.setFont(ul_awgn_font)
        ul_awgn_enabled.setChecked(self.ul_awgn_enabled[cell_number])
        ul_awgn_enabled.toggled.connect(
            lambda enabled, cell_number=cell_number: self.set_cell_ul_awgn_enabled(
                cell_number, enabled
            )
        )
        self.ul_awgn_enabled_checkboxes[cell_number] = ul_awgn_enabled
        receiver_layout.addWidget(ul_awgn_enabled, 0, 0, 1, 2)

        ul_awgn_snr_control = SliderSpinBox(
            AWGN_SNR_MIN_DB,
            AWGN_SNR_MAX_DB,
            0.1,
            self.ul_awgn_snr_db_by_cell[cell_number],
        )
        ul_awgn_snr_control.setEnabled(self.ul_awgn_enabled[cell_number])
        ul_awgn_snr_control.valueChanged.connect(
            lambda value, cell_number=cell_number: self.set_cell_ul_awgn_snr_db(
                cell_number, value
            )
        )
        self.ul_awgn_snr_controls[cell_number] = ul_awgn_snr_control
        receiver_layout.addWidget(Qt.QLabel("Uplink AWGN SNR [dB]"), 1, 0)
        receiver_layout.addWidget(ul_awgn_snr_control, 1, 1)
        controls_layout.addWidget(receiver_group)

        for ue in UE_CONFIGS:
            ue_number = ue["number"]
            path_key = (cell_number, ue_number)
            link_group = Qt.QGroupBox(f"UE {ue_number}")
            self.link_groups[path_key] = link_group
            link_layout = Qt.QGridLayout(link_group)
            link_layout.setColumnStretch(1, 1)

            path_enabled = Qt.QCheckBox("Enable path")
            path_enabled.setChecked(self.path_enabled[path_key])
            path_enabled.toggled.connect(
                lambda enabled, cell_number=cell_number, ue_number=ue_number: self.set_path_enabled(
                    cell_number, ue_number, enabled
                )
            )
            self.path_enabled_checkboxes[path_key] = path_enabled
            link_layout.addWidget(path_enabled, 0, 0, 1, 2)

            path_loss_linked = Qt.QCheckBox("Link uplink and downlink path loss")
            path_loss_linked.setChecked(self.path_loss_linked[path_key])
            path_loss_linked.toggled.connect(
                lambda linked, cell_number=cell_number, ue_number=ue_number: self.set_path_loss_linked(
                    cell_number, ue_number, linked
                )
            )
            self.path_loss_linked_checkboxes[path_key] = path_loss_linked
            link_layout.addWidget(path_loss_linked, 1, 0, 1, 2)

            dl_path_loss_control = SliderSpinBox(
                0, PATH_LOSS_MAX_DB, 0.1, self.dl_path_loss_db[path_key]
            )
            dl_path_loss_control.valueChanged.connect(
                lambda value, cell_number=cell_number, ue_number=ue_number: self.set_dl_path_loss(
                    cell_number, ue_number, value
                )
            )
            self.dl_path_loss_controls[path_key] = dl_path_loss_control
            link_layout.addWidget(Qt.QLabel("Downlink path loss [dB]"), 2, 0)
            link_layout.addWidget(dl_path_loss_control, 2, 1)

            ul_path_loss_control = SliderSpinBox(
                0, PATH_LOSS_MAX_DB, 0.1, self.ul_path_loss_db[path_key]
            )
            ul_path_loss_control.valueChanged.connect(
                lambda value, cell_number=cell_number, ue_number=ue_number: self.set_ul_path_loss(
                    cell_number, ue_number, value
                )
            )
            self.ul_path_loss_controls[path_key] = ul_path_loss_control
            link_layout.addWidget(Qt.QLabel("Uplink path loss [dB]"), 3, 0)
            link_layout.addWidget(ul_path_loss_control, 3, 1)

            dl_awgn_enabled = Qt.QCheckBox("Enable downlink AWGN")
            dl_awgn_enabled.setChecked(self.dl_awgn_enabled[path_key])
            dl_awgn_enabled.toggled.connect(
                lambda enabled, cell_number=cell_number, ue_number=ue_number: self.set_link_dl_awgn_enabled(
                    cell_number, ue_number, enabled
                )
            )
            self.dl_awgn_enabled_checkboxes[path_key] = dl_awgn_enabled
            link_layout.addWidget(dl_awgn_enabled, 4, 0, 1, 2)

            dl_awgn_snr_control = SliderSpinBox(
                AWGN_SNR_MIN_DB,
                AWGN_SNR_MAX_DB,
                0.1,
                self.dl_awgn_snr_db_by_path[path_key],
            )
            dl_awgn_snr_control.setEnabled(self.dl_awgn_enabled[path_key])
            dl_awgn_snr_control.valueChanged.connect(
                lambda value, cell_number=cell_number, ue_number=ue_number: self.set_link_dl_awgn_snr_db(
                    cell_number, ue_number, value
                )
            )
            self.dl_awgn_snr_controls[path_key] = dl_awgn_snr_control
            link_layout.addWidget(Qt.QLabel("Downlink AWGN SNR [dB]"), 5, 0)
            link_layout.addWidget(dl_awgn_snr_control, 5, 1)
            controls_layout.addWidget(link_group)

        controls_layout.addStretch(1)
        scroll_area.setWidget(scroll_content)
        tab_layout.addWidget(scroll_area, 1)
        self.cell_tabs.addTab(tab, f"Cell {cell_number}")

    def set_selected_topology_path(self, path_key):
        previous_path = self.selected_topology_path
        if self.highlighted_link_group is not None:
            self.highlighted_link_group.setStyleSheet("")
            self.highlighted_link_group = None

        self.selected_topology_path = path_key
        if previous_path is not None:
            self.update_topology_entry(previous_path)
        if path_key is not None:
            self.highlighted_link_group = self.link_groups[path_key]
            self.highlighted_link_group.setStyleSheet(
                "QGroupBox { background-color: #dceeff; border: 1px solid #79a8d8; "
                "margin-top: 8px; } QGroupBox::title { subcontrol-origin: margin; "
                "left: 8px; padding: 0 3px; }"
            )
            self.update_topology_entry(path_key)

    def show_topology_item(self, row, column):
        if not 0 <= row < len(UE_CONFIGS):
            return
        if column == 0:
            self.set_selected_topology_path(None)
        elif 0 < column <= len(CELL_CONFIGS):
            cell_number = CELL_CONFIGS[column - 1]["number"]
            ue_number = UE_CONFIGS[row]["number"]
            path_key = (cell_number, ue_number)
            self.cell_tabs.setCurrentIndex(column - 1)
            if self.selected_topology_path == path_key:
                self.set_selected_topology_path(None)
                return
            self.set_selected_topology_path(path_key)
            scroll_area = self.cell_scroll_areas[cell_number]
            scroll_area.ensureWidgetVisible(self.link_groups[path_key], 0, 8)

    def show_topology_cell(self, column):
        self.set_selected_topology_path(None)
        if 0 < column <= len(CELL_CONFIGS):
            self.cell_tabs.setCurrentIndex(column - 1)

    def copy_link_settings(self, source_path, target_path):
        if source_path == target_path:
            return
        target_linked = self.path_loss_linked[source_path]
        self.path_enabled_checkboxes[target_path].setChecked(
            self.path_enabled[source_path]
        )
        self.path_loss_linked_checkboxes[target_path].setChecked(False)
        self.dl_path_loss_controls[target_path].set_value(
            self.dl_path_loss_db[source_path]
        )
        self.ul_path_loss_controls[target_path].set_value(
            self.ul_path_loss_db[source_path]
        )
        self.path_loss_linked_checkboxes[target_path].setChecked(target_linked)
        self.dl_awgn_enabled_checkboxes[target_path].setChecked(
            self.dl_awgn_enabled[source_path]
        )
        self.dl_awgn_snr_controls[target_path].set_value(
            self.dl_awgn_snr_db_by_path[source_path]
        )

    def copy_selected_ue(self, target_ue_number):
        if self.selected_topology_path is None:
            return
        source_path = self.selected_topology_path
        self.copy_link_settings(source_path, (source_path[0], target_ue_number))

    def copy_current_cell(self, target_cell_number):
        source_cell_number = CELL_CONFIGS[self.cell_tabs.currentIndex()]["number"]
        if source_cell_number == target_cell_number:
            return
        self.ul_awgn_enabled_checkboxes[target_cell_number].setChecked(
            self.ul_awgn_enabled[source_cell_number]
        )
        self.ul_awgn_snr_controls[target_cell_number].set_value(
            self.ul_awgn_snr_db_by_cell[source_cell_number]
        )
        for ue in UE_CONFIGS:
            ue_number = ue["number"]
            self.copy_link_settings(
                (source_cell_number, ue_number),
                (target_cell_number, ue_number),
            )

    def set_current_cell_path_loss(self):
        cell_number = CELL_CONFIGS[self.cell_tabs.currentIndex()]["number"]
        path_loss_db, accepted = Qt.QInputDialog.getDouble(
            self,
            "Set Path Loss",
            "Uplink and downlink path loss [dB]",
            0.0,
            0.0,
            PATH_LOSS_MAX_DB,
            1,
        )
        if not accepted:
            return
        for ue in UE_CONFIGS:
            path_key = (cell_number, ue["number"])
            linked = self.path_loss_linked[path_key]
            self.path_loss_linked_checkboxes[path_key].setChecked(False)
            self.dl_path_loss_controls[path_key].set_value(path_loss_db)
            self.ul_path_loss_controls[path_key].set_value(path_loss_db)
            self.path_loss_linked_checkboxes[path_key].setChecked(linked)

    def set_current_cell_awgn(self, enabled):
        cell_number = CELL_CONFIGS[self.cell_tabs.currentIndex()]["number"]
        self.ul_awgn_enabled_checkboxes[cell_number].setChecked(enabled)

    def set_current_cell_path_loss_linked(self, linked):
        cell_number = CELL_CONFIGS[self.cell_tabs.currentIndex()]["number"]
        for ue in UE_CONFIGS:
            self.path_loss_linked_checkboxes[(cell_number, ue["number"])].setChecked(
                linked
            )

    def update_actions_menu(self):
        current_cell = CELL_CONFIGS[self.cell_tabs.currentIndex()]["number"]
        selected_ue = (
            self.selected_topology_path[1]
            if self.selected_topology_path is not None
            else None
        )
        for ue_number, action in self.copy_ue_actions.items():
            action.setEnabled(selected_ue is not None and ue_number != selected_ue)
        for cell_number, action in self.copy_cell_actions.items():
            action.setEnabled(cell_number != current_cell)

        awgn_action = "Disable" if self.ul_awgn_enabled[current_cell] else "Enable"
        self.awgn_action.setText(f"{awgn_action} Uplink AWGN for Current Cell")
        all_path_loss_linked = all(
            self.path_loss_linked[(current_cell, ue["number"])] for ue in UE_CONFIGS
        )
        path_loss_action = "Unlink" if all_path_loss_linked else "Link"
        self.path_loss_link_action.setText(
            f"{path_loss_action} Path Loss for Current Cell"
        )

    def toggle_current_cell_awgn(self):
        cell_number = CELL_CONFIGS[self.cell_tabs.currentIndex()]["number"]
        self.set_current_cell_awgn(not self.ul_awgn_enabled[cell_number])

    def toggle_current_cell_path_loss_linked(self):
        cell_number = CELL_CONFIGS[self.cell_tabs.currentIndex()]["number"]
        all_linked = all(
            self.path_loss_linked[(cell_number, ue["number"])] for ue in UE_CONFIGS
        )
        self.set_current_cell_path_loss_linked(not all_linked)

    def update_topology(self):
        for row, ue in enumerate(UE_CONFIGS):
            for column, cell in enumerate(CELL_CONFIGS, start=1):
                path_key = (cell["number"], ue["number"])
                self.update_topology_entry(path_key, row, column)

    def update_topology_entry(self, path_key, row=None, column=None):
        if row is None:
            ue_numbers = [ue["number"] for ue in UE_CONFIGS]
            row = ue_numbers.index(path_key[1])
        if column is None:
            cell_numbers = [cell["number"] for cell in CELL_CONFIGS]
            column = cell_numbers.index(path_key[0]) + 1

        item = self.topology_items.get(path_key)
        if item is None:
            item = Qt.QTableWidgetItem()
            item.setTextAlignment(QtCore.Qt.AlignCenter)
            self.topology_items[path_key] = item
            self.topology_table.setItem(row, column, item)

        dl_loss = self.dl_path_loss_db[path_key]
        ul_loss = self.ul_path_loss_db[path_key]
        enabled = self.path_enabled[path_key]
        ul_awgn_enabled = self.ul_awgn_enabled[path_key[0]]
        dl_awgn_enabled = self.dl_awgn_enabled[path_key]
        details = [f"{ul_loss:.1f}/{dl_loss:.1f} dB"]
        if not enabled:
            details.append("Off")
        ul_awgn_state = "On" if ul_awgn_enabled else "Off"
        dl_awgn_state = "On" if dl_awgn_enabled else "Off"
        details.append(f"AWGN: {ul_awgn_state}/{dl_awgn_state}")
        item.setText("\n".join(details))
        item.setToolTip(
            f"Downlink path loss: {dl_loss:.1f} dB\n"
            f"Uplink path loss: {ul_loss:.1f} dB\n"
            f"Path: {'on' if enabled else 'off'}\n"
            f"Uplink AWGN: {'on' if ul_awgn_enabled else 'off'}\n"
            f"Downlink AWGN: {'on' if dl_awgn_enabled else 'off'}"
        )

        font = item.font()
        font.setPointSize(8)
        font.setBold(False)  # (self.selected_topology_path == path_key)
        item.setFont(font)
        if not enabled:
            item.setBackground(Qt.QColor(232, 232, 232))
            return
        path_loss = min(max(max(dl_loss, ul_loss), 0.0), PATH_LOSS_MAX_DB)
        if path_loss <= PATH_LOSS_WARNING_DB:
            color_ratio = path_loss / PATH_LOSS_WARNING_DB
            start_color = (255, 255, 255)
            end_color = (237, 228, 213)
        else:
            color_ratio = (path_loss - PATH_LOSS_WARNING_DB) / (
                PATH_LOSS_RED_DB - PATH_LOSS_WARNING_DB
            )
            color_ratio = min(color_ratio, 1.0)
            start_color = (255, 226, 181)
            end_color = (214, 161, 161)
        color = [
            round(start + (end - start) * color_ratio)
            for start, end in zip(start_color, end_color)
        ]
        item.setBackground(Qt.QColor(*color))

    def update_reset_cell_button(self, tab_index):
        if 0 <= tab_index < len(CELL_CONFIGS):
            cell_number = CELL_CONFIGS[tab_index]["number"]
            self.reset_cell_button.setText(f"Reset Cell {cell_number} to Default")

    def reset_current_cell(self):
        tab_index = self.cell_tabs.currentIndex()
        if 0 <= tab_index < len(CELL_CONFIGS):
            self.reset_cell(CELL_CONFIGS[tab_index]["number"])

    def reset_all(self):
        self.slow_down_ratio_control.set_value(SLOW_DOWN_RATIO)
        for cell in CELL_CONFIGS:
            self.reset_cell(cell["number"])
        for ue in UE_CONFIGS:
            ue_number = ue["number"]
            path_key = (CELL_CONFIGS[0]["number"], ue_number)
            defaults = self.default_link_settings[path_key]
            self.set_link_dl_awgn_enabled(
                path_key[0], ue_number, defaults["dl_awgn_enabled"]
            )
            self.set_link_dl_awgn_snr_db(
                path_key[0], ue_number, defaults["dl_awgn_snr_db"]
            )

    def scenario_state(self):
        cells = {}
        for cell in CELL_CONFIGS:
            cell_number = cell["number"]
            links = {}
            for ue in UE_CONFIGS:
                ue_number = ue["number"]
                path_key = (cell_number, ue_number)
                links[str(ue_number)] = {
                    "enabled": self.path_enabled[path_key],
                    "path_loss_linked": self.path_loss_linked[path_key],
                    "downlink_path_loss_db": self.dl_path_loss_db[path_key],
                    "uplink_path_loss_db": self.ul_path_loss_db[path_key],
                    "downlink_awgn_enabled": self.dl_awgn_enabled[path_key],
                    "downlink_awgn_snr_db": self.dl_awgn_snr_db_by_path[path_key],
                }
            cells[str(cell_number)] = {
                "uplink_awgn_enabled": self.ul_awgn_enabled[cell_number],
                "uplink_awgn_snr_db": self.ul_awgn_snr_db_by_cell[cell_number],
                "ues": links,
            }
        return {
            "version": 1,
            "cell_numbers": [cell["number"] for cell in CELL_CONFIGS],
            "ue_numbers": [ue["number"] for ue in UE_CONFIGS],
            "slow_down_ratio": self.slow_down_ratio,
            "cells": cells,
        }

    def save_scenario(self, file_path=None):
        interactive = file_path is None
        if interactive:
            file_path, _ = Qt.QFileDialog.getSaveFileName(
                self,
                "Save ZeroMQ Channel Emulator Scenario",
                "zmq_channel_emulator_scenario.json",
                "JSON Files (*.json)",
            )
        if not file_path:
            return False
        if not str(file_path).lower().endswith(".json"):
            file_path = f"{file_path}.json"
        try:
            with open(file_path, "w", encoding="utf-8") as scenario_file:
                json.dump(self.scenario_state(), scenario_file, indent=2)
        except OSError as error:
            if interactive:
                Qt.QMessageBox.critical(self, "Save Scenario", str(error))
            return False
        return True

    @staticmethod
    def validate_scenario_number(value, minimum, maximum, label):
        value = float(value)
        if not np.isfinite(value) or not minimum <= value <= maximum:
            raise ValueError(f"{label} must be between {minimum} and {maximum}")
        return value

    def load_scenario(self, file_path=None):
        interactive = file_path is None
        if interactive:
            file_path, _ = Qt.QFileDialog.getOpenFileName(
                self,
                "Load ZeroMQ Channel Emulator Preset",
                "",
                "JSON Files (*.json)",
            )
        if not file_path:
            return False

        try:
            with open(file_path, "r", encoding="utf-8") as scenario_file:
                state = json.load(scenario_file)
            if not isinstance(state, dict):
                raise ValueError("Scenario file must contain a JSON object")
            if state.get("version") != 1:
                raise ValueError("This scenario file version is not supported")

            cell_numbers = [cell["number"] for cell in CELL_CONFIGS]
            ue_numbers = [ue["number"] for ue in UE_CONFIGS]
            if state.get("cell_numbers") != cell_numbers:
                raise ValueError("Scenario does not use the current cells")
            if state.get("ue_numbers") != ue_numbers:
                raise ValueError("Scenario does not use the current UEs")

            slow_down_ratio = self.validate_scenario_number(
                state["slow_down_ratio"], 1, 20, "Time slowdown ratio"
            )
            validated_cells = {}
            validated_dl_awgn_by_ue = {}
            for cell_number in cell_numbers:
                cell_state = state["cells"][str(cell_number)]
                if not isinstance(cell_state["uplink_awgn_enabled"], bool):
                    raise ValueError("Uplink AWGN enabled must be true or false")
                validated_links = {}
                for ue_number in ue_numbers:
                    link_state = cell_state["ues"][str(ue_number)]
                    boolean_fields = {
                        "enabled": "Path enabled",
                        "path_loss_linked": "Path loss linked",
                        "downlink_awgn_enabled": "Downlink AWGN enabled",
                    }
                    for field, label in boolean_fields.items():
                        if not isinstance(link_state[field], bool):
                            raise ValueError(f"{label} must be true or false")
                    dl_loss = self.validate_scenario_number(
                        link_state["downlink_path_loss_db"],
                        0,
                        PATH_LOSS_MAX_DB,
                        "Downlink path loss",
                    )
                    ul_loss = self.validate_scenario_number(
                        link_state["uplink_path_loss_db"],
                        0,
                        PATH_LOSS_MAX_DB,
                        "Uplink path loss",
                    )
                    if link_state["path_loss_linked"] and dl_loss != ul_loss:
                        raise ValueError("Linked path-loss values must match")
                    dl_awgn_state = {
                        "enabled": link_state["downlink_awgn_enabled"],
                        "snr_db": self.validate_scenario_number(
                            link_state["downlink_awgn_snr_db"],
                            AWGN_SNR_MIN_DB,
                            AWGN_SNR_MAX_DB,
                            "Downlink AWGN SNR",
                        ),
                    }
                    if (
                        ue_number in validated_dl_awgn_by_ue
                        and validated_dl_awgn_by_ue[ue_number] != dl_awgn_state
                    ):
                        raise ValueError(
                            "Downlink AWGN settings must match across cells for each UE"
                        )
                    validated_dl_awgn_by_ue[ue_number] = dl_awgn_state
                    validated_links[ue_number] = {
                        **link_state,
                        "downlink_path_loss_db": dl_loss,
                        "uplink_path_loss_db": ul_loss,
                        "downlink_awgn_snr_db": dl_awgn_state["snr_db"],
                    }
                validated_cells[cell_number] = {
                    "uplink_awgn_enabled": cell_state["uplink_awgn_enabled"],
                    "uplink_awgn_snr_db": self.validate_scenario_number(
                        cell_state["uplink_awgn_snr_db"],
                        AWGN_SNR_MIN_DB,
                        AWGN_SNR_MAX_DB,
                        "Uplink AWGN SNR",
                    ),
                    "ues": validated_links,
                }
        except (
            OSError,
            ValueError,
            KeyError,
            TypeError,
            AttributeError,
            json.JSONDecodeError,
        ) as error:
            if interactive:
                Qt.QMessageBox.critical(self, "Load Preset", str(error))
            return False

        self.slow_down_ratio_control.set_value(slow_down_ratio)
        for cell_number, cell_state in validated_cells.items():
            self.ul_awgn_enabled_checkboxes[cell_number].setChecked(
                cell_state["uplink_awgn_enabled"]
            )
            self.ul_awgn_snr_controls[cell_number].set_value(
                cell_state["uplink_awgn_snr_db"]
            )
            for ue_number, link_state in cell_state["ues"].items():
                path_key = (cell_number, ue_number)
                self.path_enabled_checkboxes[path_key].setChecked(link_state["enabled"])
                self.path_loss_linked_checkboxes[path_key].setChecked(False)
                self.dl_path_loss_controls[path_key].set_value(
                    link_state["downlink_path_loss_db"]
                )
                self.ul_path_loss_controls[path_key].set_value(
                    link_state["uplink_path_loss_db"]
                )
                self.path_loss_linked_checkboxes[path_key].setChecked(
                    link_state["path_loss_linked"]
                )
        first_cell_number = cell_numbers[0]
        for ue_number, dl_awgn_state in validated_dl_awgn_by_ue.items():
            path_key = (first_cell_number, ue_number)
            self.dl_awgn_enabled_checkboxes[path_key].setChecked(
                dl_awgn_state["enabled"]
            )
            self.dl_awgn_snr_controls[path_key].set_value(dl_awgn_state["snr_db"])
        self.update_topology()
        return True

    @staticmethod
    def path_loss_db_to_iq_gain(path_loss_db):
        return 10 ** (-path_loss_db / 20.0)

    def set_path_loss(self, cell_number, ue_number, path_loss_db):
        path_key = (cell_number, ue_number)
        if path_key in self.dl_path_loss_controls:
            self.dl_path_loss_controls[path_key].set_value(path_loss_db)
            self.ul_path_loss_controls[path_key].set_value(path_loss_db)
        else:
            self.set_dl_path_loss(cell_number, ue_number, path_loss_db)
            self.set_ul_path_loss(cell_number, ue_number, path_loss_db)

    def set_path_enabled(self, cell_number, ue_number, enabled):
        path_key = (cell_number, ue_number)
        self.path_enabled[path_key] = bool(enabled)
        self.update_path_gains(path_key)
        if hasattr(self, "topology_table"):
            self.update_topology_entry(path_key)

    def set_path_loss_linked(self, cell_number, ue_number, linked):
        path_key = (cell_number, ue_number)
        self.path_loss_linked[path_key] = bool(linked)
        if linked:
            self.ul_path_loss_controls[path_key].set_value(
                self.dl_path_loss_db[path_key]
            )

    def set_dl_path_loss(self, cell_number, ue_number, path_loss_db):
        path_key = (cell_number, ue_number)
        self.dl_path_loss_db[path_key] = self.validate_scenario_number(
            path_loss_db, 0, PATH_LOSS_MAX_DB, "Downlink path loss"
        )
        self.update_path_gains(path_key)
        if self.path_loss_linked[path_key]:
            self.ul_path_loss_controls[path_key].set_value(path_loss_db)
        if hasattr(self, "topology_table"):
            self.update_topology_entry(path_key)

    def set_ul_path_loss(self, cell_number, ue_number, path_loss_db):
        path_key = (cell_number, ue_number)
        self.ul_path_loss_db[path_key] = self.validate_scenario_number(
            path_loss_db, 0, PATH_LOSS_MAX_DB, "Uplink path loss"
        )
        self.update_path_gains(path_key)
        if self.path_loss_linked[path_key]:
            self.dl_path_loss_controls[path_key].set_value(path_loss_db)
        if hasattr(self, "topology_table"):
            self.update_topology_entry(path_key)

    def update_path_gains(self, path_key):
        if self.path_enabled[path_key]:
            dl_gain = self.path_loss_db_to_iq_gain(self.dl_path_loss_db[path_key])
            ul_gain = self.path_loss_db_to_iq_gain(self.ul_path_loss_db[path_key])
        else:
            dl_gain = 0.0
            ul_gain = 0.0
        self.dl_gains[path_key].set_k(dl_gain)
        self.ul_gains[path_key].set_k(ul_gain)

    def set_link_dl_awgn_enabled(self, cell_number, ue_number, enabled):
        enabled = bool(enabled)
        self.dl_awgn[ue_number].set_enabled(enabled)
        for cell in CELL_CONFIGS:
            path_key = (cell["number"], ue_number)
            self.dl_awgn_enabled[path_key] = enabled
            checkbox = self.dl_awgn_enabled_checkboxes.get(path_key)
            if checkbox is not None and checkbox.isChecked() != enabled:
                checkbox.blockSignals(True)
                checkbox.setChecked(enabled)
                checkbox.blockSignals(False)
            control = self.dl_awgn_snr_controls.get(path_key)
            if control is not None:
                control.setEnabled(enabled)
            if hasattr(self, "topology_table"):
                self.update_topology_entry(path_key)

    def set_link_dl_awgn_snr_db(self, cell_number, ue_number, snr_db):
        self.dl_awgn[ue_number].set_snr_db(snr_db)
        value = self.dl_awgn[ue_number].snr_db
        for cell in CELL_CONFIGS:
            path_key = (cell["number"], ue_number)
            self.dl_awgn_snr_db_by_path[path_key] = value
            control = self.dl_awgn_snr_controls.get(path_key)
            if control is not None:
                control.set_value(value, emit=False)

    def set_cell_ul_awgn_enabled(self, cell_number, enabled):
        self.ul_awgn_enabled[cell_number] = bool(enabled)
        self.cell_ul_awgn[cell_number].set_enabled(enabled)
        self.ul_awgn_snr_controls[cell_number].setEnabled(bool(enabled))
        if hasattr(self, "topology_table"):
            for ue in UE_CONFIGS:
                self.update_topology_entry((cell_number, ue["number"]))

    def set_cell_ul_awgn_snr_db(self, cell_number, snr_db):
        self.cell_ul_awgn[cell_number].set_snr_db(snr_db)
        self.ul_awgn_snr_db_by_cell[cell_number] = self.cell_ul_awgn[cell_number].snr_db

    def reset_cell(self, cell_number):
        cell_defaults = self.default_cell_settings[cell_number]
        self.ul_awgn_enabled_checkboxes[cell_number].setChecked(
            cell_defaults["ul_awgn_enabled"]
        )
        self.ul_awgn_snr_controls[cell_number].set_value(
            cell_defaults["ul_awgn_snr_db"]
        )

        for ue in UE_CONFIGS:
            path_key = (cell_number, ue["number"])
            defaults = self.default_link_settings[path_key]
            self.path_enabled_checkboxes[path_key].setChecked(defaults["path_enabled"])
            self.path_loss_linked_checkboxes[path_key].setChecked(
                defaults["path_loss_linked"]
            )
            self.dl_path_loss_controls[path_key].set_value(defaults["dl_path_loss_db"])
            self.ul_path_loss_controls[path_key].set_value(defaults["ul_path_loss_db"])

    def set_slow_down_ratio(self, slow_down_ratio):
        self.slow_down_ratio = self.validate_scenario_number(
            slow_down_ratio, 1, 20, "Time slowdown ratio"
        )
        for cell_number in self.dl_throttles:
            self.dl_throttles[cell_number].set_sample_rate(
                self.samp_rate / self.slow_down_ratio
            )

    def set_dl_awgn_snr_db(self, snr_db):
        self.dl_awgn_snr_db = float(snr_db)
        for ue_number in self.dl_awgn:
            self.set_link_dl_awgn_snr_db(CELL_CONFIGS[0]["number"], ue_number, snr_db)

    def set_ul_awgn_snr_db(self, snr_db):
        self.ul_awgn_snr_db = float(snr_db)
        for cell_number in self.cell_ul_awgn:
            self.ul_awgn_snr_controls[cell_number].set_value(snr_db)

    def closeEvent(self, event):
        self.settings.setValue("geometry", self.saveGeometry())
        self.stop()
        self.wait()
        event.accept()


def main():
    qapp = Qt.QApplication(sys.argv)
    tb = zmq_channel_emulator()
    tb.start()
    tb.show()

    def sig_handler(sig=None, frame=None):
        tb.stop()
        tb.wait()
        Qt.QApplication.quit()

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    timer = Qt.QTimer()
    timer.start(500)
    timer.timeout.connect(lambda: None)
    qapp.exec_()


if __name__ == "__main__":
    main()

EOF

sed -i "s/__SAMPLE_RATE_HZ__/$SAMPLE_RATE_HZ/" "$OUTPUT"
sed -i "s/__SLOW_DOWN_RATIO__/$SLOW_DOWN_RATIO/" "$OUTPUT"
chmod 755 "$OUTPUT"

echo "Generated ZeroMQ Channel Emulator: $OUTPUT"

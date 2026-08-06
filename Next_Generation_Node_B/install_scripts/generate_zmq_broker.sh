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

OUTPUT=""
SAMPLE_RATE_HZ=""
SLOW_DOWN_RATIO=""
CELL_NUMBERS=()
UE_NUMBERS=()
UE_IPS=()
VALIDATED_CELL_NUMBERS=()

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

usage() {
    echo "Usage: $0 --output FILE --sample-rate-hz HZ [--slow-down-ratio N] --cells <cell_numbers> --ues <number:ip_addresses>"
}

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
            echo "ERROR: --ues requires comma-separated NUMBER:IP_ADDRESS values."
            usage
            exit 1
        fi
        IFS=',' read -r -a PARSED_UE_CONFIGS <<<"$2"
        for UE_VALUE in "${PARSED_UE_CONFIGS[@]}"; do
            UE_NUMBER="${UE_VALUE%%:*}"
            UE_IP="${UE_VALUE#*:}"
            if ! [[ "$UE_NUMBER" =~ ^[1-9][0-9]*$ ]] || [ "$UE_IP" = "$UE_VALUE" ]; then
                echo "ERROR: UEs must be formatted as comma-separated NUMBER:IP_ADDRESS values."
                exit 1
            fi
            for EXISTING_UE in "${UE_NUMBERS[@]}"; do
                if [ "$EXISTING_UE" = "$UE_NUMBER" ]; then
                    echo "ERROR: UE $UE_NUMBER was provided more than once."
                    exit 1
                fi
            done
            UE_NUMBERS+=("$UE_NUMBER")
            UE_IPS+=("$UE_IP")
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

if [ -z "$OUTPUT" ] || [ -z "$SAMPLE_RATE_HZ" ] || [ ${#UE_NUMBERS[@]} -eq 0 ] || [ ${#CELL_NUMBERS[@]} -eq 0 ]; then
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
done

mkdir -p "$(dirname "$OUTPUT")"

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

# WARNING: Auto-generated ZeroMQ Channel Emulator, overwritten with the script: ./Next_Generation_Node_B/install_scripts/generate_zmq_broker.sh

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
import signal
import sys
import numpy as np

if sys.platform.startswith("linux"):
    try:
        ctypes.cdll.LoadLibrary("libX11.so").XInitThreads()
        # ctypes.cdll.LoadLibrary("libX11.so.6").XInitThreads()
    except Exception:
        print("Warning: failed to XInitThreads()")

from PyQt5 import Qt
from PyQt5 import QtCore
from gnuradio import blocks
from gnuradio import gr
from gnuradio import qtgui
from gnuradio import zeromq
from gnuradio.qtgui import Range
from gnuradio.qtgui import RangeWidget

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
PRIMARY_CELL_PATH_LOSS_DB = 0
OTHER_CELL_PATH_LOSS_DB = 12
ZMQ_TIMEOUT = 100
ZMQ_HIGH_WATER_MARK = -1
DL_AWGN_SNR_DB = 30.0
UL_AWGN_SNR_DB = 30.0
PATH_ENABLED = True
PATH_LOSS_COUPLED = True
DL_AWGN_ENABLED = True
UL_AWGN_ENABLED = True

class awgn_cc(gr.sync_block):
    def __init__(self, snr_db, enabled=True):
        gr.sync_block.__init__(
            self,
            name="Complex AWGN",
            in_sig=[np.complex64],
            out_sig=[np.complex64],
        )
        self.set_snr_db(snr_db)
        self.set_enabled(enabled)
        self.rng = np.random.default_rng()

    def set_snr_db(self, snr_db):
        self.snr_linear = 10.0 ** (float(snr_db) / 10.0)

    def set_enabled(self, enabled):
        self.enabled = bool(enabled)

    def work(self, input_items, output_items):
        input_samples = input_items[0]
        output_samples = output_items[0]
        sample_count = len(input_samples)

        if sample_count == 0:
            return 0

        if not self.enabled:
            np.copyto(output_samples, input_samples)
            return sample_count

        signal_power = float(np.vdot(input_samples, input_samples).real) / sample_count
        if signal_power == 0.0:
            np.copyto(output_samples, input_samples)
            return sample_count

        noise = self.rng.standard_normal(2 * sample_count, dtype=np.float32)
        noise = noise.view(np.complex64)
        noise *= np.float32(np.sqrt(signal_power / (2.0 * self.snr_linear)))
        np.add(input_samples, noise, out=output_samples)
        return sample_count


def make_range_widget(range_object, callback, label):
    try:
        return RangeWidget(
            range_object,
            callback,
            label,
            "counter_slider",
            float,
            QtCore.Qt.Horizontal,
        )
    except TypeError as error: # GNU Radio 3.8/Ubuntu 20.04 support
        error_message = str(error)
        if "positional argument" not in error_message or "were given" not in error_message:
            raise
        return RangeWidget(
            range_object,
            callback,
            label,
            "counter_slider",
        )

class SliderSpinBox(Qt.QWidget):
    valueChanged = QtCore.pyqtSignal(float)

    def __init__(self, minimum, maximum, step, value):
        Qt.QWidget.__init__(self)
        self.minimum = float(minimum)
        self.step = float(step)

        layout = Qt.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self.slider = Qt.QSlider(QtCore.Qt.Horizontal)
        self.slider.setRange(0, int(round((maximum - minimum) / step)))
        self.spin_box = Qt.QDoubleSpinBox()
        self.spin_box.setRange(minimum, maximum)
        self.spin_box.setSingleStep(step)
        self.spin_box.setDecimals(1)
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
        changed = abs(self.spin_box.value() - value) > 1e-9
        self.slider.blockSignals(True)
        self.spin_box.blockSignals(True)
        self.slider.setValue(int(round((value - self.minimum) / self.step)))
        self.spin_box.setValue(value)
        self.slider.blockSignals(False)
        self.spin_box.blockSignals(False)
        if emit and changed:
            self.valueChanged.emit(value)

class multi_ue_scenario(gr.top_block, Qt.QWidget):
    def __init__(self):
        try:
            gr.top_block.__init__(
                self, "ZeroMQ Channel Emulator", catch_exceptions=True
            )
        except TypeError:
            gr.top_block.__init__(self, "ZeroMQ Channel Emulator")
        Qt.QWidget.__init__(self)
        self.setWindowTitle("ZeroMQ Channel Emulator")
        self.resize(500, 560)
        qtgui.util.check_set_qss()

        self.top_layout = Qt.QVBoxLayout()
        self.setLayout(self.top_layout)
        self.settings = Qt.QSettings("GNU Radio", "multi_ue_scenario")
        try:
            self.restoreGeometry(self.settings.value("geometry"))
        except Exception:
            pass

        self.samp_rate = SAMPLE_RATE_HZ
        self.slow_down_ratio = SLOW_DOWN_RATIO
        self.dl_awgn_snr_db = DL_AWGN_SNR_DB
        self.ul_awgn_snr_db = UL_AWGN_SNR_DB

        # # Equally loud cells
        # self.path_loss_db = {(cell["number"], ue["number"]): 0 for cell in CELL_CONFIGS for ue in UE_CONFIGS}

        # Map each UE to one primary cell in configured order, wrapping when there are more UEs than cells
        self.path_loss_db = {}
        self.dl_path_loss_db = self.path_loss_db
        self.ul_path_loss_db = {}
        self.path_enabled = {}
        self.path_loss_coupled = {}
        self.dl_awgn_enabled = {}
        self.dl_awgn_snr_db_by_path = {}
        self.ul_awgn_enabled = {}
        self.ul_awgn_snr_db_by_cell = {}
        self.default_link_settings = {}
        self.default_cell_settings = {}
        cell_count = len(CELL_CONFIGS)
        for cell_index, cell in enumerate(CELL_CONFIGS):
            cell_number = cell["number"]
            self.ul_awgn_enabled[cell_number] = UL_AWGN_ENABLED
            self.ul_awgn_snr_db_by_cell[cell_number] = UL_AWGN_SNR_DB
            self.default_cell_settings[cell_number] = {
                "ul_awgn_enabled": UL_AWGN_ENABLED,
                "ul_awgn_snr_db": UL_AWGN_SNR_DB,
            }
            for ue_index, ue in enumerate(UE_CONFIGS):
                ue_number = ue["number"]
                is_mapped_pair = cell_index == ue_index % cell_count

                if is_mapped_pair:
                    path_loss_db = PRIMARY_CELL_PATH_LOSS_DB
                else:
                    path_loss_db = OTHER_CELL_PATH_LOSS_DB

                path_key = (cell_number, ue_number)
                self.dl_path_loss_db[path_key] = path_loss_db
                self.ul_path_loss_db[path_key] = path_loss_db
                self.path_enabled[path_key] = PATH_ENABLED
                self.path_loss_coupled[path_key] = PATH_LOSS_COUPLED
                self.dl_awgn_enabled[path_key] = DL_AWGN_ENABLED
                self.dl_awgn_snr_db_by_path[path_key] = DL_AWGN_SNR_DB
                self.default_link_settings[path_key] = {
                    "path_enabled": PATH_ENABLED,
                    "path_loss_coupled": PATH_LOSS_COUPLED,
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
        self.path_loss_coupled_checkboxes = {}
        self.dl_path_loss_controls = {}
        self.ul_path_loss_controls = {}
        self.dl_awgn_enabled_checkboxes = {}
        self.dl_awgn_snr_controls = {}
        self.ul_awgn_enabled_checkboxes = {}
        self.ul_awgn_snr_controls = {}

        print(
            f"ZeroMQ Channel Emulator sample_rate={SAMPLE_RATE_HZ} slow_down_ratio={SLOW_DOWN_RATIO} cells={len(CELL_CONFIGS)} ues={len(UE_CONFIGS)}",
            flush=True,
        )

        for cell in CELL_CONFIGS:
            cell_number = cell["number"]
            print(
                f"ZeroMQ Channel Emulator Cell{cell_number} gNB DL source tcp://127.0.0.1:{cell['rx_port']} UL sink tcp://127.0.0.1:{cell['tx_port']}",
                flush=True,
            )
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
            print(
                f"ZeroMQ Channel Emulator UE{ue_number} DL sink tcp://*:{ue['rx_port']} UL source tcp://{ue['ue_ip']}:{ue['tx_port']}",
                flush=True,
            )
            self.ue_dl_adds[ue_number] = blocks.add_vcc(1)
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
                self.dl_awgn[path_key] = awgn_cc(
                    self.dl_awgn_snr_db_by_path[path_key],
                    self.dl_awgn_enabled[path_key],
                )

                self.connect(
                    (self.dl_throttles[cell_number], 0), (self.dl_gains[path_key], 0)
                )
                self.connect(
                    (self.dl_gains[path_key], 0), (self.dl_awgn[path_key], 0)
                )
                self.connect(
                    (self.dl_awgn[path_key], 0),
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
        general_group = Qt.QGroupBox("ZeroMQ Channel Emulator Settings")
        general_layout = Qt.QVBoxLayout(general_group)
        self.slow_down_ratio_range = Range(1, 20, 0.5, self.slow_down_ratio, 200)
        self.slow_down_ratio_widget = make_range_widget(
            self.slow_down_ratio_range,
            self.set_slow_down_ratio,
            "Time Slow Down Ratio",
        )
        general_layout.addWidget(self.slow_down_ratio_widget)
        self.top_layout.addWidget(general_group)

        self.cell_tabs = Qt.QTabWidget()
        self.top_layout.addWidget(self.cell_tabs, 1)
        for cell in CELL_CONFIGS:
            self.build_cell_tab(cell["number"])

    def build_cell_tab(self, cell_number):
        tab = Qt.QWidget()
        tab_layout = Qt.QVBoxLayout(tab)
        scroll_area = Qt.QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_content = Qt.QWidget()
        controls_layout = Qt.QVBoxLayout(scroll_content)

        receiver_group = Qt.QGroupBox("Uplink")
        receiver_layout = Qt.QGridLayout(receiver_group)
        receiver_layout.setColumnStretch(1, 1)
        ul_awgn_enabled = Qt.QCheckBox(
            "Enable uplink Additive White Gaussian Noise (AWGN)"
        )
        ul_awgn_enabled.setChecked(self.ul_awgn_enabled[cell_number])
        ul_awgn_enabled.toggled.connect(
            lambda enabled, cell_number=cell_number: self.set_cell_ul_awgn_enabled(
                cell_number, enabled
            )
        )
        self.ul_awgn_enabled_checkboxes[cell_number] = ul_awgn_enabled
        receiver_layout.addWidget(ul_awgn_enabled, 0, 0, 1, 2)

        ul_awgn_snr_control = SliderSpinBox(
            -20, 100, 0.1, self.ul_awgn_snr_db_by_cell[cell_number]
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
            link_layout.addWidget(path_enabled, 0, 0)

            path_loss_coupled = Qt.QCheckBox("Link uplink and downlink path loss")
            path_loss_coupled.setChecked(self.path_loss_coupled[path_key])
            path_loss_coupled.toggled.connect(
                lambda coupled, cell_number=cell_number, ue_number=ue_number: self.set_path_loss_coupled(
                    cell_number, ue_number, coupled
                )
            )
            self.path_loss_coupled_checkboxes[path_key] = path_loss_coupled
            link_layout.addWidget(path_loss_coupled, 0, 1)

            dl_path_loss_control = SliderSpinBox(
                0, 100, 0.1, self.dl_path_loss_db[path_key]
            )
            dl_path_loss_control.valueChanged.connect(
                lambda value, cell_number=cell_number, ue_number=ue_number: self.set_dl_path_loss(
                    cell_number, ue_number, value
                )
            )
            self.dl_path_loss_controls[path_key] = dl_path_loss_control
            link_layout.addWidget(Qt.QLabel("Downlink path loss [dB]"), 1, 0)
            link_layout.addWidget(dl_path_loss_control, 1, 1)

            ul_path_loss_control = SliderSpinBox(
                0, 100, 0.1, self.ul_path_loss_db[path_key]
            )
            ul_path_loss_control.valueChanged.connect(
                lambda value, cell_number=cell_number, ue_number=ue_number: self.set_ul_path_loss(
                    cell_number, ue_number, value
                )
            )
            self.ul_path_loss_controls[path_key] = ul_path_loss_control
            link_layout.addWidget(Qt.QLabel("Uplink path loss [dB]"), 2, 0)
            link_layout.addWidget(ul_path_loss_control, 2, 1)

            dl_awgn_enabled = Qt.QCheckBox("Enable downlink AWGN")
            dl_awgn_enabled.setChecked(self.dl_awgn_enabled[path_key])
            dl_awgn_enabled.toggled.connect(
                lambda enabled, cell_number=cell_number, ue_number=ue_number: self.set_link_dl_awgn_enabled(
                    cell_number, ue_number, enabled
                )
            )
            self.dl_awgn_enabled_checkboxes[path_key] = dl_awgn_enabled
            link_layout.addWidget(dl_awgn_enabled, 3, 0, 1, 2)

            dl_awgn_snr_control = SliderSpinBox(
                -20, 100, 0.1, self.dl_awgn_snr_db_by_path[path_key]
            )
            dl_awgn_snr_control.setEnabled(self.dl_awgn_enabled[path_key])
            dl_awgn_snr_control.valueChanged.connect(
                lambda value, cell_number=cell_number, ue_number=ue_number: self.set_link_dl_awgn_snr_db(
                    cell_number, ue_number, value
                )
            )
            self.dl_awgn_snr_controls[path_key] = dl_awgn_snr_control
            link_layout.addWidget(Qt.QLabel("Downlink AWGN SNR [dB]"), 4, 0)
            link_layout.addWidget(dl_awgn_snr_control, 4, 1)
            controls_layout.addWidget(link_group)

        controls_layout.addStretch(1)
        scroll_area.setWidget(scroll_content)
        tab_layout.addWidget(scroll_area, 1)

        reset_button = Qt.QPushButton(f"Reset Cell {cell_number} to Default")
        reset_button.clicked.connect(
            lambda checked=False, cell_number=cell_number: self.reset_cell(cell_number)
        )
        reset_layout = Qt.QHBoxLayout()
        reset_layout.addStretch(1)
        reset_layout.addWidget(reset_button)
        tab_layout.addLayout(reset_layout)
        self.cell_tabs.addTab(tab, f"Cell {cell_number}")

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

    def set_path_loss_coupled(self, cell_number, ue_number, coupled):
        path_key = (cell_number, ue_number)
        self.path_loss_coupled[path_key] = bool(coupled)
        if coupled:
            self.ul_path_loss_controls[path_key].set_value(
                self.dl_path_loss_db[path_key]
            )

    def set_dl_path_loss(self, cell_number, ue_number, path_loss_db):
        path_key = (cell_number, ue_number)
        self.dl_path_loss_db[path_key] = float(path_loss_db)
        self.update_path_gains(path_key)
        if self.path_loss_coupled[path_key]:
            self.ul_path_loss_controls[path_key].set_value(path_loss_db)

    def set_ul_path_loss(self, cell_number, ue_number, path_loss_db):
        path_key = (cell_number, ue_number)
        self.ul_path_loss_db[path_key] = float(path_loss_db)
        self.update_path_gains(path_key)
        if self.path_loss_coupled[path_key]:
            self.dl_path_loss_controls[path_key].set_value(path_loss_db)

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
        path_key = (cell_number, ue_number)
        self.dl_awgn_enabled[path_key] = bool(enabled)
        self.dl_awgn[path_key].set_enabled(enabled)
        self.dl_awgn_snr_controls[path_key].setEnabled(bool(enabled))

    def set_link_dl_awgn_snr_db(self, cell_number, ue_number, snr_db):
        path_key = (cell_number, ue_number)
        self.dl_awgn_snr_db_by_path[path_key] = float(snr_db)
        self.dl_awgn[path_key].set_snr_db(snr_db)

    def set_cell_ul_awgn_enabled(self, cell_number, enabled):
        self.ul_awgn_enabled[cell_number] = bool(enabled)
        self.cell_ul_awgn[cell_number].set_enabled(enabled)
        self.ul_awgn_snr_controls[cell_number].setEnabled(bool(enabled))

    def set_cell_ul_awgn_snr_db(self, cell_number, snr_db):
        self.ul_awgn_snr_db_by_cell[cell_number] = float(snr_db)
        self.cell_ul_awgn[cell_number].set_snr_db(snr_db)

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
            self.path_enabled_checkboxes[path_key].setChecked(
                defaults["path_enabled"]
            )
            self.path_loss_coupled_checkboxes[path_key].setChecked(
                defaults["path_loss_coupled"]
            )
            self.dl_path_loss_controls[path_key].set_value(
                defaults["dl_path_loss_db"]
            )
            self.ul_path_loss_controls[path_key].set_value(
                defaults["ul_path_loss_db"]
            )
            self.dl_awgn_enabled_checkboxes[path_key].setChecked(
                defaults["dl_awgn_enabled"]
            )
            self.dl_awgn_snr_controls[path_key].set_value(
                defaults["dl_awgn_snr_db"]
            )

    def set_slow_down_ratio(self, slow_down_ratio):
        self.slow_down_ratio = slow_down_ratio
        for cell_number in self.dl_throttles:
            self.dl_throttles[cell_number].set_sample_rate(
                self.samp_rate / self.slow_down_ratio
            )

    def set_dl_awgn_snr_db(self, snr_db):
        self.dl_awgn_snr_db = float(snr_db)
        for path_key in self.dl_awgn:
            self.dl_awgn_snr_controls[path_key].set_value(snr_db)

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
    tb = multi_ue_scenario()
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

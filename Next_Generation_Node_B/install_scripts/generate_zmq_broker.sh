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

# WARNING: Auto-generated ZeroMQ broker, overwritten with the script: ./Next_Generation_Node_B/install_scripts/generate_zmq_broker.sh

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

class awgn_cc(gr.sync_block):
    def __init__(self, snr_db):
        gr.sync_block.__init__(
            self,
            name="Complex AWGN",
            in_sig=[np.complex64],
            out_sig=[np.complex64],
        )
        self.set_snr_db(snr_db)
        self.rng = np.random.default_rng()

    def set_snr_db(self, snr_db):
        self.snr_linear = 10.0 ** (float(snr_db) / 10.0)

    def work(self, input_items, output_items):
        input_samples = input_items[0]
        output_samples = output_items[0]
        sample_count = len(input_samples)

        if sample_count == 0:
            return 0

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

class multi_ue_scenario(gr.top_block, Qt.QWidget):
    def __init__(self):
        try:
            gr.top_block.__init__(
                self, "Multi_Cell_Multi_UE_Broker", catch_exceptions=True
            )
        except TypeError:
            gr.top_block.__init__(self, "Multi_Cell_Multi_UE_Broker")
        Qt.QWidget.__init__(self)
        self.setWindowTitle("Multi_Cell_Multi_UE_Broker")
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
        cell_count = len(CELL_CONFIGS)
        for cell_index, cell in enumerate(CELL_CONFIGS):
            for ue_index, ue in enumerate(UE_CONFIGS):
                cell_number = cell["number"]
                ue_number = ue["number"]
                is_mapped_pair = cell_index == ue_index % cell_count

                if is_mapped_pair:
                    path_loss_db = PRIMARY_CELL_PATH_LOSS_DB
                else:
                    path_loss_db = OTHER_CELL_PATH_LOSS_DB

                self.path_loss_db[(cell_number, ue_number)] = path_loss_db

        self.gnb_dl_sources = {}
        self.gnb_ul_sinks = {}
        self.dl_throttles = {}
        self.ue_dl_sinks = {}
        self.ue_ul_sources = {}
        self.ue_dl_adds = {}
        self.cell_ul_adds = {}
        self.ue_dl_awgn = {}
        self.cell_ul_awgn = {}
        self.dl_gains = {}
        self.ul_gains = {}
        self.path_loss_ranges = {}
        self.path_loss_widgets = {}
        self.slow_down_ratio_range = Range(1, 20, 0.5, self.slow_down_ratio, 200)
        self.slow_down_ratio_widget = make_range_widget(
            self.slow_down_ratio_range,
            self.set_slow_down_ratio,
            "Time Slow Down Ratio",
        )
        self.top_layout.addWidget(self.slow_down_ratio_widget)

        self.dl_awgn_snr_range = Range(-20, 100, 1, self.dl_awgn_snr_db, 200)
        self.dl_awgn_snr_widget = make_range_widget(
            self.dl_awgn_snr_range,
            self.set_dl_awgn_snr_db,
            "Downlink AWGN SNR [dB]",
        )
        self.top_layout.addWidget(self.dl_awgn_snr_widget)

        self.ul_awgn_snr_range = Range(-20, 100, 1, self.ul_awgn_snr_db, 200)
        self.ul_awgn_snr_widget = make_range_widget(
            self.ul_awgn_snr_range,
            self.set_ul_awgn_snr_db,
            "Uplink AWGN SNR [dB]",
        )
        self.top_layout.addWidget(self.ul_awgn_snr_widget)

        print(
            f"ZMQ broker sample_rate={SAMPLE_RATE_HZ} slow_down_ratio={SLOW_DOWN_RATIO} cells={len(CELL_CONFIGS)} ues={len(UE_CONFIGS)}",
            flush=True,
        )

        for cell in CELL_CONFIGS:
            cell_number = cell["number"]
            print(
                f"ZMQ broker Cell{cell_number} gNB DL source tcp://127.0.0.1:{cell['rx_port']} UL sink tcp://127.0.0.1:{cell['tx_port']}",
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
            self.cell_ul_awgn[cell_number] = awgn_cc(self.ul_awgn_snr_db)

        for ue in UE_CONFIGS:
            ue_number = ue["number"]
            print(
                f"ZMQ broker UE{ue_number} DL sink tcp://*:{ue['rx_port']} UL source tcp://{ue['ue_ip']}:{ue['tx_port']}",
                flush=True,
            )
            self.ue_dl_adds[ue_number] = blocks.add_vcc(1)
            self.ue_dl_awgn[ue_number] = awgn_cc(self.dl_awgn_snr_db)
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
                (self.ue_dl_awgn[ue_number], 0),
            )
            self.connect(
                (self.ue_dl_awgn[ue_number], 0),
                (self.ue_dl_sinks[ue_number], 0),
            )

        for ue_index, ue in enumerate(UE_CONFIGS):
            ue_number = ue["number"]
            for cell_index, cell in enumerate(CELL_CONFIGS):
                cell_number = cell["number"]
                path_key = (cell_number, ue_number)
                label = f"UE {ue_number} Cell {cell_number} Path Loss [dB]"

                self.path_loss_ranges[path_key] = Range(
                    0, 100, 1, self.path_loss_db[path_key], 200
                )
                self.path_loss_widgets[path_key] = make_range_widget(
                    self.path_loss_ranges[path_key],
                    lambda value, cell_number=cell_number, ue_number=ue_number: self.set_path_loss(
                        cell_number, ue_number, value
                    ),
                    label,
                )
                self.top_layout.addWidget(self.path_loss_widgets[path_key])

                gain = self.path_loss_db_to_iq_gain(self.path_loss_db[path_key])
                self.dl_gains[path_key] = blocks.multiply_const_cc(gain)
                self.ul_gains[path_key] = blocks.multiply_const_cc(gain)

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

    @staticmethod
    def path_loss_db_to_iq_gain(path_loss_db):
        return 10 ** (-path_loss_db / 20.0)

    def set_path_loss(self, cell_number, ue_number, path_loss_db):
        path_key = (cell_number, ue_number)
        self.path_loss_db[path_key] = path_loss_db
        gain = self.path_loss_db_to_iq_gain(path_loss_db)
        self.dl_gains[path_key].set_k(gain)
        self.ul_gains[path_key].set_k(gain)

    def set_slow_down_ratio(self, slow_down_ratio):
        self.slow_down_ratio = slow_down_ratio
        for cell_number in self.dl_throttles:
            self.dl_throttles[cell_number].set_sample_rate(
                self.samp_rate / self.slow_down_ratio
            )

    def set_dl_awgn_snr_db(self, snr_db):
        self.dl_awgn_snr_db = float(snr_db)
        for awgn_block in self.ue_dl_awgn.values():
            awgn_block.set_snr_db(self.dl_awgn_snr_db)

    def set_ul_awgn_snr_db(self, snr_db):
        self.ul_awgn_snr_db = float(snr_db)
        for awgn_block in self.cell_ul_awgn.values():
            awgn_block.set_snr_db(self.ul_awgn_snr_db)

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

echo "Generated ZMQ broker: $OUTPUT"

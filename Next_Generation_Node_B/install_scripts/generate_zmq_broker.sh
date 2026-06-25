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

set -e

OUTPUT=""
SAMPLE_RATE_HZ=""
SLOW_DOWN_RATIO="1"
CELL_COUNT=1
UE_NUMBERS=()
UE_IPS=()

usage() {
    echo "Usage: $0 --output FILE --sample-rate-hz HZ [--slow-down-ratio N] [--cells N] --ue NUMBER:IP [--ue NUMBER:IP ...]"
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
    --cells | --cell-count)
        CELL_COUNT="$2"
        shift 2
        ;;
    --ue)
        UE_VALUE="$2"
        UE_NUMBER="${UE_VALUE%%:*}"
        UE_IP="${UE_VALUE#*:}"
        if ! [[ "$UE_NUMBER" =~ ^[0-9]+$ ]] || [ "$UE_NUMBER" -lt 1 ] || [ "$UE_IP" = "$UE_VALUE" ]; then
            echo "ERROR: UE must be formatted as NUMBER:IP_ADDRESS."
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
        shift 2
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

if [ -z "$OUTPUT" ] || [ -z "$SAMPLE_RATE_HZ" ] || [ ${#UE_NUMBERS[@]} -eq 0 ]; then
    usage
    exit 1
fi
if ! [[ "$SAMPLE_RATE_HZ" =~ ^[0-9]+$ ]] || [ "$SAMPLE_RATE_HZ" -lt 1 ]; then
    echo "ERROR: --sample-rate-hz must be a positive integer."
    exit 1
fi
if ! [[ "$SLOW_DOWN_RATIO" =~ ^[0-9]+$ ]] || [ "$SLOW_DOWN_RATIO" -lt 1 ]; then
    echo "ERROR: --slow-down-ratio must be a positive integer."
    exit 1
fi
if ! [[ "$CELL_COUNT" =~ ^[0-9]+$ ]] || [ "$CELL_COUNT" -lt 1 ]; then
    echo "ERROR: --cells must be a positive integer."
    exit 1
fi

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

for CELL_NUMBER in $(seq 1 "$CELL_COUNT"); do
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

if sys.platform.startswith("linux"):
    try:
        ctypes.cdll.LoadLibrary("libX11.so").XInitThreads()
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

for CELL_NUMBER in $(seq 1 "$CELL_COUNT"); do
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
SAMPLE_RATE = __SAMPLE_RATE_HZ__
SLOW_DOWN_RATIO = __SLOW_DOWN_RATIO__
ZMQ_TIMEOUT = 100
ZMQ_HWM = -1


class multi_ue_scenario(gr.top_block, Qt.QWidget):
    def __init__(self):
        try:
            gr.top_block.__init__(self, "srsRAN_multi_cell_multi_UE", catch_exceptions=True)
        except TypeError:
            gr.top_block.__init__(self, "srsRAN_multi_cell_multi_UE")
        Qt.QWidget.__init__(self)
        self.setWindowTitle("srsRAN_multi_cell_multi_UE")
        qtgui.util.check_set_qss()

        self.top_layout = Qt.QVBoxLayout()
        self.setLayout(self.top_layout)
        self.settings = Qt.QSettings("GNU Radio", "multi_ue_scenario")
        try:
            self.restoreGeometry(self.settings.value("geometry"))
        except Exception:
            pass

        self.samp_rate = SAMPLE_RATE
        self.slow_down_ratio = SLOW_DOWN_RATIO
        self.path_loss_db = {(cell["number"], ue["number"]): 0 for cell in CELL_CONFIGS for ue in UE_CONFIGS}
        self.gnb_dl_sources = {}
        self.gnb_ul_sinks = {}
        self.dl_throttles = {}
        self.ue_dl_sinks = {}
        self.ue_ul_sources = {}
        self.ue_dl_adds = {}
        self.cell_ul_adds = {}
        self.dl_gains = {}
        self.ul_gains = {}
        self.path_loss_ranges = {}
        self.path_loss_widgets = {}

        print(
            f"ZMQ broker sample_rate={SAMPLE_RATE} slow_down_ratio={SLOW_DOWN_RATIO} cells={len(CELL_CONFIGS)} ues={len(UE_CONFIGS)}",
            flush=True,
        )

        for cell in CELL_CONFIGS:
            cell_number = cell["number"]
            print(
                f"ZMQ broker Cell{cell_number} gNB DL source tcp://127.0.0.1:{cell['rx_port']} UL sink tcp://127.0.0.1:{cell['tx_port']}",
                flush=True,
            )
            self.gnb_dl_sources[cell_number] = zeromq.req_source(
                gr.sizeof_gr_complex, 1, f"tcp://127.0.0.1:{cell['rx_port']}", ZMQ_TIMEOUT, False, ZMQ_HWM
            )
            self.gnb_ul_sinks[cell_number] = zeromq.rep_sink(
                gr.sizeof_gr_complex, 1, f"tcp://127.0.0.1:{cell['tx_port']}", ZMQ_TIMEOUT, False, ZMQ_HWM
            )
            self.dl_throttles[cell_number] = blocks.throttle(
                gr.sizeof_gr_complex, self.samp_rate / self.slow_down_ratio, True
            )
            self.cell_ul_adds[cell_number] = blocks.add_vcc(1)

            self.connect((self.gnb_dl_sources[cell_number], 0), (self.dl_throttles[cell_number], 0))
            self.connect((self.cell_ul_adds[cell_number], 0), (self.gnb_ul_sinks[cell_number], 0))

        for ue in UE_CONFIGS:
            ue_number = ue["number"]
            print(
                f"ZMQ broker UE{ue_number} DL sink tcp://*:{ue['rx_port']} UL source tcp://{ue['ue_ip']}:{ue['tx_port']}",
                flush=True,
            )
            self.ue_dl_adds[ue_number] = blocks.add_vcc(1)
            self.ue_dl_sinks[ue_number] = zeromq.rep_sink(
                gr.sizeof_gr_complex, 1, f"tcp://*:{ue['rx_port']}", ZMQ_TIMEOUT, False, ZMQ_HWM
            )
            self.ue_ul_sources[ue_number] = zeromq.req_source(
                gr.sizeof_gr_complex, 1, f"tcp://{ue['ue_ip']}:{ue['tx_port']}", ZMQ_TIMEOUT, False, ZMQ_HWM
            )
            self.connect((self.ue_dl_adds[ue_number], 0), (self.ue_dl_sinks[ue_number], 0))

        for cell_index, cell in enumerate(CELL_CONFIGS):
            cell_number = cell["number"]
            for ue_index, ue in enumerate(UE_CONFIGS):
                ue_number = ue["number"]
                path_key = (cell_number, ue_number)
                label = f"Cell{cell_number} UE{ue_number} Pathloss [dB]"

                self.path_loss_ranges[path_key] = Range(0, 100, 1, 0, 200)
                self.path_loss_widgets[path_key] = RangeWidget(
                    self.path_loss_ranges[path_key],
                    lambda value, cell_number=cell_number, ue_number=ue_number: self.set_path_loss(
                        cell_number, ue_number, value
                    ),
                    label,
                    "counter_slider",
                    float,
                    QtCore.Qt.Horizontal,
                )
                self.top_layout.addWidget(self.path_loss_widgets[path_key])

                gain = self.path_loss_to_gain(self.path_loss_db[path_key])
                self.dl_gains[path_key] = blocks.multiply_const_cc(gain)
                self.ul_gains[path_key] = blocks.multiply_const_cc(gain)

                self.connect((self.dl_throttles[cell_number], 0), (self.dl_gains[path_key], 0))
                self.connect((self.dl_gains[path_key], 0), (self.ue_dl_adds[ue_number], cell_index))
                self.connect((self.ue_ul_sources[ue_number], 0), (self.ul_gains[path_key], 0))
                self.connect((self.ul_gains[path_key], 0), (self.cell_ul_adds[cell_number], ue_index))

    @staticmethod
    def path_loss_to_gain(path_loss_db):
        return 10 ** (-1.0 * path_loss_db / 20.0)

    def set_path_loss(self, cell_number, ue_number, path_loss_db):
        path_key = (cell_number, ue_number)
        self.path_loss_db[path_key] = path_loss_db
        gain = self.path_loss_to_gain(path_loss_db)
        self.dl_gains[path_key].set_k(gain)
        self.ul_gains[path_key].set_k(gain)

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

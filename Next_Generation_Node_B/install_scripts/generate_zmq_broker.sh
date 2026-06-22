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
UE_NUMBERS=()
UE_IPS=()

usage() {
    echo "Usage: $0 --output FILE --sample-rate-hz HZ [--slow-down-ratio N] --ue NUMBER:IP [--ue NUMBER:IP ...]"
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


UE_CONFIGS = [
EOF

for INDEX in "${!UE_NUMBERS[@]}"; do
    UE_NUMBER="${UE_NUMBERS[$INDEX]}"
    UE_RX_PORT=$((2000 + UE_NUMBER * 100))
    UE_TX_PORT=$((2001 + UE_NUMBER * 100))
    echo "    {'number': $UE_NUMBER, 'rx_port': $UE_RX_PORT, 'tx_port': $UE_TX_PORT, 'ue_ip': '${UE_IPS[$INDEX]}'}," >>"$OUTPUT"
done

cat >>"$OUTPUT" <<EOF
]
SAMPLE_RATE = $SAMPLE_RATE_HZ
SLOW_DOWN_RATIO = $SLOW_DOWN_RATIO
ZMQ_TIMEOUT = 100
ZMQ_HWM = -1


class multi_ue_scenario(gr.top_block, Qt.QWidget):
    def __init__(self):
        try:
            gr.top_block.__init__(self, "srsRAN_multi_UE", catch_exceptions=True)
        except TypeError:
            gr.top_block.__init__(self, "srsRAN_multi_UE")
        Qt.QWidget.__init__(self)
        self.setWindowTitle("srsRAN_multi_UE")
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
        self.path_loss_db = {ue["number"]: 0 for ue in UE_CONFIGS}
        self.dl_gains = {}
        self.ul_gains = {}
        self.dl_sinks = {}
        self.ul_sources = {}
        self.path_loss_ranges = {}
        self.path_loss_widgets = {}

        print(f"ZMQ broker sample_rate={SAMPLE_RATE} slow_down_ratio={SLOW_DOWN_RATIO}", flush=True)
        print("ZMQ broker gNB DL source tcp://127.0.0.1:2000", flush=True)
        print("ZMQ broker gNB UL sink tcp://127.0.0.1:2001", flush=True)

        self.gnb_dl_source = zeromq.req_source(
            gr.sizeof_gr_complex, 1, "tcp://127.0.0.1:2000", ZMQ_TIMEOUT, False, ZMQ_HWM
        )
        self.gnb_ul_sink = zeromq.rep_sink(
            gr.sizeof_gr_complex, 1, "tcp://127.0.0.1:2001", ZMQ_TIMEOUT, False, ZMQ_HWM
        )
        self.dl_throttle = blocks.throttle(
            gr.sizeof_gr_complex, self.samp_rate / self.slow_down_ratio, True
        )
        self.ul_add = blocks.add_vcc(1)

        self.connect((self.gnb_dl_source, 0), (self.dl_throttle, 0))

        for index, ue in enumerate(UE_CONFIGS):
            ue_number = ue["number"]
            print(
                f"ZMQ broker UE{ue_number} DL sink tcp://*:{ue['rx_port']} UL source tcp://{ue['ue_ip']}:{ue['tx_port']}",
                flush=True,
            )
            self.path_loss_ranges[ue_number] = Range(0, 100, 1, 0, 200)
            self.path_loss_widgets[ue_number] = RangeWidget(
                self.path_loss_ranges[ue_number],
                lambda value, ue_number=ue_number: self.set_path_loss(ue_number, value),
                f"UE{ue_number} Pathloss [dB]",
                "counter_slider",
                float,
                QtCore.Qt.Horizontal,
            )
            self.top_layout.addWidget(self.path_loss_widgets[ue_number])

            gain = self.path_loss_to_gain(self.path_loss_db[ue_number])
            self.dl_gains[ue_number] = blocks.multiply_const_cc(gain)
            self.ul_gains[ue_number] = blocks.multiply_const_cc(gain)

            self.dl_sinks[ue_number] = zeromq.rep_sink(
                gr.sizeof_gr_complex, 1, f"tcp://*:{ue['rx_port']}", ZMQ_TIMEOUT, False, ZMQ_HWM
            )
            self.ul_sources[ue_number] = zeromq.req_source(
                gr.sizeof_gr_complex, 1, f"tcp://{ue['ue_ip']}:{ue['tx_port']}", ZMQ_TIMEOUT, False, ZMQ_HWM
            )

            self.connect((self.dl_throttle, 0), (self.dl_gains[ue_number], 0))
            self.connect((self.dl_gains[ue_number], 0), (self.dl_sinks[ue_number], 0))
            self.connect((self.ul_sources[ue_number], 0), (self.ul_gains[ue_number], 0))
            self.connect((self.ul_gains[ue_number], 0), (self.ul_add, index))

        self.connect((self.ul_add, 0), (self.gnb_ul_sink, 0))

    @staticmethod
    def path_loss_to_gain(path_loss_db):
        return 10 ** (-1.0 * path_loss_db / 20.0)

    def set_path_loss(self, ue_number, path_loss_db):
        self.path_loss_db[ue_number] = path_loss_db
        gain = self.path_loss_to_gain(path_loss_db)
        self.dl_gains[ue_number].set_k(gain)
        self.ul_gains[ue_number].set_k(gain)

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

chmod 755 "$OUTPUT"

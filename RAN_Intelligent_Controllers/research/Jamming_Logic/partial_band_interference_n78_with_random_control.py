#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#
# SPDX-License-Identifier: GPL-3.0
#
# GNU Radio Python Flow Graph
# Title: Not titled yet
# GNU Radio version: 3.10.1.1

from packaging.version import Version as StrictVersion

if __name__ == '__main__':
    import ctypes
    import sys
    if sys.platform.startswith('linux'):
        try:
            x11 = ctypes.cdll.LoadLibrary('libX11.so')
            x11.XInitThreads()
        except:
            print("Warning: failed to XInitThreads()")

from gnuradio import analog
from gnuradio import blocks
from gnuradio import filter
from gnuradio.filter import firdes
from gnuradio import gr
from gnuradio.fft import window
import sys
import signal
from PyQt5 import Qt
from argparse import ArgumentParser
from gnuradio.eng_arg import eng_float, intx
from gnuradio import eng_notation
from gnuradio import uhd



from gnuradio import qtgui

class partial_band_interference_n78(gr.top_block, Qt.QWidget):

    def __init__(self):
        gr.top_block.__init__(self, "Not titled yet", catch_exceptions=True)
        Qt.QWidget.__init__(self)
        self.setWindowTitle("Not titled yet")
        qtgui.util.check_set_qss()
        try:
            self.setWindowIcon(Qt.QIcon.fromTheme('gnuradio-grc'))
        except:
            pass
        self.top_scroll_layout = Qt.QVBoxLayout()
        self.setLayout(self.top_scroll_layout)
        self.top_scroll = Qt.QScrollArea()
        self.top_scroll.setFrameStyle(Qt.QFrame.NoFrame)
        self.top_scroll_layout.addWidget(self.top_scroll)
        self.top_scroll.setWidgetResizable(True)
        self.top_widget = Qt.QWidget()
        self.top_scroll.setWidget(self.top_widget)
        self.top_layout = Qt.QVBoxLayout(self.top_widget)
        self.top_grid_layout = Qt.QGridLayout()
        self.top_layout.addLayout(self.top_grid_layout)

        self.settings = Qt.QSettings("GNU Radio", "partial_band_interference_n78")

        try:
            if StrictVersion(Qt.qVersion()) < StrictVersion("5.0.0"):
                self.restoreGeometry(self.settings.value("geometry").toByteArray())
            else:
                self.restoreGeometry(self.settings.value("geometry"))
        except:
            pass

        ##################################################
        # Variables
        ##################################################
        self.f_low = f_low = -3.6e6
        self.BW = BW = 7.2e6
        self.samp_rate = samp_rate = 7.2e6
        self.gain_tx = gain_tx = 52
        self.freq_center = freq_center = 3619.2e6
        self.f_high = f_high = f_low+BW

        ##################################################
        # Blocks
        ##################################################
        self.uhd_usrp_sink_0 = uhd.usrp_sink(
            ",".join(("", "type=b200")),
            uhd.stream_args(
                cpu_format="fc32",
                args='',
                channels=list(range(0,1)),
            ),
            "",
        )
        self.uhd_usrp_sink_0.set_clock_source('external', 0)
        self.uhd_usrp_sink_0.set_time_source('external', 0)
        self.uhd_usrp_sink_0.set_samp_rate(samp_rate)
        self.uhd_usrp_sink_0.set_time_unknown_pps(uhd.time_spec(0))

        self.uhd_usrp_sink_0.set_center_freq(freq_center, 0)
        self.uhd_usrp_sink_0.set_antenna("TX/RX", 0)
        self.uhd_usrp_sink_0.set_bandwidth(BW, 0)
        self.uhd_usrp_sink_0.set_gain(gain_tx, 0)
        self.low_pass_filter_0 = filter.fir_filter_ccf(
            1,
            firdes.low_pass(
                1,
                samp_rate,
                f_high,
                20e3,
                window.WIN_HAMMING,
                6.76))
        self.blocks_throttle_0 = blocks.throttle(gr.sizeof_gr_complex*1, samp_rate,True)
        self.analog_fastnoise_source_x_0 = analog.fastnoise_source_c(analog.GR_GAUSSIAN, 1, 0, 16384)


        ##################################################
        # Connections
        ##################################################
        self.connect((self.analog_fastnoise_source_x_0, 0), (self.blocks_throttle_0, 0))
        self.connect((self.blocks_throttle_0, 0), (self.low_pass_filter_0, 0))
        self.connect((self.low_pass_filter_0, 0), (self.uhd_usrp_sink_0, 0))


    def closeEvent(self, event):
        self.settings = Qt.QSettings("GNU Radio", "partial_band_interference_n78")
        self.settings.setValue("geometry", self.saveGeometry())
        self.stop()
        self.wait()

        event.accept()

    def get_f_low(self):
        return self.f_low

    def set_f_low(self, f_low):
        self.f_low = f_low
        self.set_f_high(self.f_low+self.BW)

    def get_BW(self):
        return self.BW

    def set_BW(self, BW):
        self.BW = BW
        self.set_f_high(self.f_low+self.BW)
        self.uhd_usrp_sink_0.set_bandwidth(self.BW, 0)

    def get_samp_rate(self):
        return self.samp_rate

    def set_samp_rate(self, samp_rate):
        self.samp_rate = samp_rate
        self.blocks_throttle_0.set_sample_rate(self.samp_rate)
        self.low_pass_filter_0.set_taps(firdes.low_pass(1, self.samp_rate, self.f_high, 20e3, window.WIN_HAMMING, 6.76))
        self.uhd_usrp_sink_0.set_samp_rate(self.samp_rate)

    def get_gain_tx(self):
        return self.gain_tx

    def set_gain_tx(self, gain_tx):
        self.gain_tx = gain_tx
        self.uhd_usrp_sink_0.set_gain(self.gain_tx, 0)

    def get_freq_center(self):
        return self.freq_center

    def set_freq_center(self, freq_center):
        self.freq_center = freq_center
        self.uhd_usrp_sink_0.set_center_freq(self.freq_center, 0)

    def get_f_high(self):
        return self.f_high

    def set_f_high(self, f_high):
        self.f_high = f_high
        self.low_pass_filter_0.set_taps(firdes.low_pass(1, self.samp_rate, self.f_high, 20e3, window.WIN_HAMMING, 6.76))




def main(top_block_cls=partial_band_interference_n78, options=None):

    if StrictVersion("4.5.0") <= StrictVersion(Qt.qVersion()) < StrictVersion("5.0.0"):
        style = gr.prefs().get_string('qtgui', 'style', 'raster')
        Qt.QApplication.setGraphicsSystem(style)
    qapp = Qt.QApplication(sys.argv)

    tb = top_block_cls()

    tb.show()

    ##################################################
    # Start of radio stats printing
    ##################################################
    radio_on_event_delay_from = 5
    radio_on_event_delay_to = 30
    radio_off_event_delay_from = 20
    radio_off_event_delay_to = 120

    import csv
    import os
    import random
    import time

    now = time.time()
    now_formatted = time.strftime("%Y-%m-%d-%I-%M-%S-%p", time.localtime(now))
    parts = now_formatted.split('-')
    parts[1] = str(int(parts[1])) # Month
    parts[2] = str(int(parts[2])) # Day
    parts[3] = str(int(parts[3])) # Hour
    now_formatted = '-'.join(parts)
    CSV_FILE_PATH = f"Jamming_Metrics_{now_formatted}.csv"
    print(f"Output CSV: {CSV_FILE_PATH}")

    radio_on = False
    delay_duration = 0
    
    def print_radio_stats():
        nonlocal delay_duration
        now = time.time()
        print(f"Time: {now}")
        print(f"   Is Radio On: {'1' if radio_on else '0'}")
        print(f"   TX Gain: {tb.get_gain_tx()}")
        print(f"   Duration (s): {delay_duration}")
        print(f"   Bandwidth: {tb.get_BW()}")
        print(f"   Sample Rate: {tb.get_samp_rate()}")
        print(f"   Center Frequency: {tb.get_freq_center()}")
        print(f"   Low Frequency: {tb.get_f_low()}")
        print(f"   High Frequency: {tb.get_f_high()}")
        # Write to CSV
        fieldnames = ['Time (UNIX Epoch)', 'Is Radio On', 'TX Gain', 'Duration (s)', 'Bandwidth', 'Sample Rate', 'Center Frequency', 'Low Frequency', 'High Frequency']
        row = {
            'Time (UNIX Epoch)': f"{now:.6f}",
            'Is Radio On': '1' if radio_on else '0',
            'TX Gain': tb.get_gain_tx(),
            'Duration (s)': delay_duration,
            'Bandwidth': tb.get_BW(),
            'Sample Rate': tb.get_samp_rate(),
            'Center Frequency': tb.get_freq_center(),
            'Low Frequency': tb.get_f_low(),
            'High Frequency': tb.get_f_high()
        }
        # Write header only if file is empty
        try:
            file_exists = os.path.isfile(CSV_FILE_PATH)
            file_empty = (os.path.getsize(CSV_FILE_PATH) == 0) if file_exists else True
            with open(CSV_FILE_PATH, 'a', newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                if file_empty:
                    writer.writeheader()
                writer.writerow(row)
        except Exception as e:
            print(f"Error writing to CSV: {e}")

    def toggle_radio_event(reschedule=True):
        nonlocal radio_on
        nonlocal delay_duration
        if reschedule:
            if radio_on:
                delay_duration = int(random.uniform(radio_off_event_delay_from, radio_off_event_delay_to) * 1000) / 1000
            else:
                delay_duration = int(random.uniform(radio_on_event_delay_from, radio_on_event_delay_to) * 1000) / 1000
        else:
            delay_duration = ""
        if radio_on:
            print("Turning radio OFF")
            tb.stop()
            tb.wait()
            radio_on = False
        else:
            print("Turning radio ON")
            tb.start()
            radio_on = True
        print_radio_stats()
        if reschedule:
            print(f"Remaining in state for {delay_duration} ms")
            random_event_timer.start(int(delay_duration * 1000)) # ms
        else:
            print("Not rescheduling the radio event.")

    random_event_timer = Qt.QTimer()
    random_event_timer.timeout.connect(toggle_radio_event)
    toggle_radio_event(reschedule=True)

    def sig_handler(sig=None, frame=None):
        nonlocal delay_duration
        delay_duration = 0
        radio_on = False
        print("Exiting gracefully...")
        tb.stop()
        print_radio_stats()

        tb.wait()
        Qt.QApplication.quit()

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)
    
    ##################################################
    # End of radio stats printing
    ##################################################

    timer = Qt.QTimer()
    timer.start(500)
    timer.timeout.connect(lambda: None)

    qapp.exec_()

if __name__ == '__main__':
    main()

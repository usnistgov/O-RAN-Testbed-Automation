## Flexible RAN Intelligent Controller (FlexRIC)

The Near-RT RIC, conceptualized by the O-RAN Alliance's Working Group 3 (WG3) [[1]][oran-wg3] and implemented by Mosaic5G [\[2][publication-nearrtric], [3\]][mosaic5g-nearrtric], enables dynamic management and optimization of Radio Access Networks (RAN).

## Usage

- **Compile**: Use `./full_install.sh` to build and install the Near-RT RIC software.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the Near-RT RIC**: Use `./run.sh` to start the Near-RT RIC application.
- **Stop the Near-RT RIC**: Terminate the Near-RT RIC with `./stop.sh`.
- **Status**: Check if the Near-RT RIC is running with `./is_running.sh`.
- **Logs**: Access logs by navigating to the `logs` directory.
- **Uninstall**: Use `./uninstall.sh` to remove the Near-RT RIC software.

## Running an xApp

This installation of the Near-RT RIC supports six xApps.

- **KPI Monitor xApp (xapp_kpm_moni)**:
  - Run with `./run_xapp_kpm_moni.sh`.
  - Patched to run indefinitely and include several new metrics (see below).
    - Pre-existing metrics from OpenAirInterface:
      ```console
      DRB.PdcpSduVolumeDL (kb) - Downlink volume of the UE since the last sample
      DRB.PdcpSduVolumeUL (kb) - Uplink volume of the UE since the last sample
      DRB.RlcSduDelayDl (μs) - Delay downlink, (100ms-windowed) per-packet sojourn (SDU to PDU) in microseconds
      DRB.UEThpDl (kbps) - Downlink throughput of the UE since the last sample
      DRB.UEThpUl (kbps) - Uplink throughput of the UE since the last sample
      RRU.PrbTotDl (PRB count) - Number of resource blocks received since the last sample
      RRU.PrbTotUl (PRB count) - Number of resource blocks sent since the last sample
      ```
    - New metrics for the automation tool:
      ```console
      RSRP.Mean (dBm) - Averaged SSB/CSI-RS Reference Signal Received Power in the sample
      RSRP.Minimum (dBm) - Minimum SSB/CSI-RS Reference Signal Received Power in the sample
      RSRP.Quartile1 (dBm) - Quartile 1 SSB/CSI-RS Reference Signal Received Power in the sample
      RSRP.Median (dBm) - Quartile 2/Median SSB/CSI-RS Reference Signal Received Power in the sample
      RSRP.Quartile3 (dBm) - Quartile 3 SSB/CSI-RS Reference Signal Received Power in the sample
      RSRP.Maximum (dBm) - Minimum SSB/CSI-RS Reference Signal Received Power in the sample
      RSRP.Count (count) - Number of RSRP measurements in the sample, used to calculate RSRP
      N_PRB (count) - Number of PRBs in the sample, used to calculate RSSI
      RSSI (dBm) - Received Signal Strength Indicator (computed using RSRP and N_PRB: https://www.techplayon.com/rssi)
      PUSCH_SNR (dB) - Signal to noise ratio for Physical Uplink Shared Channel
      PUCCH_SNR (dB) - Signal to noise ratio for Physical Uplink Control Channel
      DRB.HarqMcsUl (MCS index) - Uplink modulation and coding scheme to use
      DRB.HarqMcsDl (MCS index) - Downlink modulation and coding scheme to use
      DRB.HarqBlockErrorRateUl (%) - Percentage of uplink HARQ blocks containing corrupt SDUs
      DRB.HarqBlockErrorRateDl (%) - Percentage of downlink HARQ blocks containing corrupt SDUs
      DRB.MacSduRetransmissionRateUl (%) - Percentage of uplink SDUs retransmitted
      DRB.MacSduRetransmissionRateDl (%) - Percentage of downlink SDUs retransmitted
      DRB.MacSduErrorRateUl (%) - Percentage of corrupt uplink SDUs [Experimental]
      DRB.MacSduErrorRateDl (%) - Percentage of corrupt downlink SDUs [Experimental]
      CQI_SINGLE_CODEWORD - Single codeword channel quality indicator [Experimental]
      CQI_DUAL_CODEWORD - Dual codeword channel quality indicator [Experimental]
      RSRQ (dB) - Reference Signal Received Quality, computed using RSRP, RSSI, and N_PRB [Experimental]
      ```
- **KPI Monitor to CSV xApp (xapp_kpm_moni_write_to_csv)**:
  - Retains all functionality from xapp_kpm_moni, but rather than outputting to stdout, writes to `logs/KPI_Metrics.csv`.
- **KPI Monitor to InfluxDB v2 xApp (xapp_kpm_moni_write_to_influxdb)**:
  - Retains all functionality from xapp_kpm_moni, but rather than outputting to stdout, writes to a InfluxDB database (/var/lib/influxdb).
- **MAC + RLC + PDCP + GTP Monitor xApp (xapp_gtp_mac_rlc_pdcp_moni)**:
  - Run with `./additional_scripts/run_xapp_gtp_mac_rlc_pdcp_moni.sh`.
- **RIC Control xApp (xapp_kpm_rc)**:
  - Run with `./additional_scripts/run_xapp_kpm_rc.sh`.
- **RIC Control Monitor xApp (xapp_rc_moni)**:
  - Run with `./additional_scripts/run_xapp_rc_moni.sh`.

## KPI Monitor Visualization in Grafana

After the KPI Monitor xApp subscribes to the E2 node, metrics of the gNodeB and UE are sent through the E2 interface and received by the xApp. An xApp has been made at `flexric/build/examples/xApp/c/monitor/xapp_kpm_moni_write_to_csv` which writes the metrics to logs/KPI_Metrics.csv instead of printing them to the console. The Python server at `additional_scripts/python_server_for_grafana.py` will make this CSV file accessible at `http://localhost:3030/KPI_Metrics.csv`, and a Grafana dashboard has been created to consume this data and visualize it.

- **Real-Time Metrics**: To start the xApp that generates `logs/KPI_Monitor.csv`, the Python server that hosts the file, and the Grafana server, run the following.
  ```console
  ./additional_scripts/start_grafana_with_xapp_kpm_moni.sh
  ```

- **Non-Real Time Metrics**: Since it is not a requirement for the xApp to actively write metrics to `logs/KPI_Monitor.csv`, the Python server and Grafana server can be started without the xApp by running the following.
  ```console
  ./additional_scripts/start_grafana_only.sh
  ```
  A sample KPI_Metrics.csv file has been provided, and can be applied with `cp additional_scripts/sample_KPI_Metrics.csv logs/KPI_Metrics.csv`.

- **Initial Configuration**: The dashboard uses the Infinity plugin (yesoreyeram-infinity-datasource), which may require creating a data source under Connections → Data sources → Add data source → Infinity. Configure it under URL, Headers & Params → Base URL → Type "`http://localhost:3030/KPI_Metrics.csv`" → Save & test.

- **Stop Grafana**: To stop the Grafana server, Python server, and xApp, use `./additional_scripts/stop_grafana_and_python_server.sh`.

The Grafana dashboard is accessible at `http://localhost:3000` with default credentials being "admin". Upon initial startup, import the following JSON file into the Grafana client by navigating to Dashboards → New → Import: `additional_scripts/grafana_xapp_dashboard.json`. Please note that the dashboard and the metrics provided with this software are still in development and therefore may display some inaccurate values. Below is a snapshot of the dashboard in its current state.

<p align="center">
  <img src="../../../Images/xApp_Dashboard.png" alt="Grafana dashboard of xApp KPI metrics" width="75%">
</p>

## References

1. Working Group 3: Near-Real-time RAN Intelligent Controller and E2 Interface Workgroup. O-RAN Alliance. [https://public.o-ran.org/display/WG3/Introduction][oran-wg3]
2. FlexRIC: an SDK for next-generation SD-RANs. R. Schmidt, M. Irazabal, N. Nikaein. [https://dl.acm.org/doi/10.1145/3485983.3494870][publication-nearrtric]
3. Flexible RAN Intelligent Controller (FlexRIC) and E2 Agent. Mosaic5G. [https://gitlab.eurecom.fr/mosaic5g/flexric][mosaic5g-nearrtric]

<!-- References -->

[oran-wg3]: https://public.o-ran.org/display/WG3/Introduction
[publication-nearrtric]: https://dl.acm.org/doi/10.1145/3485983.3494870
[mosaic5g-nearrtric]: https://gitlab.eurecom.fr/mosaic5g/flexric

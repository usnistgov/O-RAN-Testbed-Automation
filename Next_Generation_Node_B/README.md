## OCUDU Next Generation Node B

The Next Generation Node B (gNodeB) is a 5G base station configured with OCUDU [\[1\]][ocudu-gnb], connecting User Equipments (UEs) to the 5G Core Network based on the specifications outlined in 3GPP TS 38.300 [\[2\]][ts3191-3gpp], 3GPP TS 38.401 [\[3\]][ts3219-3gpp], and 3GPP TS 38.413 [\[4\]][ts3223-3gpp].

## Usage

- **Compile**: Use `./full_install.sh` to build and install the gNodeB software.
- **Rebuild**: Use `./rebuild_code.sh` to rebuild and reinstall the gNodeB software after source changes. The script reuses the existing build directory, so unchanged files are not rebuilt.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - The script automatically retrieves the 5G Core Network's AMF address and the SCTP address from the Near-Real-Time RAN Intelligent Controller's E2 Terminator. If either are not found locally, the script will prompt the user to enter the address manually.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the gNodeB**: Use `./run.sh` to start the gNodeB, or `./run_background.sh` to run it as a background process where the output is redirected to `logs/gnb_stdout.txt`.
- **Stop the gNodeB**: Terminate the gNodeB with `./stop.sh`.
- **Status**: Check if the gNodeB is running with `./is_running.sh`.
- **Logs**: Access logs by navigating to the `logs` directory.
- **Uninstall**: Use `./uninstall.sh` to remove the gNodeB software.

> [!NOTE]
> If the directory `RAN_Intelligent_Controllers/Near-Real-Time-RIC` is not found, then the `generate_configurations.sh` script will disable the E2 interface. Alternatively, if prompted to enter an E2 address, enter nothing ("") to disable the E2 interface in the gNodeB configuration.

## Simulating Multiple UEs with ZeroMQ Broker

By default, the gNodeB connects directly to a single SRS UE. To facilitate multi-UE emulation, the testbed can utilize a ZeroMQ (ZMQ) Broker based on the OCUDU Multi-UE Emulation tutorial [\[5\]][ocudu-multi-ue]. The broker Python runtime script is generated during configuration from the requested UE list using `install_scripts/generate_zmq_broker.sh`. The ZMQ Broker operates the simulated ZeroMQ channel. Its graphical user interface is disabled by default, but can be enabled by setting `SHOW_ZMQ_BROKER_UI=true` in `run.sh`.

Broker mode generates a 10 MHz / 11.52 Msps RF profile with the OCUDU narrow-band PUCCH/SR resources required for 5/10 MHz cells and runs the broker at real-time sample pacing. Direct single-UE ZMQ keeps the 20 MHz / 23.04 Msps profile. OCUDU commit `3f609dea0e` does not accept `cell_cfg.dl_ssb_arfcn`; the UE-side generator derives the required SSB ARFCN from the supported Band 3 profile instead.

To enable the broker, set all occurrences of `USE_ZMQ_BROKER` to `true`, then run `../generate_configurations.sh`.

<details>
<summary>Enable ZMQ broker</summary>

```bash
sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' ../run.sh
sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' run.sh
sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' full_install.sh
sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' generate_configurations.sh
sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' is_running.sh
sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' run_background.sh
sed -i 's/^USE_ZMQ_BROKER=false$/USE_ZMQ_BROKER=true/' stop.sh
````

</details>

<details>
<summary>Disable ZMQ broker (default)</summary>

```bash
sed -i 's/^USE_ZMQ_BROKER=true$/USE_ZMQ_BROKER=false/' ../run.sh
sed -i 's/^USE_ZMQ_BROKER=true$/USE_ZMQ_BROKER=false/' run.sh
sed -i 's/^USE_ZMQ_BROKER=true$/USE_ZMQ_BROKER=false/' full_install.sh
sed -i 's/^USE_ZMQ_BROKER=true$/USE_ZMQ_BROKER=false/' generate_configurations.sh
sed -i 's/^USE_ZMQ_BROKER=true$/USE_ZMQ_BROKER=false/' is_running.sh
sed -i 's/^USE_ZMQ_BROKER=true$/USE_ZMQ_BROKER=false/' run_background.sh
sed -i 's/^USE_ZMQ_BROKER=true$/USE_ZMQ_BROKER=false/' stop.sh
```

</details>

- When the ZMQ broker is enabled, `run.sh` on the base directory starts all generated UEs. It starts all but the lowest-numbered UE as background processes, then starts the lowest-numbered UE in the foreground while monitoring every selected UE for PDU-session establishment. The generated broker has one uplink input per UE, so the UE processes are started together before PDU-session checks.

> [!NOTE]
> To configure a specific emulated UE set, pass the UE numbers to the top-level generator, for example `../generate_configurations.sh 1 2 3 4`. The generated broker creates one downlink and one uplink branch for each requested UE, and the top-level `run.sh` launches the generated UE set unless explicit UE numbers are passed to `run.sh`. UE numbers above the preloaded subscriber set still require subscriber registration in the 5G Core.

The top-level generator verifies that the generated broker, gNodeB, and UE configs agree before finishing. The same check can be run manually from this directory with:

```bash
./install_scripts/validate_zmq_broker_config.sh
```

After a live multi-UE run, list the PDU sessions for each UE from the repository root:

```bash
User_Equipment/install_scripts/get_pdu_sessions.sh 1
User_Equipment/install_scripts/get_pdu_sessions.sh 2
User_Equipment/install_scripts/get_pdu_sessions.sh 3
```

## E2 Interface

By default, the gNodeB's Distributed Unit (DU) connects to the O-RAN Software Community's Near-Real-Time RAN Intelligent Controller (O-RAN SC Near-RT RIC) E2 Terminator. To use FlexRIC instead of O-RAN SC's Near-RT RIC, set all occurrences of `USE_FLEXRIC` to `true`, then run `../generate_configurations.sh`.

<details>
<summary>Enable FlexRIC</summary>

```bash
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_install.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_uninstall.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../generate_configurations.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../run.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../stop.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' generate_configurations.sh
```

</details>

<details>
<summary>Disable FlexRIC (default)</summary>

```bash
sed -i 's/^USE_FLEXRIC=true$/USE_FLEXRIC=false/' ../full_install.sh
sed -i 's/^USE_FLEXRIC=true$/USE_FLEXRIC=false/' ../full_uninstall.sh
sed -i 's/^USE_FLEXRIC=true$/USE_FLEXRIC=false/' ../generate_configurations.sh
sed -i 's/^USE_FLEXRIC=true$/USE_FLEXRIC=false/' ../run.sh
sed -i 's/^USE_FLEXRIC=true$/USE_FLEXRIC=false/' ../stop.sh
sed -i 's/^USE_FLEXRIC=true$/USE_FLEXRIC=false/' generate_configurations.sh
```

</details>

## O1 Interface

The gNodeB can also be monitored and controlled through the OCUDU O1 Adapter [\[6\]][ocudu-o1-adapter]. Management scripts for the O1 interface are located in the `additional_scripts/` directory. Use `./additional_scripts/install_o1_adapter.sh` to install and build the required components, `./additional_scripts/run_o1_adapter.sh` to start the O1 services, `./additional_scripts/stop_o1_adapter.sh` to stop them, and `./additional_scripts/uninstall_o1_adapter.sh` to remove them.

When running, the O1 setup starts a NETCONF Docker container `ocudu_netconf` and the OCUDU O1 adapter system process. The NETCONF endpoint is exposed at `127.0.0.1:830`.

## OCUDU Grafana WebUI

The gNodeB includes support for visualizing performance metrics via a Grafana dashboard hosted at `http://localhost:3300`.

- **Start Grafana WebUI**: Start the dashboard and its Docker Compose dependencies with `./start_grafana_webui.sh`.
- **Stop Grafana WebUI**: Stop the dashboard container with `./stop_grafana_webui.sh`.

![OCUDU Grafana WebUI and ZMQ Broker](../Images/OCUDU_Grafana_WebUI.png)

## References

1. OCUDU Ecosystem Foundation. [https://ocudu.org][ocudu-gnb]
2. 3GPP TS 38.300: NR; NR and NG-RAN Overall description; Stage-2 [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191][ts3191-3gpp]
3. 3GPP TS 38.401: NG-RAN; Architecture description. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219][ts3219-3gpp]
4. 3GPP TS 38.413: NG-RAN; NG Application Protocol (NGAP). [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223][ts3223-3gpp]
5. OCUDU Project Documentation: OCUDU with srsUE [https://ocudu.gitlab.io/ocudu_docs/user_manual/tutorials/srsue/#multi-ue-emulation][ocudu-multi-ue]
6. OCUDU O1 Adapter [https://ocudu.gitlab.io/ocudu_docs/oran_apps/ocudu_o1_adapter/][ocudu-o1-adapter]

<!-- References -->

[ocudu-gnb]: https://ocudu.org
[ts3191-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191
[ts3219-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219
[ts3223-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223
[ocudu-multi-ue]: https://ocudu.gitlab.io/ocudu_docs/user_manual/tutorials/srsue/#multi-ue-emulation
[ocudu-o1-adapter]: https://ocudu.gitlab.io/ocudu_docs/oran_apps/ocudu_o1_adapter/

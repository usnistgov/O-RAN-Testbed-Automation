## OCUDU Next Generation Node B

The Next Generation Node B (gNodeB) is a 5G base station configured with OCUDU [\[1\]][ocudu-gnb], connecting User Equipments (UEs) to the 5G Core Network based on the specifications outlined in 3GPP TS 38.300 [\[2\]][ts3191-3gpp], 3GPP TS 38.401 [\[3\]][ts3219-3gpp], and 3GPP TS 38.413 [\[4\]][ts3223-3gpp].

## Usage

- **Compile**: Use `./full_install.sh` to build and install the gNodeB software.
- **Rebuild**: Use `./rebuild_code.sh` to rebuild and reinstall the gNodeB software after source changes. The script reuses the existing build directory, so unchanged files are not rebuilt.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - The script automatically retrieves the 5G Core Network's AMF address and the SCTP address from the Near-Real-Time RAN Intelligent Controller's E2 Terminator. If either are not found locally, the script will prompt the user to enter the address manually.
  - An optional list of UE numbers for multi-UE emulation can be provided with `--ues <ue_numbers>` as a comma-separated list, for example `./generate_configurations.sh --ues 1,2,3`, to generate the ZeroMQ channel emulator configuration (see [here](/Next_Generation_Node_B/README.md#simulating-multiple-ues-and-cells-with-a-zeromq-channel-emulator) for more information).
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the gNodeB**: Use `./run.sh` to start the gNodeB, or `./run_background.sh` to run it as a background process where the output is redirected to `logs/gnb_stdout.txt`.
- **Stop the gNodeB**: Terminate the gNodeB with `./stop.sh`.
- **Status**: Check if the gNodeB is running with `./is_running.sh`.
- **Logs**: Access logs by navigating to the `logs` directory.
- **Uninstall**: Use `./uninstall.sh` to remove the gNodeB software.

> [!TIP]
> If the directory `RAN_Intelligent_Controllers/Near-Real-Time-RIC` is not found, then the `generate_configurations.sh` script will disable the E2 interface. Alternatively, if prompted to enter an E2 address, enter nothing ("") to disable the E2 interface in the gNodeB configuration.

## Simulating Multiple UEs and Cells with a ZeroMQ Channel Emulator

By default, the gNodeB uses a ZeroMQ (ZMQ) channel emulator with cell 1 and UEs 1, 2, and 3. It supports multi-UE and multi-cell emulation and is motivated by the OCUDU Multi-UE Emulation tutorial [\[5][ocudu-multi-ue], [6\]][ocudu-multi-ue-grc]. The Python runtime script is generated under `zmq_channel_emulator` using `install_scripts/generate_zmq_channel_emulator.sh`. The generator accepts comma-separated UE numbers, such as `--ues 1,2,3`. Its graphical user interface can be toggled by setting `SHOW_ZMQ_CHANNEL_EMULATOR_UI` in `run.sh`.

To connect the gNodeB directly to a single SRS UE without the channel emulator, set all occurrences of `USE_ZMQ_CHANNEL_EMULATOR` to `false`, then run the base directory configuration script: `../generate_configurations.sh`.

<details>
<summary>Disable ZeroMQ channel emulator</summary>

```bash
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=true$/USE_ZMQ_CHANNEL_EMULATOR=false/' ../run.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=true$/USE_ZMQ_CHANNEL_EMULATOR=false/' ../generate_configurations.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=true$/USE_ZMQ_CHANNEL_EMULATOR=false/' run.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=true$/USE_ZMQ_CHANNEL_EMULATOR=false/' generate_configurations.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=true$/USE_ZMQ_CHANNEL_EMULATOR=false/' is_running.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=true$/USE_ZMQ_CHANNEL_EMULATOR=false/' run_background.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=true$/USE_ZMQ_CHANNEL_EMULATOR=false/' stop.sh
```

</details>

To restore the default channel emulator configuration, set all occurrences of `USE_ZMQ_CHANNEL_EMULATOR` to `true`, then run the base directory configuration script: `../generate_configurations.sh`.

<details>
<summary>Enable ZeroMQ channel emulator (default)</summary>

```bash
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' ../run.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' ../generate_configurations.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' generate_configurations.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' is_running.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' run_background.sh
sed -i 's/^USE_ZMQ_CHANNEL_EMULATOR=false$/USE_ZMQ_CHANNEL_EMULATOR=true/' stop.sh
```

</details>

> [!NOTE]
> When the ZeroMQ channel emulator is enabled, the base directory `run.sh` starts all but the first UE as background processes, then starts the first UE in the foreground.

<details>
<summary>Configure multiple UEs</summary>

To configure a specific emulated UE set, pass the UE numbers to the base directory generator with `--ues` as a comma-separated list, e.g., `../generate_configurations.sh --ues 1,2,3`. The generated channel emulator creates one downlink and one uplink route for each requested UE, and the base directory `run.sh` launches the generated UE set.

</details>

<details>
<summary>Troubleshoot UE attach</summary>

If one or more UEs remain stuck while attaching with the ZeroMQ channel emulator, check `ZMQ_TIMEOUT` in `Next_Generation_Node_B/zmq_channel_emulator/zmq_channel_emulator.py`. Slower systems may require an increase from the default value of `100`, but larger values may slow attach and PDU session establishment. `ZMQ_HIGH_WATER_MARK` is left as `-1` by default to use the GNU Radio/ZeroMQ default buffering behavior.
</details>


<details>
<summary>Configure multiple cells</summary>

To configure multiple cells with the channel emulator, pass `--cells <cell_numbers>` to the base directory generator, e.g., `../generate_configurations.sh --cells 1,2,3`. The generated channel emulator creates one gNB-side downlink/uplink port pair per cell and one path-loss control for each cell/UE pair. Specific UEs can be specified with `--ues <ue_numbers>`, e.g., `--ues 9,8,7`.

</details>

<details>
<summary>Retrieve PDU session IPs</summary>

After multiple UEs are running, the PDU session IP can be retrieved with the following.

```bash
# List all PDU sessions for all UEs:
./User_Equipment/additional_scripts/get_all_pdu_sessions.sh

# List PDU sessions for a specific UE:
./User_Equipment/install_scripts/get_pdu_sessions.sh 1
./User_Equipment/install_scripts/get_pdu_sessions.sh 2
./User_Equipment/install_scripts/get_pdu_sessions.sh 3
```

</details>



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

The gNodeB can also be monitored and controlled through the OCUDU O1 Adapter [\[7\]][ocudu-o1-adapter]. Management scripts for the O1 interface are located in the `additional_scripts/` directory. Use `./additional_scripts/install_o1_adapter.sh` to install and build the required components, `./additional_scripts/run_o1_adapter.sh` to start the O1 services, `./additional_scripts/stop_o1_adapter.sh` to stop them, and `./additional_scripts/uninstall_o1_adapter.sh` to remove them.

When running, the O1 setup starts a NETCONF Docker container `ocudu_netconf` and the OCUDU O1 adapter system process. The NETCONF endpoint is exposed at `127.0.0.1:830`.

## OCUDU Grafana WebUI

The gNodeB includes support for visualizing performance metrics via a Grafana dashboard hosted at `http://localhost:3300`.

- **Start Grafana WebUI**: Start the dashboard and its Docker Compose dependencies with `./start_grafana_webui.sh`.
- **Stop Grafana WebUI**: Stop the dashboard container with `./stop_grafana_webui.sh`.

![OCUDU Grafana WebUI and ZeroMQ Channel Emulator](../Images/OCUDU_Grafana_WebUI.png)

## References

1. OCUDU Ecosystem Foundation. [https://ocudu.org][ocudu-gnb]
2. 3GPP TS 38.300: NR; NR and NG-RAN Overall description; Stage-2 [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191][ts3191-3gpp]
3. 3GPP TS 38.401: NG-RAN; Architecture description. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219][ts3219-3gpp]
4. 3GPP TS 38.413: NG-RAN; NG Application Protocol (NGAP). [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223][ts3223-3gpp]
5. OCUDU Project Documentation: OCUDU with srsUE [https://ocudu.gitlab.io/ocudu_docs/tutorials/srsue/#multi-ue-emulation][ocudu-multi-ue]
6. OCUDU Multi-UE Emulation GRC [https://gitlab.com/ocudu/ocudu_docs/-/blob/main/docs/tutorials/srsue/assets/multi_ue_scenario.grc][ocudu-multi-ue-grc]
7. OCUDU O1 Adapter [https://ocudu.gitlab.io/ocudu_docs/oran_apps/ocudu_o1_adapter/][ocudu-o1-adapter]

<!-- References -->

[ocudu-gnb]: https://ocudu.org
[ts3191-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191
[ts3219-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219
[ts3223-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223
[ocudu-multi-ue]: https://ocudu.gitlab.io/ocudu_docs/tutorials/srsue/#multi-ue-emulation
[ocudu-multi-ue-grc]: https://gitlab.com/ocudu/ocudu_docs/-/blob/main/docs/tutorials/srsue/assets/multi_ue_scenario.grc
[ocudu-o1-adapter]: https://ocudu.gitlab.io/ocudu_docs/oran_apps/ocudu_o1_adapter/

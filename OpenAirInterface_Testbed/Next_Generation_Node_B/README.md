## Next Generation Node B

The Next Generation Node B (gNodeB) is a 5G base station configured with OpenAirInterface [\[1\]][oai-gnb], connecting User Equipments (UEs) to the 5G Core Network based on the specifications outlined in 3GPP TS 38.300 [\[2\]][ts3191-3gpp], 3GPP TS 38.401 [\[3\]][ts3219-3gpp], and 3GPP TS 38.413 [\[4\]][ts3223-3gpp].

## Usage

- **Compile**: Use `./full_install.sh` to build and install the gNodeB software.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - The script automatically retrieves the 5G Core Network's AMF address. If it is not found locally, the script will prompt the user to enter the address manually.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the gNodeB**: Use `./run.sh` to start the gNodeB, or `./run_background.sh` to run it as a background process where the output is redirected to `logs/gnb_stdout.txt`.
- **Stop the gNodeB**: Terminate the gNodeB with `./stop.sh`.
- **Status**: Check if the gNodeB is running with `./is_running.sh`.
- **Logs**: Access logs by navigating to the `logs` directory.
- **Uninstall**: Use `./uninstall.sh` to remove the gNodeB/UE software.

## Telnet Server for Monitoring and Control

This gNodeB supports an optional telnet server for monitoring and controlling the gNodeB [\[5\]][oai-telnet]. It can be enabled by setting `TELNET_SERVER=true` in the beginning of the `full_install.sh` script before running it. When starting the gNodeB, if the telnet server was installed, it will automatically start, and can be accessed by directly typing into the gNodeB terminal or with `telnet 127.0.0.1 9099`. Use the `help` command within the telnet session to see available commands.

### Telnet Connection to O1 Interface

The gNodeB can be monitored and controlled remotely using the O1 adapter [\[6\]][oai-o1-adapter], which runs as a Docker container. The scripts to manage the O1 adapter container are located in the `additional_scripts/` directory. Use the installer script `install_o1_adapter.sh` to configure the adapter, `./run_o1_adapter.sh` to start the container and connect to the gNodeB's telnet server, `./stop_o1_adapter.sh` to stop the container, and `./uninstall_o1_adapter.sh` to uninstall the O1 adapter.

## References

1. Openairinterface 5G Wireless Implementation. OpenAirInterface. [https://gitlab.eurecom.fr/oai/openairinterface5g][oai-gnb]
2. 3GPP TS 38.300: NR; NR and NG-RAN Overall description; Stage-2 [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191][ts3191-3gpp]
3. 3GPP TS 38.401: NG-RAN; Architecture description. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219][ts3219-3gpp]
4. 3GPP TS 38.413: NG-RAN; NG Application Protocol (NGAP). [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223][ts3223-3gpp]
5. Starting the softmodem with the telnet server. OpenAirInterface. [https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/develop/common/utils/telnetsrv/DOC/telnetusage.md][oai-telnet]
6. OAI O1 Adapter. OpenAirInterface. [https://gitlab.eurecom.fr/oai/o1-adapter][oai-o1-adapter]

<!-- References -->

[oai-gnb]: https://gitlab.eurecom.fr/oai/openairinterface5g
[ts3191-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191
[ts3219-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219
[ts3223-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223
[oai-telnet]: https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/develop/common/utils/telnetsrv/DOC/telnetusage.md[oai-o1-adapter]: https://gitlab.eurecom.fr/oai/o1-adapter
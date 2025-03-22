## OpenAirInterface Testbed

This testbed deployment consists of a 5G Core Network by Open5GS [[1]][open5gs-core], gNodeB and 5G UE by OpenAirInterface [[2]][oai-ue-gnb], and FlexRIC by Mosaic5G [[3]][mosaic-flexric].

## Usage

- **Installation**: Use `./full_install.sh` to build and install the testbed components, and `./full_uninstall.sh` to remove them.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files for each testbed component.
- **Start the Testbed**: Use `./run.sh` to start the 5G Core, FlexRIC, gNodeB, and UE as background processes, and KPI monitoring xApp in the foreground.
- **Run an xApp**: Once all components are running and properly connected, use the `./run_xapp_*` scripts within the RAN_Intelligent_Controllers/FlexRIC/additional_scripts directory to interact with the gNodeB and UE.
- **Stop the Testbed**: Terminate the testbed components with `./stop.sh`.
- **Status**: Check which testbed components are running with `./is_running.sh`.
- **Debugging Information**: Configuration files are in the `configs/` directory, and log files are located in the `logs/` directory for each component.

> [!IMPORTANT]
> OpenAirInterface's support for Linux Mint is currently limited. It is recommended to use Ubuntu.

## References

1. Open Source implementation for 5G Core and EPC. Open5GS. [https://github.com/open5gs/open5gs][open5gs-core]
2. Openairinterface 5G Wireless Implementation. OpenAirInterface. [https://gitlab.eurecom.fr/oai/openairinterface5g][oai-ue-gnb]
3. Flexible RAN Intelligent Controller (FlexRIC) and E2 Agent. Mosaic5G. [https://gitlab.eurecom.fr/mosaic5g/flexric][mosaic-flexric]

<!-- References -->

[open5gs-core]: https://github.com/open5gs/open5gs
[oai-ue-gnb]: https://gitlab.eurecom.fr/oai/openairinterface5g
[mosaic-flexric]: https://gitlab.eurecom.fr/mosaic5g/flexric
[ts3191-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191
[ts3219-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219
[ts3223-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223

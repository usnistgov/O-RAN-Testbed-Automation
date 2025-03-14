## OpenAirInterface Testbed

This testbed consists of the 5G Core Network by Open5GS [[1]][open5gs-core], gNodeB and 5G UE by OpenAirInterface [[2]][oai-ue-gnb], and FlexRIC by Mosaic5G [[3]][mosaic-flexric].

## Usage

- **Installation**: Use `./full_install.sh` to build the testbed components.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files for each testbed component.
- **Start the Testbed**: Use `./run.sh` to start the testbed components.
- **Stop the Testbed**: Terminate the testbed components with `./stop.sh`.
- **Status**: Check if the testbed components are running with `./is_running.sh`.

> [!IMPORTANT]
> OpenAirInterface's support for Linux Mint is limited. It is recommended to use Ubuntu.

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

## User Equipment

The following scripts operationalize a 5G User Equipment (UE) configured with OpenAirInterface [[1]][oai-ue], designed to connect to the gNodeB and establish a PDU session with the 5G Core Network based on the specifications outlined in 3GPP TS 36.300 [[2]][ts2430-3gpp], 3GPP TS 36.331 [[3]][ts2440-3gpp], 3GPP TS 36.401 [[4]][ts2442-3gpp], 3GPP TS 36.413 [[5]][ts2446-3gpp], and 3GPP TS 23.401 [[6]][ts849-3gpp].

## Usage

- **Compile**: Use `./full_install.sh` to build and install the UE software.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the UE**: Use `./run.sh` to start the UE, or `./run_background.sh` to run it as a background process where the output is redirected to `logs/ue1_stdout.txt`.
- **Stop the UE**: Terminate the UE with `./stop.sh`.
- **Status**: Check is a UE is running with `./is_running.sh`.
- **Logs**: Access logs by navigating to the `logs` directory.
- **Uninstall**: Use `./uninstall.sh` to remove the UE/gNodeB software.

## References

1. Openairinterface 5G Wireless Implementation. OpenAirInterface. [https://gitlab.eurecom.fr/oai/openairinterface5g][oai-ue]
2. 3GPP TS 36.300: Evolved Universal Terrestrial Radio Access (E-UTRA) and Evolved Universal Terrestrial Radio Access Network (E-UTRAN); Overall description; Stage 2. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2430][ts2430-3gpp]
3. 3GPP TS 36.331: Evolved Universal Terrestrial Radio Access (E-UTRA); Radio Resource Control (RRC); Protocol specification. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2440][ts2440-3gpp]
4. 3GPP TS 36.401: Evolved Universal Terrestrial Radio Access Network (E-UTRAN); Architecture description. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2442][ts2442-3gpp]
5. 3GPP TS 36.413: Evolved Universal Terrestrial Radio Access Network (E-UTRAN); S1 Application Protocol (S1AP). [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2446][ts2446-3gpp]
6. 3GPP TS 23.401: General Packet Radio Service (GPRS) enhancements for Evolved Universal Terrestrial Radio Access Network (E-UTRAN) access. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=849][ts849-3gpp]

<!-- References -->

[oai-ue]: https://gitlab.eurecom.fr/oai/openairinterface5g
[ts2430-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2430
[ts2440-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2440
[ts2442-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2442
[ts2446-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2446
[ts849-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=849

## User Equipment

The following scripts operationalize a 5G User Equipment (UE) configured with OpenAirInterface [\[1\]][oai-ue], designed to connect to the gNodeB and establish a PDU session with the 5G Core Network based on the specifications outlined in 3GPP TS 36.300 [\[2\]][ts2430-3gpp], 3GPP TS 36.331 [\[3\]][ts2440-3gpp], 3GPP TS 36.401 [\[4\]][ts2442-3gpp], 3GPP TS 36.413 [\[5\]][ts2446-3gpp], and 3GPP TS 23.401 [\[6\]][ts849-3gpp].

## Usage

- **Compile**: Use `./full_install.sh` to build and install the UE software.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the UE**: Use `./run.sh` to start the UE, or `./run_background.sh` to run it as a background process where the output is redirected to `logs/ue1_stdout.txt`.
  - To operate multiple UEs, execute `./run.sh <N>` or `./run_background.sh <N>`, where `<N>` is an identifying number for the UE. If the subscriber information for `<N>` is not registered with the 5G Core, the script will automatically generate and register the subscriber information before starting the UE.
- **Stop the UE**: Terminate the UE with `./stop.sh`.
  - To stop an individual UE, use `./stop.sh <N>`.
- **Status**: Check running UEs with `./is_running.sh`. The output will display which UEs are running.
- **Logs**: Access logs by navigating to the `logs` directory.
- **Uninstall**: Use `./uninstall.sh` to remove the UE/gNodeB software.

## Multiple UEs

The `run.sh`, `run_background.sh`, and `stop.sh` scripts can be given an optional `<N>` argument (default: 1) to specify which UE to run or stop. Each UE is assigned the following unique parameters:

- IMEI
- IMSI
- Key
- Network namespace

To customize the SIM subscriber information or to get more information about how they are generated, refer to the `ue_credentials_generator.sh` script. For UE 1, UE 2, and UE 3, the SIM subscriber information is pre-registered with the 5G Core Network. For `<N>` values greater than 3, the unique values are generated dynamically, registered with the 5G Core, and stored in the `configs` directory as their own `ue<N>.conf` file before starting the UE software.

## RF Simulator Server

By default, the RF simulator server is set to the gNodeB host. To make the UE the server, add `--rfsim-server` to the `run.sh` command. This is useful in multi-DU scenarios where the UE may be handed over between different DUs.

## Interacting with the UE

- **Simulate UE traffic to Core**:
  `./additional_scripts/simulate_ue_traffic_to_core.sh <UE_NUMBER> [BANDWIDTH] [DURATION]`
  - Sends traffic from the UE to the core. Default bandwidth: 1M, duration: 60s.

- **Simulate Core traffic to UE**:
  `./additional_scripts/simulate_core_traffic_to_ue.sh <UE_NUMBER> [BANDWIDTH] [DURATION]`
  - Sends traffic from the core to the UE. Default bandwidth: 1M, duration: 60s.

- **Open UE shell**:
  `./additional_scripts/open_ue_shell.sh <UE_NUMBER>`
  - Opens a shell in the UE's network namespace.

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

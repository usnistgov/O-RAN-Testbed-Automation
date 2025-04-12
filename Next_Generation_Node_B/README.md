## Next Generation Node B

The Next Generation Node B (gNodeB) is a 5G base station configured with srsRAN_Project [[1]][srsran-gnb], connecting User Equipments (UEs) to the 5G Core Network based on the specifications outlined in 3GPP TS 38.300 [[2]][ts3191-3gpp], 3GPP TS 38.401 [[3]][ts3219-3gpp], and 3GPP TS 38.413 [[4]][ts3223-3gpp].

## Usage

- **Compile**: Use `./full_install.sh` to build and install the gNodeB software.
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

## References

1. srsRAN Project Documentation. Software Radio Systems. [https://docs.srsran.com/projects/project/en/latest/index.html][srsran-gnb]
2. 3GPP TS 38.300: NR; NR and NG-RAN Overall description; Stage-2 [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191][ts3191-3gpp]
3. 3GPP TS 38.401: NG-RAN; Architecture description. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219][ts3219-3gpp]
4. 3GPP TS 38.413: NG-RAN; NG Application Protocol (NGAP). [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223][ts3223-3gpp]

<!-- References -->

[srsran-gnb]: https://docs.srsran.com/projects/project/en/latest/index.html
[ts3191-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3191
[ts3219-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3219
[ts3223-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3223

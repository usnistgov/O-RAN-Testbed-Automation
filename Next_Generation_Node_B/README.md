## Next Generation Node B

The Next Generation Node B (gNodeB) is a base station configured with the srsRAN project [[1]][srsran-srsran], connecting User Equipments (UEs) to the 5G Core Network.

## Usage
- **Compile**: Use `./full_install.sh` to build the gNodeB.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - The script automatically retrieves the 5G Core Network's AMF address and the SCTP address from the Near Real-Time RAN Intelligent Controller's E2 Terminator. If either are not found, the script will prompt the user to enter the address manually.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the gNodeB**: Use `./run.sh` to start the gNodeB, or `./run_background.sh` to run it as a background process where the output is redirected to `logs/gnb_stdout.txt`.
- **Stop the gNodeB**: Terminate the gNodeB with `./stop.sh`.
- **Status**: Check if the gNodeB is running with `./is_running.sh`. The output will display the running status.
- **Logs**: Access logs by navigating to the `logs` directory.

## References
1. srsRAN Project Documentation. Software Radio Systems. [https://docs.srsran.com/projects/project/en/latest/index.html][srsran-gnb]

<!-- References -->

[srsran-gnb]: https://docs.srsran.com/projects/project/en/latest/index.html

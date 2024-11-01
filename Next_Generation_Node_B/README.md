## Next Generation Node B

The Next Generation Node B (gNodeB) is a base station based on [srsRAN_Project][srsran-srsran], and is configured to connect to the 5G Core Network and provide a connection to the User Equipments.

## Usage
- Compile the gNodeB with `./full_install.sh`.
- Generate the configuration files with `./generate_configurations.sh`.
  - The script fetches the address of the 5G Core Network's AMF and the SCTP address from the Near Real-Time RAN Intelligent Controller's E2 Terminator. If either are not found, the script will prompt the user to enter the address manually.
  - To view or modify the configuration file, navigate to the `configs` directory.
- Run the gNodeB with `./run_foreground.sh`, or as a background process with `./run.sh`, where the output is redirected to `logs/gnb_stdout.txt`.
- Stop the gNodeB with `./stop.sh`.
- Check if the gNodeB is running with `./is_running.sh`.
- Access the log files by navigating to the `logs` directory.

<!-- References -->

[srsran-gnb]: https://docs.srsran.com/projects/project/en/latest/knowledge_base/source/oran_gnb/source/index.html

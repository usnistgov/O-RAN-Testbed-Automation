## User Equipment

The User Equipment (UE) is a simulated device utilizing the srsRAN_4G software provided by srsRAN [[1]][srsran-srsue], designed to connect to the gNodeB and establish a PDU session with the 5G Core Network.

## Usage
- **Compile**: Use `./full_install.sh` to build the UE software.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the UE**: Use `./run.sh` to start the UE, or `./run_background.sh` to run it as a background process where the output is redirected to `logs/ue1_stdout.txt`.
  - To operate multiple UEs, execute `./run.sh <N>` or `./run_background.sh <N>`, where `<N>` is the identifying number of the UE.
- **Stop the UE**: Terminate the UE with `./stop.sh`.
  - To stop an individual UE, use `./stop.sh <N>`.
- **Status**: Check running UEs with `./is_running.sh`. The output will display which UEs are running.
- **Logs**: Access logs by navigating to the `logs` directory.

## Multiple UEs
The `run.sh`, `run_background.sh` and `stop.sh` scripts can be given an optional `<N>` argument (default: 1) to specify which UE to run or stop. Each UE is assigned the following unique parameters:
- IMEI
- IMSI
- Key
- TX Port
- RX Port
- Network namespace

For UE 1, UE 2, and UE 3, the SIM subscriber information is pre-registered with the 5G Core Network. For `<N>` values greater than 3, the unique values are generated dynamically, registered with the 5G Core Network, and stored in the `configs` directory as their own `ue<N>.conf` file. For more information about how the unique parameters are generated, refer to the `run.sh` script.

## References
1. srsRAN 4G UE User Manual. Software Radio Systems. [https://docs.srsran.com/projects/4g/en/latest/usermanuals/source/srsue/source/index.html][srsran-srsue]

<!-- References -->

[srsran-srsue]: https://docs.srsran.com/projects/4g/en/latest/usermanuals/source/srsue/source/index.html

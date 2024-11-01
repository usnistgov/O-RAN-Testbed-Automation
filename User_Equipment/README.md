## User Equipment

The User Equipment (UE) is a simulated device based on the [srsUE][srsran-srsue] software provided by srsRAN, and is configured to connect to the gNodeB and establish a PDU session with the 5G Core Network.

## Usage
- Compile the UE with `./full_install.sh`.
- Generate the configuration files with `./generate_configurations.sh`.
  - To view or modify the configuration file(s), navigate to the `configs` directory.
- Run UE 1 with `./run.sh`, or to run it as a background process with `./run_background.sh`, where the output is redirected to `logs/ue1_stdout.txt`.
  - To run multiple UEs, use `./run.sh <N>` or `./run_background.sh <N>`.
- Stop all running UEs with `./stop.sh`.
  - To stop an individual UE, use `./stop.sh <N>`.
- Check which UEs are running with `./is_running.sh`.
- Access the log files by navigating to the `logs` directory.

## Multiple UEs

The `run.sh`, `run_background.sh` and `stop.sh` scripts can be given an optional `<N>` argument (default: 1) to specify which UE to run or stop. Each UE is assigned the following unique parameters:
- IMEI
- IMSI
- Key
- TX Port
- RX Port
- Network namespace

For UE 1, UE 2, and UE 3, the SIM subscriber information is pre-registered with the 5G Core Network. For `<N>` values greater than 3, the unique values are generated dynamically, registered with the 5G Core Network, and stored in the `configs` directory as their own `ue<N>.conf` file. For more information about how the unique parameters are generated, refer to the `run.sh` script.

<!-- References -->

[srsran-srsue]: https://docs.srsran.com/projects/4g/en/latest/usermanuals/source/srsue/source/1_ue_intro.html

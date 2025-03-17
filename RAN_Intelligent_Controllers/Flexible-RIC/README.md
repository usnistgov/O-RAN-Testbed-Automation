## Flexible RAN Intelligent Controller (FlexRIC)

The Near-RT RIC, conceptualized by the O-RAN Alliance's Working Group 3 (WG3) [[1]][oran-wg3] and implemented by Mosaic5G [[2]][publication-nearrtric][[3]][mosaic5g-nearrtric], enables dynamic management and optimization of Radio Access Networks (RAN).

## Usage

- **Compile**: Use `./full_install.sh` to build the Near-RT RIC software.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the Near-RT RIC**: Use `./run.sh` to start the Near-RT RIC application.
- **Stop the Near-RT RIC**: Terminate the Near-RT RIC with `./stop.sh`.
- **Status**: Check if the Near-RT RIC is running with `./is_running.sh`.
- **Logs**: Access logs by navigating to the `logs` directory.

## Running an xApp

This implementation of the Near-RT RIC showcases two xApps.

- **KPI Monitoring xApp (xapp_kpm_moni)**:
  - Run with `./additional_scripts/run_xapp_kpi_monitor.sh`.
- **RIC Control xApp (xapp_kpm_rc)**:
  - Run with `./additional_scripts/run_xapp_ric_control.sh`.

## References

1. Working Group 3: Near-Real-time RAN Intelligent Controller and E2 Interface Workgroup. O-RAN Alliance. [https://public.o-ran.org/display/WG3/Introduction][oran-wg3]
2. FlexRIC: an SDK for next-generation SD-RANs. R. Schmidt, M. Irazabal, N. Nikaein. [https://dl.acm.org/doi/10.1145/3485983.3494870][publication-nearrtric]
3. Flexible RAN Intelligent Controller (FlexRIC) and E2 Agent. Mosaic5G. [https://gitlab.eurecom.fr/mosaic5g/flexric][mosaic5g-nearrtric]

<!-- References -->

[oran-wg3]: https://public.o-ran.org/display/WG3/Introduction
[publication-nearrtric]: https://dl.acm.org/doi/10.1145/3485983.3494870
[mosaic5g-nearrtric]: https://gitlab.eurecom.fr/mosaic5g/flexric

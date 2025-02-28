## Near-RT RIC, K-Release

The Near-RT RIC, conceptualized by the O-RAN Alliance's Working Group 3 (WG3) [[1]][oran-wg3] and implemented by the O-RAN Software Community [[2]][oransc-nearrtric], enables dynamic management and optimization of Radio Access Networks (RAN).

This automation tool is based on the K-Release of the Near-RT RIC. More information about these releases can be found at [[3]][oransc-releases].

## Usage

- **Installation Process**: Use `./full_install.sh` to get the Near-RT RIC running on the host machine. The installation process consists of the following steps.
  - Installs Docker, Kubernetes, and Helm if not previously installed.
  - Uses Helm to install the RIC components.
  - Builds, installs, and configures the E2 Simulator (e2sim).
  - Connects the e2term pod to e2sim within the Near-RT RIC.
  - Installs and Configures the xApp manager (appmgr) to deploy a Hello World (hw-go) xApp.

- **Start the Near-RT RIC**: While the Kubernetes pods start automatically on system boot, the entire process of ensuring that the components are running, connected, and that the xApp is deployed can be re-executed with `./run.sh`.
- **Status**: Check on a pod's status with `kubectl get pods -A`, or by running the interactive pod manager (K9s) with `k9s -A` or `./start_k9s.sh`.
- **Logs**: From within K9s, use the `Arrow Keys` to highlight a pod, `Enter` to view the logs for the pod, `w` to wrap text, `Esc` to go back, `Ctrl+k` to restart a pod that isn't responding, and `s` to open a command line shell in the pod.

## Installing xApps
By default, the Hello World Go xApp (hw-go) is installed automatically. Additional xApps can be installed to extend the functionality of the Near-RT RIC. For convenience, installation scripts for the following xApps are included:

- **KPI Monitoring xApp (kpimon)**:
  - Install with `./additional_scripts/install_xapp_kpi_monitor.sh`.
  - More information can be found in the documentation [[4]][kpimon-go-docs] and code [[5]][kpimon-go-code].
  - For information about using the KPI monitor, please refer to [[6]][abdul-kpimon-go].
- **5G Cell Anomaly Detection xApp (ad-cell)**:
  - Install with `./additional_scripts/install_xapp_5g_cell_anomaly_detection.sh`.
  - More information can be found in the documentation [[7]][ad-cell-docs] and code [[8]][ad-cell-code].
- **Anomaly Detection xApp (ad)**:
  - Install with `./additional_scripts/install_xapp_anomaly_detection.sh`.
  - More information can be found in the documentation [[9]][ad-docs] and code [[10]][ad-code].
- **Hello World Python xApp (hw-python)**:
  - Install with `./additional_scripts/install_xapp_hw-python.sh`.
  - More information can be found in the code [[11]][hw-python-code].
- **Hello World Rust xApp (hw-rust)**:
  - Install with `./additional_scripts/install_xapp_hw-rust.sh`.
  - More information can be found in the code [[12]][hw-rust-code].
- **Quality of Experience Predictor xApp (qp)**:
  - Install with `./additional_scripts/install_xapp_qoe_predictor.sh`.
  - More information can be found in the documentation [[13]][qp-docs] and code [[14]][qp-code].
- **RIC Control xApp (rc)**:
  - Install with `./additional_scripts/install_xapp_ric_control.sh`.
  - More information can be found in the documentation [[15]][rc-docs] and code [[16]][rc-code].
- **Traffic Steering xApp (trafficxapp)**:
  - Install with `./additional_scripts/install_xapp_traffic_steering.sh`.
  - More information can be found in the documentation [[17]][trafficxapp-docs] and code [[18]][trafficxapp-code].

## References

1. Working Group 3: Near-Real-time RAN Intelligent Controller and E2 Interface Workgroup. O-RAN Alliance. [https://public.o-ran.org/display/WG3/Introduction][oran-wg3]
2. Near Realtime RAN Intelligent Controller. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/projects.html#near-realtime-ran-intelligent-controller-ric][oransc-nearrtric]
3. Release Notes. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/release-notes.html][oransc-releases]
4. KPI Monitoring xApp documentation. O-RAN Software Community. [https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-kpimon/en/latest/overview.html][kpimon-go-docs]
5. KPI Monitoring xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-kpimon-go][kpimon-go-code]
6. Install KPI Monitoring & xApp RIC. Abdul Fikih Kurnia. [https://hackmd.io/@abdfikih/BkIeoH9D0][abdul-kpimon-go]
7. 5G Cell AD xApp documentation. O-RAN Software Community. [https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ad/en/latest/overview.html][ad-cell-docs]
8. 5G Cell AD xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-ad-cell][ad-cell-code]
9. AD xApp documentation. O-RAN Software Community. [https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ad/en/latest/overview.html][ad-docs]
10. AD xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-ad][ad-code]
11. HW Python xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-hw-python][hw-python-code]
12. HW Rust xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-hw-rust][hw-rust-code]
13. QoE Predictor xApp documentation. O-RAN Software Community. [https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-qp/en/latest/overview.html][qp-docs]
14. QoE Predictor xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-qp][qp-code]
15. RIC Control xApp documentation. O-RAN Software Community. [https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-rc/en/latest/overview.html][rc-docs]
16. RIC Control xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-rc][rc-code]
17. Traffic Steering xApp documentation. O-RAN Software Community. [https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ts/en/latest/user-guide.html][trafficxapp-docs]
18. Traffic Steering xApp project page. O-RAN Software Community. [https://github.com/o-ran-sc/ric-app-ts][trafficxapp-code]

<!-- References -->

[oran-wg3]: https://public.o-ran.org/display/WG3/Introduction
[oransc-nearrtric]: https://docs.o-ran-sc.org/en/latest/projects.html#near-realtime-ran-intelligent-controller-ric
[oransc-releases]: https://docs.o-ran-sc.org/en/latest/release-notes.html
[kpimon-go-code]: https://github.com/o-ran-sc/ric-app-kpimon-go
[kpimon-go-docs]: https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-kpimon/en/latest/overview.html
[abdul-kpimon-go]: https://hackmd.io/@abdfikih/BkIeoH9D0
[ad-cell-code]: https://github.com/o-ran-sc/ric-app-ad-cell
[ad-cell-docs]: https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ad/en/latest/overview.html
[ad-code]: https://github.com/o-ran-sc/ric-app-ad
[ad-docs]: https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ad/en/latest/overview.html
[hw-python-code]: https://github.com/o-ran-sc/ric-app-hw-python
[hw-rust-code]: https://github.com/o-ran-sc/ric-app-hw-rust
[qp-code]: https://github.com/o-ran-sc/ric-app-qp
[qp-docs]: https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-qp/en/latest/overview.html
[rc-code]: https://github.com/o-ran-sc/ric-app-rc
[rc-docs]: https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-rc/en/latest/overview.html
[trafficxapp-code]: https://github.com/o-ran-sc/ric-app-ts
[trafficxapp-docs]: https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ts/en/latest/user-guide.html

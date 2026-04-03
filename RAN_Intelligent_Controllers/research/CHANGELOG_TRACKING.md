## Changelog for v1.7.0: OCUDU Integration

### Next Generation Node B
- Switched gNodeB implementation from srsRAN_Project 25.10 to OCUDU 26.04 [\[1\]][ocudu-announcement].
  - As the continuation of srsRAN_Project, OCUDU offers a high-performance open-source O-CU and O-DU [\[2\]][ocudu], [\[3\]][ocudu-docs].
  - Integrated ZeroMQ Broker for concurrent UE connections; default scenario now starts three UEs [\[4\]][ocudu-multi-ue].
  - Added support for OCUDU's O1 interface for configuration management and performance monitoring [\[5\]][ocudu-o1-adapter].
  - Added Grafana dashboard for OCUDU metrics monitoring and visualization [\[6\]][ocudu-grafana].
  - See the Next_Generation_Node_B documentation for configuration details [\[7\]][automation-ocudu].

### User Equipment
- OpenAirInterface: Fixed UE synchronization and handover issues by shifting DU PBCH and SIB1 in the time domain [\[8\]][oai-handover-tutorial].
  - Added script `check_rrc_state.sh` to check the current RRC state from the gNodeB.
- SRS UE: Updated network namespace setup to be the same as OpenAirInterface namespaces for concurrent instances.
- SRS UE: Improved build idempotence by checking for existing ZeroMQ installations.
- SRS UE, OpenAirInterface: Fixed fetching of core address for 5gdeploy when simulating traffic to the core.
- OpenAirInterface, OCUDU, SRS UE: Updated DU/UE network namespace IP allocation for clarity and consistency.
- OpenAirInterface, OCUDU, SRS UE: Improved idempotence of network namespace setup and cleanup.

### 5G Core Network
- 5gdeploy: Fixed race condition by waiting for all subscribers to be added to database before proceeding with other components.
- 5gdeploy: Enabled UE slicing to correctly transmit S-NSSAI (SD=FFFFFF), fixing PDU session failures with free5GC NSSF.
- 5gdeploy: Patched OAI database to allow multiple SDs per UE for custom network slice configurations.
- 5gdeploy: Added option to toggle resetting `orantestbed` scenario upon generating configurations.
- Open5GS: More efficient Open5GS install/uninstall, and fixed a segfault by using `meson` via `pip3` instead of `apt`.
- Open5GS: Enabled Position-Independent Code (PIC) in Open5GS builds for shared library support.
- Open5GS: Enabled `pipefail` for Open5GS WebUI installer and uninstaller scripts.

### RAN Intelligence Controllers
- FlexRIC: Migrated xApps to utilize the new NRCellDU-level distribution metric `CARR.PDSCHMCSDist.BinX.BinY.BinZ (PDSCH_RBs)`.
- FlexRIC: Added script to interact with the InfluxDB database from the KPM monitor xApp.
- FlexRIC: Fixed E2 identification in KPM monitoring xApps for improved RAN controller messaging.
- O-RAN SC: Moved backup J, K, and L release `commit_hashes.json` files to their respective directories.
- O-RAN SC Near-RT RIC: To prevent hanging gNodeB, added detection of unhealthy/inaccessible E2 termination.
- O-RAN SC Near-RT RIC: Restored deprecated `pkg_resources` from `setuptools` for the DMS CLI.
- O-RAN SC Non-RT RIC: Fixed ChartMuseum registration to improve Non-RT RIC installation reliability.

### General
- Instead of HTTPS, added optional SSH support for `git clone` (enable with `export USE_GIT_SSH=true`).
- Made `IP_ADDRESS` fetching consistent and added a toggle for code patching (`APPLY_PATCHES=true`).
- Enhanced error handling and coverage in dependency download scripts (`Additional_Scripts/`).
- Added optional Node Version Manager (`nvm`) support for consistent Node.js versioning.
- When stopping an application, used square brackets to prevent self-matching.
- Normalized and cleaned up usage of sudo pre-authentication across scripts.
- Fixed file permissions when `$SUDO_USER` is set and differs from `$USER`.
- Fixed exit trap loop behavior to not persist when cancelled by the user.
- Improved cleanup of directories and added dependency removal scripts in `Additional_Scripts/`.
- Updated software commit hashes to the latest versions; additional tweaks and improvements.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.6.0...v1.7.0

### References

1. The srsRAN Project journey continues as OCUDU. GitHub. [https://github.com/srsran/srsRAN_Project/discussions/1470][ocudu-announcement]
2. Open-Centralized-Unit-Distributed-Unit (OCUDU). OCUDU. [https://ocudu.org/][ocudu]
3. OCUDU Documentation. GitLab Pages. [https://ocudu.gitlab.io/ocudu_docs][ocudu-docs]
4. OCUDU Multi-UE Emulation Tutorial. GitLab Pages. [https://ocudu.gitlab.io/ocudu_docs/user_manual/tutorials/srsue/#multi-ue-emulation][ocudu-multi-ue]
5. OCUDU O1 Adapter [https://ocudu.gitlab.io/ocudu_docs/oran_apps/ocudu_o1_adapter/][ocudu-o1-adapter]
6. OCUDU Grafana Dashboard WebUI. NIST. [https://github.com/usnistgov/O-RAN-Testbed-Automation/tree/main/Next_Generation_Node_B#ocudu-grafana-webui][ocudu-grafana]
7. O-RAN-Testbed-Automation, gNodeB Documentation. NIST. [https://github.com/usnistgov/O-RAN-Testbed-Automation/blob/main/Next_Generation_Node_B/README.md][automation-ocudu]
8. Handover Tutorial for OAI. OpenAirInterface. [https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/0ba31c0f89dd3162c7d87142da2b0f4e08abeb58/doc/handover-tutorial.md#run-the-setup:~:text=DU0%20and%20DU1%20should%20use%20different%20SSBs][oai-handover-tutorial]

<!-- References -->

[ocudu-announcement]: https://github.com/srsran/srsRAN_Project/discussions/1470
[ocudu]: https://ocudu.org/
[ocudu-docs]: https://ocudu.gitlab.io/ocudu_docs
[ocudu-multi-ue]: https://ocudu.gitlab.io/ocudu_docs/user_manual/tutorials/srsue/#multi-ue-emulation
[ocudu-o1-adapter]: https://ocudu.gitlab.io/ocudu_docs/oran_apps/ocudu_o1_adapter/
[ocudu-grafana]: https://github.com/usnistgov/O-RAN-Testbed-Automation/tree/main/Next_Generation_Node_B#ocudu-grafana-webui
[automation-ocudu]: https://github.com/usnistgov/O-RAN-Testbed-Automation/blob/main/Next_Generation_Node_B/README.md
[oai-handover-tutorial]: https://gitlab.eurecom.fr/oai/openairinterface5g/-/blob/0ba31c0f89dd3162c7d87142da2b0f4e08abeb58/doc/handover-tutorial.md#run-the-setup:~:text=DU0%20and%20DU1%20should%20use%20different%20SSBs





============= PREVIOUS CHANGELOGS BELOW =============


## Changelog for v1.6.0

### OpenAirInterface

- Migrated to latest configuration style and usage instructions (e.g., multiple RF simulator front ends).
- Added support for physical-layer visualization and IQ sample extraction with ImScope `nrscope`.
  - For more information, see [OpenAirInterface_Testbed/Next_Generation_Node_B](https://github.com/usnistgov/O-RAN-Testbed-Automation/blob/main/OpenAirInterface_Testbed/Next_Generation_Node_B/README.md#imscope).
- Handover scenario supports arbitrary number of DUs via `--num-dus [N]`, and optional component toggling.
- Revised the UE and DU network namespace allocation scripts for clarity and readability.
- Added option to share gNodeB's dynamically-cloned `flexric/` repository with the FlexRIC testbed component.
- Added option to disable sharing `openairinterface5g/` repository between gNodeB and UE when on same system.
- Added option to configure E2 termination port.
- Updated FlexRIC and xApps; fixed InfluxDB installation for the KPM monitoring xApp.
- Added option to configure SST and SD for the FlexRIC KPM RC xApp.

### O-RAN SC Near- and Non-RT RICs

- Upgraded software repositories to the latest M-Release.
- Improved installation process of SMO and Non-RT RIC components.
- Added non-systemd installation option for Kubernetes deployments.
- Fixed ability to specify an alternative E2 termination port.
- Removed image caching from xApp uninstaller to enforce pulling clean images.
  - Added `commit_hashes_l_release.json` for O-RAN SC L-Release backward compatibility.

### 5G Core Network

- Network slicing (S-NSSAI) is now a list of slices that are applied to subscribers.
- Added non-systemd option across core components to support background processes in place of `systemctl` services.
- Improved robustness of MongoDB and WebUI installation scripts.

### General

- Added confirmation dialog before installing the srsRAN-based and OpenAirInterface-based testbeds.
- Improved Docker and Kubernetes installation and uninstallation across environments.
- Added optional non-systemd execution mode for Docker-based deployments.
- Made SCTP management consistent across components.
- File ownership no longer assumes user group; only based on username.
- Stop scripts recover if the terminal gets broken.
- Updated software dependency commit hashes, migrating srsRAN_Project configs to latest format.
- Additional minor improvements to documentation, diagrams, and source code.

### Issues Resolved
- Resolved issue #8: Clarification about GPU and CPU support. 
  - Thanks to @HeeJaeMon123 and @Icelab-2020 for the suggestion.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.5.0...v1.6.0

## Changelog for v1.5.0

- Added modular core network support via USNISTGOV/5gdeploy [\[1\]][5gdeploy-nist].
  - Supported cores: Open5GS [\[2\]][open5gs-open5gs], OAI CN5G [\[3\]][oaicore-oai], free5GC [\[4\]][free5gc-free5gc], and Open5GCore [\[5\]][open5gcore-phoenix].
  - Supported disaggregated UPF implementations: Open5GS UPF [\[2\]][open5gs-open5gs], free5GC UPF [\[4\]][free5gc-free5gc], Open5GCore UPF [\[5\]][open5gcore-phoenix], eUPF [\[6\]][eupf-edgecomllc], OAI UPF [\[7\]][upf-oai], OAI VPP UPF [\[8\]][upf-vpp-oai], SD-Core BESS [\[9\]][bess-aethercore], and NDN-DPDK [\[10\]][nist-ndndpdk].
  - For details, see the `Additional_Cores_5GDeploy/` directory and the 5gdeploy GitHub repository [\[1\]][5gdeploy-nist].
- Added ability to run split OpenAirInterface CU-DU deployments with support for an arbitrary number of DUs.
- Added scenario automation for F1 handover of a UE between multiple DUs in the OpenAirInterface testbed.
- Added optional interactive telnet support to the OpenAirInterface gNodeB and CU installation scripts.
- Added automatic configuration generation for the O1 adapter connecting to OpenAirInterface gNodeB.
- Fixed SCTP module loaders to properly handle kernels with built-in `nf_conntrack_sctp` (e.g., `lowlatency` kernels).
- Improved support for UE-to-core and core-to-UE traffic generators when using cores beyond Open5GS.
- FlexRIC KPM: Added E2SM-KPM support for custom slicing (1-octet if SD=0xFFFFFF, otherwise 4-octets, SST+SD) [\[11\]][e2smkpm-oran].
- KPM with Grafana: Added support for serving and visualizing CSV files beyond `KPI_Metrics.csv` for better organization.
- Fixed Open5GS subscriber generation to assign correct static IP and slice SST+SD when using over three RFsim UEs.
- srsRAN gNB: Improved configs to maintain UE sessions for up to two hours of inactivity and synced with latest version.
- Updated all software commit hashes and configuration files to ensure compatibility with the most recent versions.
- Revised documentation, diagrams, and source code to reflect the changes listed above.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.4.5...v1.5.0

### References

1. Junxiao Shi (2025), 5gdeploy: 5G Core Deployment Helper, National Institute of Standards and Technology. [https://github.com/usnistgov/5gdeploy][5gdeploy-nist]
2. Open Source implementation for 5G Core and EPC. Open5GS. [https://open5gs.org][open5gs-open5gs]
3. 5G Core Network. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g][oaicore-oai]
4. Open Source 5G Core Network based on 3GPP R15. Free5GC. [https://github.com/free5gc/free5gc][free5gc-free5gc]
5. Open5GCore - 5G Core Network for Research, Testbeds and Trials. Open5GCore. [https://www.open5gcore.org][open5gcore-phoenix]
6. 5G User Plane Function (UPF) based on eBPF. edgecomllc. [https://github.com/edgecomllc/eupf][eupf-edgecomllc]
7. An eBPF implementation of the User Plane Function. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf][upf-oai]
8. OpenAir CN 5G for UPF - Using a VPP implementation. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp][upf-vpp-oai]
9. Open Source Cloud Native Mobile Core. Aether SD-Core. [https://github.com/omec-project/bess][bess-aethercore]
10. Shi, J., Pesavento, D. and Benmohamed, L. (2020), NDN-DPDK: NDN Forwarding at 100 Gbps on Commodity Hardware, 7th ACM Conference on Information-Centric Networking (ICN 2020), Montreal, CA, [online], [https://doi.org/10.1145/3405656.3418715][nist-ndndpdk], https://tsapps.nist.gov/publication/get_pdf.cfm?pub_id=930577
11. O-RAN Alliance (2025), O-RAN.WG3.E2SM-KPM-v03.00: E2 Service Model for Key Performance Measurements, Clause 8.3.11, O-RAN Alliance Technical Specification. [https://specifications.o-ran.org/download?id=810][e2smkpm-oran]


<!-- References -->

[5gdeploy-nist]: https://github.com/usnistgov/5gdeploy
[open5gs-open5gs]: https://open5gs.org
[oaicore-oai]: https://gitlab.eurecom.fr/oai/cn5g
[free5gc-free5gc]: https://github.com/free5gc/free5gc
[open5gcore-phoenix]: https://www.open5gcore.org
[eupf-edgecomllc]: https://github.com/edgecomllc/eupf
[upf-oai]: https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf
[upf-vpp-oai]: https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp
[bess-aethercore]: https://github.com/omec-project/bess
[nist-ndndpdk]: https://doi.org/10.1145/3405656.3418715
[e2smkpm-oran]: https://specifications.o-ran.org/download?id=810

## Changelog for v1.4.5

- Updated Open5GS subscriptions to use static UE addressing, e.g., UE 1 consistently receives 10.45.0.101.
  - Subnet is configurable by updating `ogstun_ipv4` or `ogstun_ipv6` in 5G_Core_Network/options.yaml.
- Made loading of SCTP modules consistent for N2 (gNB <-> core) and E2 (gNB <-> Near-RT RIC) interfaces.
- Corrected O-RAN SC Non-RT RIC control panel release version to be compatible with Non-RT RIC gateway.
- Fixed Kubernetes installation of O-RAN SC RICs by changing Content Delivery Network from _baltocdn_ to _buildkite_.
- Upgraded `yq` expression syntax to version v4.47.2, and pinned yq version to avoid incompatibilities.
- Revised expressions using `jq` to handle input argument URIs safely using `--arg`.
- Improved robustness of `apt-get` installations across systems by using `env` to pass variables.
- Improved handling of script paths including prevention of globbing when echoing script paths.
- To align with latest software versions, updated system requirements for installing every testbed component.
- Improved documentation clarity and consistency across scripts.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.4.4...v1.4.5

## Changelog for v1.4.4

- Improved automation by adding flags to `apt-get install` to prevent automatic service restarts and suppress interactive prompts.
- Added 5G core option to avoid `systemctl` and instead use background processes for better containerization support.
- Improved lifecycle management of 5G core components and accessibility of mongodb database configurations.
- Updated UE IMSI generation algorithm to avoid collisions when the number of UEs is greater than twelve.
- Fixed configuration of srsRAN_Project for network slicing support when Slice Differentiator is not 0xFFFFFF.
- Improved error handling and robustness of Kubernetes and Helm installations for O-RAN SC Near/Non-RT RICs.
- Added input argument to FlexRIC KPM monitor to CSV xApp for the measurement periodicity (_default: 1000 ms_).
- Improved debugging capabilities by adding GNU debugger scripts for FlexRIC and the FlexRIC xApps.
- Fixed KPM measurement offset by one indication for the metrics collected in OpenAirInterface gNB.
- Improved patch logic of OpenAirInterface components to ensure backup files remain unpatched.
- Cleaned up redundancy and improved general organization, management, and documentation.

### Issues Resolved
- Resolved issue #6: Added checks to ensure that the correct `yq` is being used.
- Resolved issue #5: Don't reset iptables by default on O-RAN SC RIC installation.
  - Thanks to @The1andOnlyZeRo for finding both of these issues.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.4.3...v1.4.4

## Changelog for v1.4.3

- Updated O-RAN SC repositories to [L Release](https://docs.o-ran-sc.org/en/latest/release-notes.html#version-history), OpenAirInterface repositories to [release v2.3.0](https://gitlab.eurecom.fr/oai/openairinterface5g/-/releases/v2.3.0), srsRAN_Project to [release v25.04](https://github.com/srsran/srsRAN_Project/releases/tag/release_25_04), and other testbed components' commit hashes to their latest versions.
  - Updated Docker, Kubernetes, and Helm versions for O-RAN SC's Near-RT RIC and Non-RT RIC.
- Added support for network slice customization: Single Network Slice Selection Assistance Information (S-NSSAI) consisting of SST and SD ([3GPP 23.003 §28.4.2](https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=729)) and each RAN component use a slice (_default: SST=1, SD=FFFFFF_).
- Revised testbed to use DNN/APN of "nist-dnn" by default (can be changed in `5G_Core_Network/options.yaml`).
  - 5G_Core_Network/options.yaml now supports new parameters: `dnn`, `sst`, and `sd`.
- Added script to list the subscribers stored in the core's database: `5G_Core_Network/list_subscribers.sh`.
- Refactored all UE subscriber information generators into a single script for more straightforward customization: `User_Equipment/ue_credentials_generator.sh`.
- Added custom channel models to RFSim configurations shared between the OpenAirInterface gNB and UEs.
- Added `run_gdb.sh` for OAI UE and gNB. They are functionally equivalent to `run.sh` but run within GNU Debugger.
- Improved verbosity of outputs when generating a UE config file to help with debugging its subscription with the core.
- Added scripts to open a shell inside the UE, generate UE traffic to the core, and generate core traffic to the UE.
- Improved memory safety of xApps and resolved all compiler warnings from OpenAirInterface compilations.
- Split OpenAirInterface ongoing development of E2SM-KPM into a development branch.
- Added scripts for interactive Docker (lazydocker) for easier management of e2sim in O-RAN SC's Near-RT RIC.
- Enabled Istio sidecar injection on O-RAN SC's SMO/Non-RT RIC namespace.
- All scripts that open a web browser now use the system's default browser instead of hardcoded browser support.
- Updated documentation and diagrams, and made minor script revisions to improve organization and performance.

### Issues Resolved
- Resolved issue #2: Disabled E2 for srsRAN's CU-CP so that the KPI Monitor stops crashing (still connects to the DU).
- Fixed issue #3: OAI's UE now properly uses its namespace so that uplink/downlink traffic is detected by the xApp.
  - Thanks to @jnavarrog for finding both of these issues.
- Fixed issue #4: srsue crashing with incorrect tx/rx ports. Fixed by changing the example srsRAN_Project `gnb.yaml` and User_Equipment `ue1.conf` files that are used (band 3, with frequency division duplexing).
  - Thanks to @ven457 for finding this issue.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.4.2...v1.4.3

## Changelog for v1.4.2

- Added OpenAirInterface O1 adapter support for SMO/Non-RT RIC metrics logging and RAN control.
- Added sampling resolution option to Grafana dashboard and KPI_Metrics.csv server for improved scalability.
- Added periodicity input argument for xapp_kpm_moni_write_to_csv (default: 1000 ms).
- Detached OpenAirInterface RSRP calculation from gNB 1000 ms printing interval to allow xApp periods < 1000 ms.
- Added metric "Reporting Time Offset (ms)" to show deviations from expected epoch (≠0 if resources are exhausted).
- Added statistical RSRP metrics: RSRP.{_Minimum_, _Quartile1_, _Median_, _Mean_, _Quartile3_, _Maximum_}.
- Renamed KPI metric "N_RSRP_MEAS" to 'RSRP.Count' to match the above metrics.
- Fixed xApp signal handling following Mosaic5G's change to import environment variable "XAPP_DURATION".
- Added option for xApp to omit the first sample to avoid fluctuations in startup-sensitive KPI metrics on initial startup.
- Fixed patching logic to ensure that original files stay up-to-date with OpenAirInterface repositories.
- Updated E2 simulator connectivity with O-RAN SC's Near-RT RIC.
- Fixed permissions: Corrected file ownership-related issues and Docker no longer requires sudo.
- Updated all software dependency commit hashes to the latest versions.
- Additional minor tweaks and improvements.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.4.1...v1.4.2

## Changelog for v1.4.1

- Fixed handling of invalid KPI metrics (e.g., RSRP and RSSI are now logged as empty cells in KPI_Metrics.csv when NaN).
- Changed FlexRIC KPM monitor xApp sample-filtering based on invalid RSRP measurements toggleable (default: disabled).
- Fixed Near/Non-RT RICs from accessing `ric-dep` if either is already running upon installation.
- Improved robustness of O-RAN SC Near-RT RIC's E2 simulator installation and run scripts.
- Updated documentation of both Near-RT RICs to include notes about the supported metrics.
- Improved logging when interacting with testbed components (e.g., UE IDs are identified when echoing status).
- Updated all software dependency commit hashes to the latest versions.
- Updated srsRAN_Project configurations to align with the latest software version.
- Updated FlexRIC KPM monitoring xApp patches to the latest FlexRIC version's syntax and formatting.
- Cleaned up unused patch files in OpenAirInterface_Testbed.
- Adjusted NIST software disclaimers for consistency and correctness.
- Additional minor improvements to documentation, diagrams, and source code.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.4.0...v1.4.1

## Changelog for v1.4.0

### OpenAirInterface-based Components
- Scalability improvements: Grafana dashboard panels now request only their own data via optional URI parameters.
  - `from=<start_epoch>`: The starting epoch timestamp (ms) of the data being requested.
  - `to=<end_epoch>`: The ending epoch timestamp (ms) of the data being requested.
  - `filter=<metric1,metric2,…>`: List of columns (metric names) to include in the output response.
- Added units to the CSV column headers in KPM Monitor-to-CSV xApp.
- Added KPM Monitor-to-InfluxDB xApp that writes to InfluxDB v2 rather than to CSV.
- Fixed OpenAirInterface calculation of RSRP, N_RSRP_MEAS (set in OAI based on RSRP reset), RSSI, and RSRQ.
- Added new radio-layer metrics:
  - Block error rates (BLER) uplink/downlink.
  - Modulation and coding scheme indexes (MCS) uplink/downlink.
  - MAC SDU error rates uplink/downlink (calculated with OAI patch).
  - MAC SDU retransmission rates uplink/downlink (calculated with OAI patch).
- Updated Grafana dashboard layout and design to reflect the changes listed above.
- Patched type printing across all Mosaic5G FlexRIC C xApps.
- Added ability to simulate UE traffic with input args: `UE identifier`, `bandwidth`, and `flood duration`.

### O-RAN SC-based Components
- Extended supplemental features from Near-RT RIC to Non-RT RIC (e.g., Cilium, Hubble UI, and Wireshark logging functionalities).
- Added script to install just A1 simulators to simulate Near-RT RIC behavior across six RICs of varying A1 versions.
- Fixed bug where Non-RT RIC tests would fail after uninstalling and reinstalling the Non-RT RIC.
- Improved robustness of RIC installers and updated their documentation.
- Removed the control panel's dependence on the Non-RT RIC for installation modularity.
- Corrected dependencies for backward compatibility with O-RAN SC J-Release.

### Additional Changes
- Fixed Open5GS WebUI script so that Grafana and WebUI ports do not collide and can run simultaneously.
- Fixed the permissions of files across the automation tool (755 → 644).
- Updated commit hashes, screenshots, diagrams, and documentation.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.3.0...v1.4.0

## Changelog for v1.3.2
- Near-RT RIC: Added scripts to migrate cluster from Flannel to Cilium, and added Cilium Hubble logging/visualization.
- Upgraded RIC dependencies: Kubernetes to 1.32._X_, Kubernetes CNI to 1.5._X_, Helm to 3.17._X_, and Docker to 28.0._X_. 
- Open5GS: Added `unregister_all_subscribers.sh` to simplify clearing the subscriber database.
- Open5GS: Added new parameters to options.yaml:
  - Customizing the UE-to-UPF tunnel subnet IPs.
  - Support for 6-digit PLMNs instead of just 5-digit values.
  - Exposing the AMF over hostname instead of 127.0.0.5.
  - Toggling Security Edge Protection Proxies (SEPP1 & SEPP2).
- Fixed User Equipment stop script logic when specifying individual UE IDs.
- Added "Documentation" section to the main directory that lists the link to each README.md file.
- Added diagram of supported/not supported component connectivity to main README.md.
- Cleaned up documentation, installation scripts, and configuration generation.
- Fixed issue #1: Inaccessible database to Kubernetes nodes when hostname contains capital letters. Also made InfluxDB installation optional.
  - Thanks to @The1andOnlyZeRo for finding this.

### OpenAirInterface Testbed Changelog
- FlexRIC: Added Grafana dashboard user interface to visualize xApp KPI metrics, and updated documentation with instructions.
  - Created another KPI monitor xApp that directs metrics to `logs/KPI_Metrics.csv` rather than printing to the console.
  - Patched KPI monitor to run indefinitely rather than stopping after 10 seconds.
  - Added some testing KPI metrics to OAI, FlexRIC, and the dashboard.
- Added support for multiple UEs connecting to gNB simultaneously sending data and metrics over E2.
  - Each UE is given its own network namespace similar to how SRS software supports multiple UEs.
- Added User Equipment additional scripts to open a UE shell and simulate UE traffic using iperf.
- To stop all testbed components gracefully, added an on-exit listener to run.sh script.
- Included documentation to enable AVX2 instruction set for OpenAirInterface installation.
  - Adds full support for Ubuntu 20.04 as well as Linux Mint 20, 21, and 22.
- Added toggleable `CLEAN_INSTALL` options at the beginning of install scripts.
- Updated documentation with the changes listed above.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.3.1...v1.3.2

## Changelog for v1.3.1
- Fixed configuration files of Open5GS, srsRAN gNodeB, and OpenAirInterface components.
- Added enforcement to use GCC 13 for Open5GS, srsRAN_Project, and srsRAN_4G.
  - Enabled Ubuntu 20.04 machines to use the latest srsRAN_Project updates.
- Added `full_uninstall.sh` scripts to each testbed software component.
- Patched OpenAirInterface and FlexRIC to support RSRP for KPI monitor xApp.
- Cleaned up code, configs, and minimized usage of sudo.
- Revised presentation/documentation.
  - Added overview of supported testbed open-source components.
  - Improved descriptions of OpenAirInterface with FlexRIC deployment scenario.
  - Diagrams and images now inherit dark/light mode of the host system.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.3.0...v1.3.1

## Changelog for v1.3.0
- Added support for OpenAirInterface Testbed with FlexRIC (_see subsection_).
- Fixed all xApps that read from InfluxDB and fixed KPI monitor's writing to InfluxDB.
  - Patched Anomaly Detection and Quality of Experience Predictor xApps to use InfluxDB version 2._X_ syntax instead of InfluxDB 1._X_ syntax.
- Patched KPI monitor to fix crashing when connecting to srsRAN DU, srsRAN CU-CP, and O-RAN SC E2 simulator.
- Improved InfluxDB client shell script usage and robustness when querying KPI metrics.
- Updated xApp installers to use docker image registry `127.0.0.1:80` instead of `example.com:80`.
- Added xApp uninstallation script: `additional_scripts/uninstall_an_xapp.sh`.
- Added O-RAN SC Near-RT RIC uninstallation script:  `additional_scripts/full_uninstall.sh`.
- Updated srsRAN_Project config to use the correct number of threads when `$(nproc) ≤ 3`.
- Updated commit hashes, and updated documentation to reflect the changes listed above.

### Added support for OpenAirInterface Testbed with FlexRIC
- Added additional testbed installation under the `OpenAirInterface_Testbed` directory. Includes the following components:
  - Install scripts for OpenAirInterface gNodeB and OpenAirInterface 5G User Equipment.
  - Install scripts for Mosaic5G's Near-RT RIC (FlexRIC) and its respective xApps.
  - Symbolic link to pre-existing 5G_Core_Network directory.
 - Operation of this testbed is the same as the NIST TN 2311 blueprint, e.g., same interfaces: `full_install.sh`, `generate_configurations.sh`, `run.sh`, `is_running.sh`, `stop.sh`. For more information see the [OpenAirInterface_Testbed](https://github.com/usnistgov/O-RAN-Testbed-Automation/tree/main/OpenAirInterface_Testbed) directory.

###
**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.2.0...v1.3.0

## Changelog for v1.2.4
- Fixed race condition by waiting for the AMF to register NFs in `run.sh` to ensure UE: `RRC NR reconfiguration successful`.
- Added patches to e2sim improving its reliability and enabling support for KPI metrics to be sent to the KPI monitor.
- Mounted kpm_sim logs/e2sim_output.txt to oransim Docker container to dynamically update logs even when a shell isn't linked to it.
- Added InfluxDB token generation, stored in `influxdb_auth_token.json`.
- Added graceful stopping of all components (rather than just the UE) upon exiting `run.sh`.
- Added dynamic clearing of 5G core logs before starting new instance of each core component.
- Fixed RAN Function ID synchronization in the Near-RT RIC for KPI monitoring.
- Decreased InfluxDB size from 50Gi to 2Gi.
- Fixed permissions of shell script files for consistency.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.2.3...v1.2.4

## Changelog for v1.2.3
- Upgraded Near-RT RIC to the K-Release. To continue using the J-Release, rename `commit_hashes_j_release.json` to `commit_hashes.json`.
- Added optional installation scripts for 8 additional Near-RT RIC xApps in directory additional_scripts:
  - xApp Key Performance Indicator (KPI) monitoring ([kpimon](https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-kpimon/en/latest/overview.html)) installation script (`install_xapp_kpi_monitor.sh`).
  - xApp Anamoly Detection ([ad](https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ad/en/latest/overview.html)) installation script (`install_xapp_anomaly_detection.sh`).
  - xApp 5G Cell Anamoly Detection ([ad-cell](https://github.com/o-ran-sc/ric-app-ad-cell)) installation script (`install_xapp_5g_cell_anomaly_detection.sh`).
  - xApp Quality of Experience (QoE) Predictor ([qp](https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-qp/en/latest/overview.html)) installation script (`install_xapp_qoe_predictor.sh`).
  - xApp RIC Control ([rc](https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-rc/en/latest/overview.html)) installation script (`install_xapp_ric_control.sh`).
  - xApp Traffic Steering ([trafficxapp](https://docs.o-ran-sc.org/projects/o-ran-sc-ric-app-ts/en/latest/user-guide.html)) installation script (`install_xapp_traffic_steering.sh`).
  - xApp Hello World Python ([hw-python](https://github.com/o-ran-sc/ric-app-hw-python)) installation script (`install_xapp_hw-python.sh`).
  - xApp Hello World Rust ([hw-rust](https://github.com/o-ran-sc/ric-app-hw-rust)) installation script (`install_xapp_hw-rust.sh`).
- Improvements to E2 Simulator and additional controller scripts for testing xApps over E2.
- Added InfluxDB pod used by KPI Monitor to write metrics to the influxdb/ directory.
- Added Kubernetes Redis database client script to interact with the database.
- Added Kong database bootstrapping to Non-RT RIC pod wait script.
- Updated software dependency commit hashes, migrating srsRAN_Project configs to latest format.
- Cleaned up code, updated documentation, and improved consistency across scripts.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.2.2...v1.2.3

## Changelog for v1.2.2
- Improved support for SELinux environments by using dynamic DNS addresses from /run/systemd/resolve/resolv.conf instead of 8.8.8.8.
- Migrated from docker.io to docker.ce for compatibility (docker.io can be re-enabled with `USE_DOCKER_CE=0` in install_k8s_and_helm.sh).
- Restored download_dependency_repositories.bat and added Windows batch file generator for the script.
- Improved Open5GS configuration robustness, and tweaked configuration files of UE and gNodeB.
- Added suppression of interactive prompts when installing testbed on Vagrant and VMware.
- Fixed commit hash update script and updated software hashes.
- Cleaned up optional unused components.
- Improved documentation clarity, and consistency across scripts.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.2.1...v1.2.2

## Changelog for v1.2.1
- Non-RT RIC uses Release K. Added configuration to all sample rApps syncing their URIs with Policy Management Service (PMS) and Information Coordination Service (ICS) Producer/Consumer API addresses.
- Enabled Kong and Service Manager deployment with added Kong storage class initialization of schema/configs.
- Added configuration of Control Panel to enable A1-Policy and A1-EI management functionality.
- Added flags `-y`, `--yes`, `-n`, and `--no` to all user prompts for simpler script automation.
- Updated repository commit hashes to use the latest software versions.
- Improved documentation clarity, and consistency across scripts.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.2.0...v1.2.1

## Changelog for v1.2.0
- Dependencies are now pinned in `commit_hashes.json` so that all `git clone` commands only depend on stable and tested commits.
- Script `download_dependency_repositories.sh` now also uses `git_clone.sh` for pinned dependencies.
- 5G_Core configuration file generators refactored, now using `yq` for YAML modifications.
- Updated srsRAN_Project and srsRAN_4G configurations to support the latest releases.
- Added sample rApp CSAR generation script in Non-RT RIC installation.
- Improved documentation clarity, and consistency across scripts.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.1.0...v1.2.0

## Changelog for v1.0.1 and v1.1.0
- Added Non-RT RIC installation scripts.
- Disabled `r4-infrastructure-kong` pod installation in Near-RT RIC.
- Improved stdout installation messages for Near-RT RIC.
- Set file limit descriptors automatically when installing RICs.
- Improved documentation clarity, and consistency across scripts.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/compare/v1.0.0...v1.1.0

## Changelog for v1.0.0
- Pushed initial automation tool prototype.

**Full Changelog**: https://github.com/usnistgov/O-RAN-Testbed-Automation/commits/v1.0.0
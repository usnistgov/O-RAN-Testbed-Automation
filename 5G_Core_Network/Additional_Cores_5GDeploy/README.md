## 5G Core Network

The 5G Core Network operates as a standalone network based on the 3GPP specifications TS 23.501 [\[1\]][ts3144-3gpp] and TS 23.502 [\[2\]][ts3145-3gpp], implemented using various software stacks. The 5G Core Network consists of the Mobility Management Entity (MME), Serving Gateway Control (SGWC), Session Management Function (SMF), Access and Mobility Management Function (AMF), Serving Gateway User Plane (SGWU), User Plane Function (UPF), Home Subscriber Server (HSS), Policy Control and Charging Rules Function (PCRF), Network Repository Function (NRF), Security Capability Proxy (SCP), Security Edge Protection Proxy 1 & 2 (SEPP 1, SEPP 2), Authentication Server Function (AUSF), Unified Data Management (UDM), Policy Control Function (PCF), Network Slice Selection Function (NSSF), Binding Support Function (BSF), and Unified Data Repository (UDR).

## Usage

- **Compile**: Use `./full_install.sh` to build and install the 5G Core components.
- **Generate Configurations**: Use `./generate_configurations.sh` to create `compose` directory consisting of the scenario. It can be configured in `compose/cp-cfg/config.yaml`.
- **Start the 5G Core Network**: Use `./run.sh` to start the 5G Core components in docker.
- **Stop the Network**: Stop and remove the 5G core container instances with `./stop.sh`.
- **Status and Logs**: Check if the 5G Core is running with `./is_running.sh`. To view the logs for each component using an interactive docker manager, run `./start_lazydocker.sh`.
- **Uninstall**: Use `./full_uninstall.sh` to remove the 5G Core software.

## Supported Cores Using `USNISTGOV/5gdeploy`

These 5G Core implementations are provided through the USNISTGOV/5gdeploy 5G Core Deployment Helper [\[3\]][5gdeploy-nist]. In support for diverse software stacks, the tool allow disaggregating the Control Plane (CP) and User Plane Function (UPF) components in the 5G core network.

To select a core network beyond Open5GS, modify the `core_to_use` and `upf_to_use` fields in the ../options.yaml file. The available options are listed below.

- `core_to_use`:

  - `open5gs`: Open5GS core in the current directory (default, see [\[4\]][open5gs-open5gs]).
  - `5gdeploy-oai`: OpenAirInterface core (see [\[5\]][oaicore-oai]).
  - `5gdeploy-free5gc`: free5GC core (see [\[6\]][free5gc-free5gc]).
    - _Note: free5GC does not support gNB KPI metric subscriptions due to slicing limitations [\[7\]][free5gc-limitation]._
  - `5gdeploy-phoenix`: Phoenix core (see [\[8][open5gcore-fraunhofer-fokus], [9\]][open5gcore-phoenix]).
      - _Note: Phoenix Platform, also known as Open5GCore, requires a license to operate. See links above for more information._
  - `5gdeploy-open5gs`: Open5GS core (containerized in Docker, see [\[4\]][open5gs-open5gs]).

- `upf_to_use` (optional):
  - `null` or blank: Uses the same value as `core_to_use` (default).
  - `5gdeploy-eupf`: eUPF (see [\[10\]][eupf-edgecomllc]).
  - `5gdeploy-oai`: OpenAirInterface UPF (see [\[11\]][upf-oai]).
  - `5gdeploy-oai-vpp`: OpenAirInterface UPF (see [\[12\]][upf-vpp-oai]).
  - `5gdeploy-free5gc`: free5GC UPF (see [\[6\]][free5gc-free5gc]).
  - `5gdeploy-phoenix`: Phoenix core (license required, see [\[8][open5gcore-fraunhofer-fokus], [9\]][open5gcore-phoenix]).
  - `5gdeploy-open5gs`: Open5GS core (containerized in Docker, see [\[4\]][open5gs-open5gs]).
  - `5gdeploy-bess`: Aether SD-Core BESS UPF (see [\[13\]][bess-aethercore]).
  - `5gdeploy-ndndpdk`: NDN-DPDK UPF (see [\[14\]][nist-ndndpdk]).

Upon updating options.conf, run `generate_configurations.sh` on the core, the gNodeB, and the UE to apply changes. Please see the parent directory's README.md for more information.

## References

1. 3GPP TS 23.501: System Architecture for the 5G System. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3144][ts3144-3gpp]
2. 3GPP TS 23.502: Procedures for the 5G System. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3145][ts3145-3gpp]
3. Junxiao Shi (2025), 5gdeploy: 5G Core Deployment Helper, National Institute of Standards and Technology. [https://doi.org/10.18434/mds2-3794][5gdeploy-nist]
4. Open Source implementation for 5G Core and EPC. Open5GS. [https://open5gs.org][open5gs-open5gs]
5. 5G Core Network. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g][oaicore-oai]
6. Open Source 5G Core Network based on 3GPP R15. free5GC. [https://github.com/free5gc/free5gc][free5gc-free5gc]
7. free5GC + OAI gNB: RerouteNASRequest. [https://forum.free5gc.org/t/free5gc-oai-gnb-reroutenasrequest/2628?u=yoursunny][free5gc-limitation]
8. Open 5G Campus Networks: Key Drivers for 6G Innovations. Fraunhofer FOKUS. [https://doi.org/10.1007/s00502-022-01064-7][open5gcore-fraunhofer-fokus]
9. Open5GCore - 5G Core Network for Research, Testbeds and Trials. Open5GCore. [https://www.open5gcore.org][open5gcore-phoenix]
10. 5G User Plane Function (UPF) based on eBPF. edgecomllc. [https://github.com/edgecomllc/eupf][eupf-edgecomllc]
11. An eBPF implementation of the User Plane Function. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf][upf-oai]
12. OpenAir CN 5G for UPF - Using a VPP implementation. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp][upf-vpp-oai]
13. Open Source Cloud Native Mobile Core. Aether SD-Core. [https://github.com/omec-project/bess][bess-aethercore]
14. Shi, J., Pesavento, D. and Benmohamed, L. (2020), NDN-DPDK: NDN Forwarding at 100 Gbps on Commodity Hardware, 7th ACM Conference on Information-Centric Networking (ICN 2020), Montreal, CA, [online], [https://doi.org/10.1145/3405656.3418715][nist-ndndpdk], https://tsapps.nist.gov/publication/get_pdf.cfm?pub_id=930577

<!-- References -->

[ts3144-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3144
[ts3145-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3145
[open5gs-open5gs]: https://open5gs.org
[5gdeploy-nist]: https://doi.org/10.18434/mds2-3794
[oaicore-oai]: https://gitlab.eurecom.fr/oai/cn5g
[free5gc-free5gc]: https://github.com/free5gc/free5gc
[open5gcore-fraunhofer-fokus]: https://doi.org/10.1007/s00502-022-01064-7
[open5gcore-phoenix]: https://www.open5gcore.org
[eupf-edgecomllc]: https://github.com/edgecomllc/eupf
[upf-oai]: https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf
[upf-vpp-oai]: https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp
[free5gc-limitation]: https://forum.free5gc.org/t/free5gc-oai-gnb-reroutenasrequest/2628?u=yoursunny
[bess-aethercore]: https://github.com/omec-project/bess
[nist-ndndpdk]: https://doi.org/10.1145/3405656.3418715

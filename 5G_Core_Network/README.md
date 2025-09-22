## 5G Core Network

The 5G Core Network operates as a standalone network based on the 3GPP specifications TS 23.501 [\[1\]][ts3144-3gpp] and TS 23.502 [\[2\]][ts3145-3gpp], implemented using the Open5GS software [\[3\]][open5gs-open5gs]. The 5G Core Network consists of the Mobility Management Entity (MME), Serving Gateway Control (SGWC), Session Management Function (SMF), Access and Mobility Management Function (AMF), Serving Gateway User Plane (SGWU), User Plane Function (UPF), Home Subscriber Server (HSS), Policy Control and Charging Rules Function (PCRF), Network Repository Function (NRF), Security Capability Proxy (SCP), Security Edge Protection Proxy 1 & 2 (SEPP 1, SEPP 2), Authentication Server Function (AUSF), Unified Data Management (UDM), Policy Control Function (PCF), Network Slice Selection Function (NSSF), Binding Support Function (BSF), and Unified Data Repository (UDR).

## Usage

- **Compile**: Use `./full_install.sh` to build and install the 5G Core components.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the 5G Core Network**: Use `./run.sh` to start the 5G Core components.
  - To start each component in its own gnome-terminal instance, use `./run.sh show`.
- **Stop the Network**: Terminate the network operation with `./stop.sh`.
- **Status**: Check if the 5G Core is running with `./is_running.sh`. The output will display which components are running.
- **Logs**: Access logs by navigating to the `logs` directory.
- **Uninstall**: Use `./full_uninstall.sh` to remove the 5G Core software.

## Supported Cores Beyond Open5GS Using `USNISTGOV/5gdeploy`

Additional 5G Core implementations are provided through the USNISTGOV/5gdeploy 5G Core Deployment Helper [\[4\]][5gdeploy-nist]. In support for diverse software stacks, the tool allow disaggregating the Control Plane (CP) and User Plane Function (UPF) components in the 5G core network.

To select a core network beyond Open5GS, modify the `core_to_use` and `upf_to_use` fields in the 5G_Core_Network/options.yaml file. The available options are listed below.

- Supported values for `core_to_use`:

  - `open5gs`: Open5GS core in the current directory (default, see [\[3\]][open5gs-open5gs])
  - `5gdeploy-oai`: OpenAirInterface core (see [\[5\]][oaicore-oai])
  - `5gdeploy-free5gc`: Free5GC core (see [\[6\]][free5gc-free5gc])
  - `5gdeploy-phoenix`: Phoenix core, also known as Open5GCore (requires license to operate, see [\[7\]][open5gcore-phoenix])
  - `5gdeploy-open5gs`: Open5GS core (with the difference being that this is containerized in Docker, see [\[3\]][open5gs-open5gs])

- Supported values for `upf_to_use`:
  - `null` or blank: Uses the same value as `core_to_use` (default)
  - `5gdeploy-eupf`: eUPF (see [\[8\]][eupf-edgecomllc])
  - `5gdeploy-oai`: OpenAirInterface UPF (see [\[9\]][upf-oai])
  - `5gdeploy-oai-vpp`: OpenAirInterface UPF (see [\[10\]][upf-vpp-oai])
  - `5gdeploy-free5gc`: Free5GC UPF (see [\[7\]][free5gc-free5gc])
  - `5gdeploy-phoenix`: Phoenix core, also known as Open5GCore (requires license to operate, see [\[8\]][open5gcore-phoenix])
  - `5gdeploy-open5gs`: Open5GS core (containerized in Docker, see [\[3\]][open5gs-open5gs])
  - `5gdeploy-bess`: Aether SD-Core BESS UPF (see [\[11\]][bess-aethercore])
  - `5gdeploy-ndndpdk`: NDN-DPDK UPF (see [\[12\]][nist-ndndpdk])

> [!NOTE]
> Upon updating options.conf, run `full_install.sh` to build the new core, then in the Next_Generation_Node_B/ directory, run `generate_configurations.sh` to reconfigure the gNB with the correct AMF.

> [!TIP]
> The scripts in the 5G_Core_Network directory will change directory and run the respective 5G_Core_Network/Additional_Cores_5GDeploy script if options.yaml has `core_to_use` set to anything other than `open5gs`.

### Custom PLMN and TAC Identifiers

Modify the `5G_Core_Network/options.yaml` for different PLMN and TAC IDs, then apply changes with the following:

```console
./install_scripts/unregister_all_subscribers.sh
./generate_configurations.sh
./stop.sh
./run.sh
cd ../Next_Generation_Node_B
./generate_configurations.sh
cd ../5G_Core_Network
```

## Accessing Subscriber Data

In Open5GS, the WebUI hosts a web interface to access subscriber data. To access the WebUI, navigate to `http://localhost:9999` in a web browser, or run `start_webui.sh` to open it in the default browser.

Alternatively, to create subscriber entries from command line, use the following.

```console
./install_scripts/register_subscriber.sh --imsi 001010123456780 --key 00112233445566778899AABBCCDDEEFF --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn [--sst 1] [--sd FFFFFF]
```

Remove all registered subscribers with `./install_scripts/unregister_all_subscribers.sh`.

By default, the configuration process automatically unregisters all subscribers, then registers subscriber entries for UE 1, UE 2, and UE 3 based on the following table from the blueprint [\[13\]][nist-tn-2311]. The IMSI values will be updated accordingly if the PLMN value is changed in options.yaml.

<table><thead>
  <tr>
    <th>UE</th>
    <th>UE 1</th>
    <th>UE 2</th>
    <th>UE 3</th>
  </tr></thead>
<tbody>
  <tr>
    <td>OPc</td>
    <td colspan="3">63BFA50EE6523365FF14C1F45F88737D</td>
  </tr>
  <tr>
    <td>K</td>
    <td>00112233445566778899AABBCCDDEEFF</td>
    <td>...F00</td>
    <td>...F01</td>
  </tr>
  <tr>
    <td>IMSI</td>
    <td>001010123456780</td>
    <td>...90</td>
    <td>...91</td>
  </tr>
  <tr>
    <td>IMEI</td>
    <td>353490069873319</td>
    <td>...8</td>
    <td>...2</td>
  </tr>
  <tr>
    <td>Address</td>
    <td>10.45.0.101</td>
    <td>...102</td>
    <td>...103</td>
  </tr>
  <tr>
    <td>Namespace</td>
    <td>ue1</td>
    <td>ue2</td>
    <td>ue3</td>
  </tr>
  <!-- <tr>
    <td>TX Port</td>
    <td>2101</td>
    <td>2201</td>
    <td>2301</td>
  </tr>
  <tr>
    <td>RX Port</td>
    <td>2100</td>
    <td>2200</td>
    <td>2300</td>
  </tr> -->
</tbody>
</table>

For more information on the subscriber data, refer to the blueprint [\[13\]][nist-tn-2311] and the User_Equipment README document.

### Open5GS: Custom Gateway Address for UE Traffic

To use a custom gateway address for UE traffic, edit the `ogstun_ipv4` and `ogstun_ipv6` fields in `5G_Core_Network/options.yaml`. Default subnets are 10.45.0.0/16 (IPv4) and 2001:db8:cafe::/48 (IPv6). Gateways are set to the first address in each subnet: 10.45.0.1 and 2001:db8:cafe::1, respectively. Apply changes with `./generate_configurations.sh`.

## References

1. 3GPP TS 23.501: System Architecture for the 5G System. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3144][ts3144-3gpp]
2. 3GPP TS 23.502: Procedures for the 5G System. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3145][ts3145-3gpp]
3. Open Source implementation for 5G Core and EPC. Open5GS. [https://open5gs.org][open5gs-open5gs]
4. Junxiao Shi (2025), 5gdeploy: 5G Core Deployment Helper, National Institute of Standards and Technology. [https://doi.org/10.18434/mds2-3794][5gdeploy-nist]
5. 5G Core Network. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g][oaicore-oai]
6. Open Source 5G Core Network based on 3GPP R15. Free5GC. [https://github.com/free5gc/free5gc][free5gc-free5gc]
7. Open5GCore - 5G Core Network for Research, Testbeds and Trials. Open5GCore. [https://www.open5gcore.org][open5gcore-phoenix]
8. 5G User Plane Function (UPF) based on eBPF. edgecomllc. [https://github.com/edgecomllc/eupf][eupf-edgecomllc]
9. An eBPF implementation of the User Plane Function. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf][upf-oai]
10. OpenAir CN 5G for UPF - Using a VPP implementation. OpenAirInterface. [https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp][upf-vpp-oai]
11. Open Source Cloud Native Mobile Core. Aether SD-Core. [https://github.com/omec-project/bess][bess-aethercore]
12. Shi, J., Pesavento, D. and Benmohamed, L. (2020), NDN-DPDK: NDN Forwarding at 100 Gbps on Commodity Hardware, 7th ACM Conference on Information-Centric Networking (ICN 2020), Montreal, CA, [online], [https://doi.org/10.1145/3405656.3418715][nist-ndndpdk], https://tsapps.nist.gov/publication/get_pdf.cfm?pub_id=930577
13. Liu, Peng, Lee, Kyehwan, Cintrón, Fernando J., Wuthier, Simeon, Savaliya, Bhadresh, Montgomery, Douglas, Rouil, Richard (2024). Blueprint for Deploying 5G O-RAN Testbeds: A Guide to Using Diverse O-RAN Software Stacks. National Institute of Standards and Technology. [https://doi.org/10.6028/NIST.TN.2311][nist-tn-2311]

<!-- References -->

[ts3144-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3144
[ts3145-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3145
[open5gs-open5gs]: https://open5gs.org
[5gdeploy-nist]: https://doi.org/10.18434/mds2-3794
[oaicore-oai]: https://gitlab.eurecom.fr/oai/cn5g
[free5gc-free5gc]: https://github.com/free5gc/free5gc
[open5gcore-phoenix]: https://www.open5gcore.org
[eupf-edgecomllc]: https://github.com/edgecomllc/eupf
[upf-oai]: https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf
[upf-vpp-oai]: https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp
[bess-aethercore]: https://github.com/omec-project/bess
[nist-ndndpdk]: https://doi.org/10.1145/3405656.3418715
[nist-tn-2311]: https://doi.org/10.6028/NIST.TN.2311

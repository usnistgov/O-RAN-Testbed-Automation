## 5G Core Network

The 5G Core Network operates as a standalone network based on the 3GPP specifications TS 23.501 [[1]][ts3144-3gpp] and TS 23.502 [[2]][ts3145-3gpp], implemented using the Open5GS software [[3]][open5gs-open5gs]. The 5G Core Network consists of the Mobility Management Entity (MME), Serving Gateway Control (SGWC), Session Management Function (SMF), Access and Mobility Management Function (AMF), Serving Gateway User Plane (SGWU), User Plane Function (UPF), Home Subscriber Server (HSS), Policy Control and Charging Rules Function (PCRF), Network Repository Function (NRF), Security Capability Proxy (SCP), Security Edge Protection Proxy 1 & 2 (SEPP 1, SEPP 2), Authentication Server Function (AUSF), Unified Data Management (UDM), Policy Control Function (PCF), Network Slice Selection Function (NSSF), Binding Support Function (BSF), and Unified Data Repository (UDR).

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

By default, the configuration process automatically unregisters all subscribers, then registers subscriber entries for UE 1, UE 2, and UE 3 based on the following table from the blueprint [[4]][nist-tn-2311]. The IMSI values will be updated accordingly if the PLMN value is changed in options.yaml.

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
    <td>netns</td>
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

For more information on the subscriber data, refer to the blueprint [[4]][nist-tn-2311] and the User_Equipment README document.

### Open5GS: Custom Gateway Address for UE Traffic

To use a custom gateway address for UE traffic, edit the `ogstun_ipv4` and `ogstun_ipv6` fields in `5G_Core_Network/options.yaml`. Default subnets are 10.45.0.0/16 (IPv4) and 2001:db8:cafe::/48 (IPv6). Gateways are set to the first address in each subnet: 10.45.0.1 and 2001:db8:cafe::1, respectively. Apply changes with `./generate_configurations.sh`.

## References

1. 3GPP TS 23.501: System Architecture for the 5G System. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3144][ts3144-3gpp]
2. 3GPP TS 23.502: Procedures for the 5G System. [https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3145][ts3145-3gpp]
3. Open Source implementation for 5G Core and EPC. Open5GS. [https://open5gs.org][open5gs-open5gs]
4. Liu, Peng, Lee, Kyehwan, Cintrón, Fernando J., Wuthier, Simeon, Savaliya, Bhadresh, Montgomery, Douglas, Rouil, Richard (2024). Blueprint for Deploying 5G O-RAN Testbeds: A Guide to Using Diverse O-RAN Software Stacks. National Institute of Standards and Technology. [https://doi.org/10.6028/NIST.TN.2311][nist-tn-2311]

<!-- References -->

[ts3144-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3144
[ts3145-3gpp]: https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3145
[open5gs-open5gs]: https://open5gs.org
[nist-tn-2311]: https://doi.org/10.6028/NIST.TN.2311

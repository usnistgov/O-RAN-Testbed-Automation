## 5G Core Network

The 5G Core Network operates as a standalone network based on the 3GPP specifications TS 23.501 and TS 23.502, implemented using the Open5GS software [[1]][open5gs-open5gs].

## Usage
- **Compile**: Use `./full_install.sh` to build the 5G Core.
- **Generate Configurations**: Use `./generate_configurations.sh` to create configuration files.
  - Configuration files can be accessed and modified in the `configs` directory.
- **Start the 5G Core Network**: Use `./run.sh` to start the 5G Core components.
  - To start each component in its own gnome-terminal instance, use `./run.sh show`.
- **Stop the Network**: Terminate the network operation with `./stop.sh`.
- **Status**: Check if the 5G Core is running with `./is_running.sh`. The output will display which components are running.
- **Logs**: Access logs by navigating to the `logs` directory.

### Custom PLMN and TAC Identifiers
Modify the `5G_Core_Network/options.yaml` for different PLMN and TAC IDs, then apply changes with the following.
```console
./generate_configurations.sh
./stop.sh
./run.sh
cd ../Next_Generation_Node_B
./generate_configurations.sh
cd ../5G_Core_Network
```

## Accessing Subscriber Data
The WebUI hosts a web interface to access subscriber data. To access the WebUI, navigate to `http://localhost:9999` in a web browser, or run `start_webui.sh` to open it in Chrome or Firefox automatically.

To create subscriber entries from command line, use the following.
```console
./install_scripts/register_subscriber.sh --imsi 001010123456780 --key 00112233445566778899aabbccddeeff --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn
```

## References
1. Open Source implementation for 5G Core and EPC. Open5GS. [https://open5gs.org/][open5gs-open5gs]

<!-- References -->

[open5gs-open5gs]: https://open5gs.org

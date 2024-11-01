## 5G Core Network

The 5G Core Network is a standalone 5G network based on the architecture defined by 3GPP in TS 23.501 and TS 23.502, and is implemented using the [Open5GS][open5gs-open5gs] software.

## Usage
- Compile the 5G Core with `./full_install.sh`.
- Generate the configuration files with `./generate_configurations.sh`.
  - To view or modify the configuration files, navigate to the `configs` directory.
- Run the 5G Core with `./run.sh`.
  - To start each component in its own gnome-terminal instance, use `./run.sh show`.
- Stop the 5G Core with `./stop.sh`.
- Check if the 5G Core is running with `./is_running.sh`.
- Access the log files by navigating to the `logs` directory.

### Custom PLMN and TAC Identifiers
To select a different PLMN and TAC ID, modify the contents of `5G_Core_Network/options.yaml`, then apply the changes with:
```
./generate_configurations.sh
./stop.sh
./run.sh
cd ../Next_Generation_Node_B
./generate_configurations.sh
cd ../5G_Core_Network
```

## Accessing Subscriber Data
The WebUI hosts a web interface to access subscriber data. To access the WebUI, navigate to `http://localhost:9999` in a web browser, or run `start_webui.sh` to open Firefox at the address.

To create subscriber entries from the terminal, use the following (default values are for UE 1).
```console
./install_scripts/register_subscriber.sh --imsi 001010123456780 --key 00112233445566778899aabbccddeeff --opc 63BFA50EE6523365FF14C1F45F88737D --apn srsapn
```

<!-- References -->

[open5gs-open5gs]: https://open5gs.org/

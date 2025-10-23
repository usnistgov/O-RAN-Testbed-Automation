# Handover Support for O1 Adapter

This update adds F1 and N2 handover support to the O1 adapter, allowing O1 clients to trigger handovers on the OpenAirInterface gNB.

## Installation

### 1. Install the YANG Model

```bash
cd docker/scripts
sysrepoctl -i oai-handover.yang -v3
```

### 2. Register Handover RPCs

In your `main.c`, after initializing netconf_data:

```c
#include "netconf/netconf_data.h"

// After netconf_data_init() and netconf_data_update_full()
rc = netconf_data_register_handover_rpcs();
if (rc != 0) {
    log_error("Failed to register handover RPCs");
    goto failed;
}
```

### 3. Rebuild the Adapter

```bash
cd src
./build.sh
```

Or rebuild the Docker container:

```bash
./build-adapter.sh --adapter
```

## Usage

### Prerequisites

- gNB must be built with telnet support (default)
- gNB must be started with `--telnetsrv` flag on port 9091
- For N2 handover: neighbor cells must be configured in gNB config

### Node.js Client

Install dependencies:

```bash
npm install node-netconf
```

#### Trigger F1 Handover

```bash
O1_HOST=10.20.11.134 O1_PORT=830 \
O1_USER=netconf O1_PASS='netconf!' \
HANDOVER_TYPE=f1 \
node handover-client.js
```

Optional: specify UE with `RRC_UE_ID=1`

#### Trigger N2 Handover

```bash
O1_HOST=10.20.11.134 O1_PORT=830 \
O1_USER=netconf O1_PASS='netconf!' \
HANDOVER_TYPE=n2 NEIGHBOUR_PCI=1 UE_ID=1 \
node handover-client.js
```
### Configuration Options

Set these environment variables to control the Node.js handover client:

| Variable         | Default                           | Description                                 |
|------------------|-----------------------------------|---------------------------------------------|
| `O1_HOST`        | `127.0.0.1`                       | O1 adapter hostname or IP                   |
| `O1_PORT`        | `830`                             | NETCONF port                                |
| `O1_USER`        | `netconf`                         | NETCONF username                            |
| `O1_PASS`        | `netconf!`                        | NETCONF password                            |
| `HANDOVER_TYPE`  | `f1`                              | Handover type: `f1` or `n2`                 |
| `RRC_UE_ID`      | `-1`                              | RRC UE ID for F1 handover (`-1` = auto)     |
| `NEIGHBOUR_PCI`  | `1`                               | Target PCI for N2 handover                  |
| `UE_ID`          | `1`                               | UE ID for N2 handover                       |
| `SET_HO_ALLOWED` | `true`                            | Set `isHOAllowed` before handover           |

**Note:** By default, the client sets `isHOAllowed=true` before triggering handover for 3GPP compliance. Set `SET_HO_ALLOWED=false` to skip this if already configured.


### Using netconf-console

#### F1 Handover:

```bash
netconf-console --host=10.20.11.134 --port=830 \
  --user=netconf --password='netconf!' \
  --rpc="<trigger-f1-handover xmlns='urn:oai:params:xml:ns:yang:handover'/>"
```

#### N2 Handover:

```bash
netconf-console --host=10.20.11.134 --port=830 \
  --user=netconf --password='netconf!' \
  --rpc="<trigger-n2-handover xmlns='urn:oai:params:xml:ns:yang:handover'><neighbour-pci>1</neighbour-pci><ue-id>1</ue-id></trigger-n2-handover>"
```

## Troubleshooting

**"RPC not found"**: YANG model not installed. Verify with `sysrepoctl -l | grep oai-handover`

**"Operation failed"**: Check gNB telnet server is running, UE is connected, and (for N2) neighbor cells are configured

## Standards Compliance (3GPP TS 28.541)

This implementation uses a vendor-specific YANG module (`oai-handover`) with namespace `urn:oai:params:xml:ns:yang:handover`. It does not modify 3GPP-defined YANG modules and maintains full compliance with 3GPP TS 28.541 standards for configuration, performance, and fault management over the O1 interface.


# OCUDU gNB with Multiple Cells and UEs, RIC, and KPM Monitoring

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Testbed Components](#testbed-components)
- [Clone Repository](#clone-repository)
- [Install the Testbed](#install-the-testbed)
- [O-RAN SC Near-RT RIC with KPM xApp](#o-ran-sc-near-rt-ric-with-kpm-xapp)
  - [Start the O-RAN SC Testbed](#start-the-o-ran-sc-testbed)
  - [Install KPM Monitoring xApp](#install-kpm-monitoring-xapp)
  - [View KPI Metrics](#view-kpi-metrics)
- [FlexRIC with KPM xApp](#flexric-with-kpm-xapp)
  - [Start the Testbed](#start-the-testbed)
  - [Launch the KPM Monitoring xApp](#launch-the-kpm-monitoring-xapp)
  - [Monitor KPIs](#monitor-kpis)
- [KPM Reference](#kpm-reference)
- [Expected Results](#expected-results)
- [Learning Outcomes](#learning-outcomes)

## Overview

This tutorial demonstrates how to integrate an **OCUDU 5G gNB** with the **O-RAN SC Near-RT RIC** or **FlexRIC** using the **O-RAN E2 interface**. The example configures two cells and three UEs, then uses a **KPM Monitoring xApp** to monitor Key Performance Measurements (KPMs).

The gNB exports E2SM-KPM measurements to the selected RIC, where the KPM xApp subscribes to the E2 node and receives reports containing measurements for active UEs.

Separate sections cover O-RAN SC and FlexRIC. Select one RIC for a deployment.

At the end of this tutorial you will be able to:

- Configure multiple cells and UEs
- Connect the gNB to a Near-RT RIC through the E2 interface
- Deploy a KPM Monitoring xApp
- Subscribe to E2SM-KPM reports
- View per-cell and per-UE KPMs

---

## Architecture

```text
          +------------------------+
          |  KPM Monitoring xApp   |
          +-----------+------------+
                      |
          Subscriptions and reports
                      |
              +-------v-------+
              |  O-RAN SC RIC |
              |   or FlexRIC  |
              +-------+-------+
                      |
              E2AP and E2SM-KPM
                      |
         +------------v-------------+
         |         OCUDU gNB        |
         |  Cells 1 and 2, E2 Agent |
         +------------+-------------+
                      |
            ZeroMQ Channel Emulator
                      |
  +---------+---------+---------+---------+
  |         |         |         |         |
UE 1      UE 2      UE 3       ...      UE N
```

---

## Prerequisites

- A supported Ubuntu-based Linux distribution; see the [minimum system requirements](../README.md#minimum-system-requirements)

---

## Testbed Components

| Component | Description |
|-----------|-------------|
| OCUDU gNB | O-RAN-compliant 5G gNB with E2 Agent |
| O-RAN SC Near-RT RIC | Kubernetes-based Near-RT RIC platform |
| FlexRIC | Near-RT RIC platform |
| Open5GS | 5G Core Network |
| KPM Monitoring xApp | Collects and displays KPM metrics |
| UEs | Generate traffic and network measurements |

---
## Clone Repository

```bash
git clone https://github.com/USNISTGOV/O-RAN-Testbed-Automation.git

cd O-RAN-Testbed-Automation
```

---

## Install the Testbed

The O-RAN SC Near-RT RIC is selected by default. Run the following command for the O-RAN SC workflow. To use FlexRIC, skip to the [FlexRIC section](#flexric-with-kpm-xapp) and select it before installation.

```bash
./full_install.sh
```
```console
################################################################################
# Successfully installed the Near-RT RIC, 5G Core, gNodeB, and UE.             #
################################################################################
```

The installation deploys

- Open5GS
- OCUDU
- O-RAN SC Near-RT RIC
- srsRAN UE software
- Kubernetes components

---
## O-RAN SC Near-RT RIC with KPM xApp
This workflow deploys the O-RAN Software Community (O-RAN SC) Near-Real-Time RAN Intelligent Controller (Near-RT RIC), connects it to the OCUDU E2 node, and runs a KPM xApp to collect Key Performance Measurements (KPMs).

After installation run `kubectl get pods -A` and check all the pods are running.

```bash
kubectl get pods -A
```
```console
NAMESPACE      NAME                                                        READY   STATUS    RESTARTS       AGE
kube-flannel   kube-flannel-ds-74qcr                                       1/1     Running   0              160m
kube-system    coredns-674b8bbfcf-l2fqm                                    1/1     Running   0              160m
kube-system    coredns-674b8bbfcf-ll4bq                                    1/1     Running   0              160m
kube-system    etcd-ip-172-31-32-66                                        1/1     Running   3              160m
kube-system    kube-apiserver-ip-172-31-32-66                              1/1     Running   6              160m
kube-system    kube-controller-manager-ip-172-31-32-66                     1/1     Running   8              160m
kube-system    kube-proxy-v248v                                            1/1     Running   0              160m
kube-system    kube-scheduler-ip-172-31-32-66                              1/1     Running   7              160m
ricinfra       deployment-tiller-ricxapp-84b87b8c64-nq4ds                  1/1     Running   0              159m
ricplt         deployment-ricplt-a1mediator-f4888dfd7-88xh9                1/1     Running   0              159m
ricplt         deployment-ricplt-alarmmanager-7f984cdf77-s8j2f             1/1     Running   0              158m
ricplt         deployment-ricplt-appmgr-549d488cb8-nqbkg                   1/1     Running   0              159m
ricplt         deployment-ricplt-e2mgr-7d9f845865-9gn4l                    1/1     Running   0              159m
ricplt         deployment-ricplt-e2term-alpha-55ff9df9d9-5v5lc             1/1     Running   0              159m
ricplt         deployment-ricplt-o1mediator-6fb8f84c97-8cqln               1/1     Running   0              158m
ricplt         deployment-ricplt-rtmgr-668f86855f-kt4d2                    1/1     Running   1 (158m ago)   159m
ricplt         deployment-ricplt-submgr-5b8796c997-vn872                   1/1     Running   0              158m
ricplt         deployment-ricplt-vespamgr-848f7bb874-48bpg                 1/1     Running   0              158m
ricplt         r4-influxdb-influxdb2-0                                     1/1     Running   0              144m
ricplt         r4-infrastructure-kong-78657d8f48-chz9k                     2/2     Running   0              159m
ricplt         r4-infrastructure-prometheus-alertmanager-b9cc56766-g8jjr   2/2     Running   0              159m
ricplt         r4-infrastructure-prometheus-server-6476958975-g5s5l        1/1     Running   0              159m
ricplt         statefulset-ricplt-dbaas-server-0                           1/1     Running   0              159m
ricxapp        ricxapp-hw-go-c84579888-q5xf2                               1/1     Running   0              155m
```
### Start the O-RAN SC Testbed

Generate the tutorial topology, then start the 5G Core, OCUDU cells, and UEs:

```bash
./generate_configurations.sh --ues 1,2,3 --cells 1,2
./run.sh
```

Use `./is_running.sh` to check the components and `./stop.sh` to stop them. O-RAN SC Near-RT RIC services start automatically on boot and can be viewed with `kubectl get pods -A` or `k9s -A`.


### Install KPM Monitoring xApp

First, verify that the OCUDU E2 node is connected to the Near-RT RIC:

```bash
./RAN_Intelligent_Controllers/Near-Real-Time-RIC/additional_scripts/fetch_connected_e2_nodes.sh
```

Expected output should show the OCUDU's Distributed Unit (DU) E2 node (`gnbd_001_001_00019b_0`) as connected.
```json
  {
    "inventoryName": "gnbd_001_001_00019b_0",
    "globalNbId": {
      "plmnId": "00F110",
      "nbId": "0000000000000110011011"
    },
    "connectionStatus": "CONNECTED"
  }
```

Then install the KPM Monitoring xApp:
```bash
./RAN_Intelligent_Controllers/Near-Real-Time-RIC/additional_scripts/install_xapp_kpi_monitor.sh
```

> [!TIP]
> The `kpimon-go` xApp subscribes only to E2 nodes that are already connected to the Near-RT RIC when the xApp starts. If the E2 node connects after `kpimon-go` has already started, rerun `./RAN_Intelligent_Controllers/Near-Real-Time-RIC/additional_scripts/install_xapp_kpi_monitor.sh` to restart the xApp so that it detects the E2 node and establishes the KPM subscriptions.

After installation, run `kubectl get pods -A` and verify that the `kpimon-go` xApp is running.

```bash
kubectl get pods -A
```
```console
NAMESPACE      NAME                                                        READY   STATUS    RESTARTS       AGE
kube-flannel   kube-flannel-ds-74qcr                                       1/1     Running   0              160m
kube-system    coredns-674b8bbfcf-l2fqm                                    1/1     Running   0              160m
kube-system    coredns-674b8bbfcf-ll4bq                                    1/1     Running   0              160m
kube-system    etcd-ip-172-31-32-66                                        1/1     Running   3              160m
kube-system    kube-apiserver-ip-172-31-32-66                              1/1     Running   6              160m
kube-system    kube-controller-manager-ip-172-31-32-66                     1/1     Running   8              160m
kube-system    kube-proxy-v248v                                            1/1     Running   0              160m
kube-system    kube-scheduler-ip-172-31-32-66                              1/1     Running   7              160m
ricinfra       deployment-tiller-ricxapp-84b87b8c64-nq4ds                  1/1     Running   0              159m
ricplt         deployment-ricplt-a1mediator-f4888dfd7-88xh9                1/1     Running   0              159m
ricplt         deployment-ricplt-alarmmanager-7f984cdf77-s8j2f             1/1     Running   0              158m
ricplt         deployment-ricplt-appmgr-549d488cb8-nqbkg                   1/1     Running   0              159m
ricplt         deployment-ricplt-e2mgr-7d9f845865-9gn4l                    1/1     Running   0              159m
ricplt         deployment-ricplt-e2term-alpha-55ff9df9d9-5v5lc             1/1     Running   0              159m
ricplt         deployment-ricplt-o1mediator-6fb8f84c97-8cqln               1/1     Running   0              158m
ricplt         deployment-ricplt-rtmgr-668f86855f-kt4d2                    1/1     Running   1 (158m ago)   159m
ricplt         deployment-ricplt-submgr-5b8796c997-vn872                   1/1     Running   0              158m
ricplt         deployment-ricplt-vespamgr-848f7bb874-48bpg                 1/1     Running   0              158m
ricplt         r4-influxdb-influxdb2-0                                     1/1     Running   0              144m
ricplt         r4-infrastructure-kong-78657d8f48-chz9k                     2/2     Running   0              159m
ricplt         r4-infrastructure-prometheus-alertmanager-b9cc56766-g8jjr   2/2     Running   0              159m
ricplt         r4-infrastructure-prometheus-server-6476958975-g5s5l        1/1     Running   0              159m
ricplt         statefulset-ricplt-dbaas-server-0                           1/1     Running   0              159m
ricxapp        ricxapp-hw-go-c84579888-q5xf2                               1/1     Running   0              155m
ricxapp        ricxapp-kpimon-go-85dc5fdf8b-5s7sg                          1/1     Running   0              38m
```

Generate UE traffic from another terminal so the xApp receives active traffic measurements:

```bash
./User_Equipment/additional_scripts/simulate_ue_traffic_to_core.sh 2 1M 60
```

### View KPI Metrics

Upon installation, metrics will be stored in the InfluxDB pod under `bucket=kpimon`, `org=influxdata` as `UeMetrics` measurements. Open the InfluxDB client with:

```bash
./RAN_Intelligent_Controllers/Near-Real-Time-RIC/additional_scripts/open_influxdb_client_shell.sh
```

Example output from a successful run:

```console
----------------------------------------------------------------
  Near-RT RIC InfluxDB Client
  Org: influxdata, Bucket: kpimon
----------------------------------------------------------------
  1) List all buckets
  2) List measurements in 'kpimon' (last 1h)
  3) List field keys in 'kpimon' (last 1h)
  4) View current KPI metrics
  5) View the latest 20 KPI records
  6) Enter a custom influx command
  7) Open an interactive shell in the InfluxDB pod
  8) Exit
----------------------------------------------------------------
Select a number: 4

Latest KPI metrics:

UeMetrics
  DRB.AirIfDelayUl = 30
  DRB.RlcDelayUl = 5.215263843536377
  DRB.RlcPacketDropRateDl = 0
  DRB.RlcSduDelayDl = 3472.39990234375
  DRB.RlcSduTransmittedVolumeDL = 59446
  DRB.RlcSduTransmittedVolumeUL = 775
  DRB.UEThpDl = 59044
  DRB.UEThpUl = 824
  RRU.PrbAvailDl = 16
  RRU.PrbAvailUl = 95
  RRU.PrbTotDl = 84
  RRU.PrbTotUl = 10
  RRU.PrbUsedDl = 90
  RRU.PrbUsedUl = 11

Press Enter to return to the menu...
```
The metrics can also be viewed in the xApp logs:

```bash
kubectl logs -n ricxapp deployment/ricxapp-kpimon-go
```

```console
RIC Indication message from {gnbd_001_001_00019b_0} received
2026/08/24 21:49:13 Indication Header format = 1
 parsing for UE metrics 
 No of ue= 1
map[DRB.AirIfDelayUl:30 DRB.RlcDelayUl:5.215263843536377 DRB.RlcPacketDropRateDl:0 DRB.RlcSduDelayDl:3472.39990234375 DRB.RlcSduTransmittedVolumeDL:59446 DRB.RlcSduTransmittedVolumeUL:775 DRB.UEThpDl:59044 DRB.UEThpUl:824 RRU.PrbAvailDl:16 RRU.PrbAvailUl:95 RRU.PrbTotDl:84 RRU.PrbTotUl:10 RRU.PrbUsedDl:90 RRU.PrbUsedUl:11]
Parsing UE Metric Done
```

> [!NOTE]
> The O-RAN SC Near-RT RIC can be stopped by running `./RAN_Intelligent_Controllers/Near-Real-Time-RIC/stop.sh`, and started again with `./RAN_Intelligent_Controllers/Near-Real-Time-RIC/run.sh`.

## FlexRIC with KPM xApp
By default, the gNodeB connects to the O-RAN SC Near-RT RIC E2 Terminator. To use FlexRIC instead, set all occurrences of `USE_FLEXRIC` to `true` before installation. Stop the testbed first if it is already running.

```bash
cd Next_Generation_Node_B
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_install.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_uninstall.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../generate_configurations.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../run.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../stop.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' generate_configurations.sh
cd ..
```

Apply the changes by ensuring that FlexRIC is installed and configured correctly:
```bash
./full_install.sh # Confirmation dialog should list "Near-Real-Time RAN Intelligent Controller (FlexRIC)"
./generate_configurations.sh --ues 1,2,3 --cells 1,2
```

### Start the Testbed
Run the testbed with `./run.sh` to start the 5G Core, FlexRIC, gNodeB, and UEs as background processes. Use `./is_running.sh` to check if the components are running, and `./stop.sh` to stop the components.

Verify that `./is_running.sh` reports FlexRIC, UEs 1, 2, and 3, the ZeroMQ channel emulator, and the gNodeB as running.

### Launch the KPM Monitoring xApp
After starting the 5G Core, FlexRIC, gNodeB, and UEs, launch the KPM Monitoring xApp:

```bash
./RAN_Intelligent_Controllers/Flexible-RIC/run_xapp_kpm_moni.sh
```

While the xApp runs, generate UE traffic from another terminal:

```bash
./User_Equipment/additional_scripts/simulate_ue_traffic_to_core.sh 2 1M 60
```

Example output from a successful run:

```console
[xApp]: E42 SETUP-REQUEST tx
[xApp]: E42 SETUP-RESPONSE rx 
[xApp]: xApp ID = 7 
Connected E2 nodes = 1
[xApp] Using S-NSSAI SST=1 SD=ffffff (env SST/SD can override)
[xApp] Subscribing to KPM report style 1.
[xApp]: E42 RIC SUBSCRIPTION REQUEST tx RAN_FUNC_ID 2 RIC_REQ_ID 1 
[xApp]: SUBSCRIPTION RESPONSE rx
[xApp]: Successfully subscribed to RAN_FUNC_ID 2 
[xApp] Subscribing to KPM report style 3.
[xApp]: E42 RIC SUBSCRIPTION REQUEST tx RAN_FUNC_ID 2 RIC_REQ_ID 2 
[xApp]: SUBSCRIPTION RESPONSE rx
[xApp]: Successfully subscribed to RAN_FUNC_ID 2 
[xApp] Subscribing to KPM report style 4.
[xApp]: E42 RIC SUBSCRIPTION REQUEST tx RAN_FUNC_ID 2 RIC_REQ_ID 3 
[xApp]: SUBSCRIPTION RESPONSE rx
[xApp]: Successfully subscribed to RAN_FUNC_ID 2 
E2 node: DU:0

      1 KPM ind_msg latency = 1492 [μs]
DRB.AirIfDelayUl = 30.00 
DRB.RlcDelayUl = 4.81 
DRB.RlcPacketDropRateDl = 0 
DRB.RlcSduDelayDl = 3732.70 [μs]
DRB.RlcSduTransmittedVolumeDL = 58448 
DRB.RlcSduTransmittedVolumeUL = 768 
DRB.UEThpDl = 59044.00 [kbps]
DRB.UEThpUl = 816.00 [kbps]
RACH.PreambleDedCell = 0 
RRU.PrbAvailDl = 16 
RRU.PrbAvailUl = 98 
RRU.PrbTotDl = 84 [%]
RRU.PrbTotUl = 7 [%]
RRU.PrbUsedDl = 90 
RRU.PrbUsedUl = 8 
E2 node: DU:0
```
### Monitor KPIs
The console output shows the xApp successfully subscribed to the KPM service model using RAN function ID 2. The xApp received periodic KPM indication messages from the connected E2 node.

The values below describe the example output above. Results vary with traffic, channel settings, and host performance.

#### Successful E2 Connectivity

- The gNB-DU successfully established an **E2 connection** with FlexRIC.
- The xApp detected the connected E2 node.
- KPM subscriptions were successfully accepted, enabling continuous monitoring of RAN performance metrics.

---

## KPM Reference

The example outputs above include the following Key Performance Measurements (KPMs):

| Metric | Description | Reference |
|---|---|---|
| `DRB.AirIfDelayUl` | Average uplink delay over the air interface | 3GPP TS 28.552 §5.1.1.1.3 |
| `DRB.RlcDelayUl` | Average uplink RLC packet delay | 3GPP TS 28.552 §5.1.1.1.4 |
| `DRB.RlcPacketDropRateDl` | Downlink RLC SDU packet drop rate in the gNB-DU | 3GPP TS 28.552 §5.1.3.2.2 |
| `DRB.RlcSduDelayDl` | Average downlink RLC SDU delay in the gNB-DU | 3GPP TS 28.552 §5.1.3.3.3 |
| `DRB.RlcSduTransmittedVolumeDL` | Downlink transmitted RLC SDU data volume | O-RAN E2SM-KPM §7.10.1 |
| `DRB.RlcSduTransmittedVolumeUL` | Uplink transmitted RLC SDU data volume | O-RAN E2SM-KPM §7.10.2 |
| `DRB.UEThpDl` | Average downlink UE throughput | 3GPP TS 28.552 §5.1.1.3 |
| `DRB.UEThpUl` | Average uplink UE throughput | 3GPP TS 28.552 §5.1.1.3 |
| `RACH.PreambleDedCell` | Received dedicated random-access preambles per cell | 3GPP TS 28.552 §5.1.1.20.1 |
| `RRU.PrbAvailDl` | Available downlink PRBs | 3GPP TS 28.552 §5.1.1.2.6 |
| `RRU.PrbAvailUl` | Available uplink PRBs | 3GPP TS 28.552 §5.1.1.2.8 |
| `RRU.PrbTotDl` | Total downlink PRB utilization | 3GPP TS 28.552 §5.1.1.2.1 |
| `RRU.PrbTotUl` | Total uplink PRB utilization | 3GPP TS 28.552 §5.1.1.2.2 |
| `RRU.PrbUsedDl` | Mean downlink PRBs used for data traffic | 3GPP TS 28.552 §5.1.1.2.5 |
| `RRU.PrbUsedUl` | Mean uplink PRBs used for data traffic | 3GPP TS 28.552 §5.1.1.2.7 |

For FlexRIC, this telemetry can also be visualized with Grafana. See
[KPM Monitor Visualization in Grafana](../OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC/README.md#kpm-monitor-visualization-in-grafana) for setup instructions.

---

## Expected Results

Successful deployment should show:

- The OCUDU E2 node connected to the selected Near-RT RIC
- Successful E2SM-KPM subscriptions
- Periodic KPM indication messages
- Per-UE and per-cell measurements
- KPM data available through InfluxDB or the FlexRIC xApp output

---

## Learning Outcomes

After completing this tutorial you will understand:

- Near-RT RIC integration through the E2 interface
- E2SM-KPM subscriptions and reports
- KPM monitoring with O-RAN SC and FlexRIC
- Per-UE and per-cell performance measurements

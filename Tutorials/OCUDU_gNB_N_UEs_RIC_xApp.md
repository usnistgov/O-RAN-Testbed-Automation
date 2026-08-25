## Tutorial: OCUDU gNB with N UEs, RIC, and KPM Monitoring xApp
## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Learning Objectives](#learning-objectives)
- [Prerequisites](#prerequisites)
- [Testbed Components](#testbed-components)
- [Clone Repository](#clone-repository)
- [Install The Testbed](#install-the-testbed)
- [Tutorial Workflow](#tutorial-workflow)
- [OSC Near-RT RIC with KPM xApp](#osc-near-rt-ric-with-kpm-xapp)
  - [View KPI Metrics](#view-kpi-metrics)
- [Flexric with KPM xApp](#flexric-with-kpm-xapp)
  - [Start the Testbed](#start-the-testbed)
  - [Launch the KPM Monitoring xApp](#launch-the-kpm-monitoring-xapp)
  - [Monitor KPIs](#monitor-kpis)
- [KPM Monitoring xApp Use Case](#kpm-monitoring-xapp-use-case)
  - [Objective](#objective)
  - [xApp Responsibilities](#xapp-responsibilities)
- [Example Monitoring Output](#example-monitoring-output)
- [Expected Results](#expected-results)
- [Conclusion](#conclusion)

## Overview

This tutorial demonstrates how to integrate an **OCUDU 5G gNB** with **FlexRIC** using the **O-RAN E2 interface** and deploy a **KPM Monitoring xApp** to monitor real-time Key Performance Measurements (KPMs) from multiple connected User Equipments (UEs).

The goal is to build a complete Near-Real-Time RIC testbed where the gNB exports E2SM-KPM measurements to FlexRIC, and the KPM xApp subscribes to these measurements to monitor the performance of **N active UEs** in real time.

---

## Architecture

```text
                +------------------------+
                |      KPM xApp          |
                | (Monitoring Dashboard) |
                +-----------+------------+
                            |
                    E2 Subscription
                            |
                    +-------v-------+
                    |    FlexRIC    |
                    |  Near-RT RIC  |
                    +-------+-------+
                            |
                       E2 Interface
                            |
               +------------v-------------+
               |      OCUDU gNB           |
               |      E2 Agent            |
               +------------+-------------+
                            |
                     Radio Access Network
                            |
         +---------+---------+---------+---------+
         |         |         |         |         |
        UE1       UE2       UE3      ...       UEN
```

---

## Learning Objectives

By completing this tutorial, user will learn how to:

- Deploy an OCUDU gNB with E2 support
- Connect the gNB to FlexRIC through the E2 interface
- Launch multiple UEs
- Deploy a KPM Monitoring xApp
- Subscribe to E2SM-KPM reports
- Monitor real-time RAN performance
- Collect per-cell and per-UE measurements

---

## Prerequisites

- Ubuntu 22.04 or later
- OCUDU gNB with E2 support
- FlexRIC
- Open5GS Core Network
- SDR or ZeroMQ-based RAN setup
- sraUEs

---

## Testbed Components

| Component | Description |
|-----------|-------------|
| OCUDU gNB | O-RAN compliant 5G gNB with E2 Agent |
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

```bash
./full_install.sh
```
```text
################################################################################
# Successfully installed the Near-RT RIC, 5G Core, gNodeB, and UE.             #
################################################################################
```

The installation deploys

- Open5GS
- OCUDU
- O-RAN SC Near-RT RIC
- UE
- Kubernetes components

---
# Tutorial Workflow
## OSC Near-RT RIC with KPM xApp
This tutorial demonstrates how to deploy the O-RAN Software Community (OSC) Near-Real-Time RAN Intelligent Controller (Near-RT RIC) and connect it to a compatible O-RAN E2 node. It also shows how to deploy and run a KPM xApp to collect and monitor Key Performance Measurements (KPM) from the connected RAN.

The tutorial covers the deployment of the Near-RT RIC components, configuration of the E2 interface, and execution of the KPM xApp to retrieve RAN performance metrics. This provides a practical example of using the Near-RT RIC to monitor RAN behavior through the O-RAN E2 interface.
After successful installation run `kubectl get pods -A` and check all the pods are running.
```bash
sudo kubectl get pods -A
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
Then run the testbed with `./run.sh` to start the 5G Core, gNodeB, and UE. Use `./is_running.sh` to check if the components are running, and `./stop.sh` to stop the components. The optional RIC starts automatically on boot and can be accessed with `k9s -A`.


### Install KPM xApp
Install KPM xApp with ./additional_scripts/install_xapp_kpi_monitor.sh. The xApp will only connect to connected E2 nodes,
After installation run again `kubectl get pods -A` and verify kpimon-go xapp is running.
```bash
sudo kubectl get pods -A
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

### View KPI metrics
Upon installation, metrics will be stored in the InfluxDB pod under bucket=kpimon, org=influxdata as UeMetrics measurements. Access this data by opening the InfluxDB Client with `./additional_scripts/open_influxdb_client_shell.sh`.

```bash
 ./open_influxdb_client_shell.sh 

----------------------------------------------------------------
  Near-RT RIC InfluxDB Client
  Org: influxdata | Bucket: kpimon
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
  DRB.RlcDelayUl = 5.888718128204346
  DRB.RlcPacketDropRateDl = 0
  DRB.RlcSduDelayDl = 3520.10009765625
  DRB.RlcSduTransmittedVolumeDL = 60071
  DRB.RlcSduTransmittedVolumeUL = 710
  DRB.UEThpDl = 59044
  DRB.UEThpUl = 756
  RRU.PrbAvailDl = 16
  RRU.PrbAvailUl = 96
  RRU.PrbTotDl = 84
  RRU.PrbTotUl = 9
  RRU.PrbUsedDl = 90
  RRU.PrbUsedUl = 10

```
Additionally, the metrics can be  visualized in xApp logs. Run ` kubectl  logs -f -n ricxapp  <pod name>`

``` RIC Indication message from {gnbd_001_001_00019b_0} received
2026/08/24 21:49:13 Indication Header format = 1
 parsing for UE metrics 
 No of ue= 1
map[DRB.AirIfDelayUl:30 DRB.RlcDelayUl:5.215263843536377 DRB.RlcPacketDropRateDl:0 DRB.RlcSduDelayDl:3472.39990234375 DRB.RlcSduTransmittedVolumeDL:59446 DRB.RlcSduTransmittedVolumeUL:775 DRB.UEThpDl:59044 DRB.UEThpUl:824 RRU.PrbAvailDl:16 RRU.PrbAvailUl:95 RRU.PrbTotDl:84 RRU.PrbTotUl:10 RRU.PrbUsedDl:90 RRU.PrbUsedUl:11]
Parsing UE Metric Done
```

## Flexric with KPM xApp
By default, the gNodeB's Distributed Unit (DU) connects to the O-RAN SC Near-RT RIC E2 Terminator. To use FlexRIC instead of O-RAN SC's Near-RT RIC, set all occurrences of `USE_FLEXRIC` to `true`, then run `../generate_configurations.sh`.

```bash
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_install.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_uninstall.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../generate_configurations.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../run.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../stop.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' generate_configurations.sh
```

###  Start the Testbed
Run the testbed with `./run.sh` to start the 5G Core, FlexRIC, gNodeB, and UE as background processes. Use `./is_running.sh` to check if the components are running, and `./stop.sh` to stop the components.
#### Expected Output
```
Running FlexRIC...
Starting flexric in background...
FlexRIC: RUNNING

Waiting for AMF to be ready..............
AMF is ready.

Running gNodeB...
Starting gNodeB in background...
Waiting for gNodeB to be ready.....
gNodeB is ready.
ZMQ_Broker: RUNNING
gNodeB: RUNNING

Running User Equipment...
Running UE 3 in background...
Using srsue binary: /home/ubuntu/O-RAN-Testbed-Automation-Dev/User_Equipment/srsRAN_4G/build/srsue/src/srsue
Starting User Equipment in background...
User Equipment: RUNNING (ue3)
Running UE 2...
Using srsue binary: /home/ubuntu/O-RAN-Testbed-Automation-Dev/User_Equipment/srsRAN_4G/build/srsue/src/srsue
# Script: /home/ubuntu/O-RAN-Testbed-Automation-Dev/User_Equipment/install_scripts/setup_ue_namespace.sh...
Starting srsue (ue2) in namespace ue2...
Active RF plugins: libsrsran_rf_uhd.so libsrsran_rf_zmq.so
Inactive RF plugins: 
Reading configuration file configs/ue2.conf...

Built in Release mode using commit 6bcbd9e5b on branch master.

Opening 1 channels in RF device=zmq with args=tx_port=tcp://*:2201,rx_port=tcp://10.201.0.9:2200,base_srate=11.52e6,id=ue2
Supported RF device list: UHD zmq file
CHx base_srate=11.52e6
CHx id=ue2
Current sample rate is 1.92 MHz with a base rate of 11.52 MHz (x6 decimation)
CH0 rx_port=tcp://10.201.0.9:2200
CH0 tx_port=tcp://*:2201
Current sample rate is 11.52 MHz with a base rate of 11.52 MHz (x1 decimation)
Current sample rate is 11.52 MHz with a base rate of 11.52 MHz (x1 decimation)
Waiting PHY to initialize ... done!
Attaching UE...
Random Access Transmission: prach_occasion=0, preamble_index=0, ra-rnti=0x39, tti=174
Random Access Complete.     c-rnti=0x4601, ta=0
RRC Connected
PDU Session Establishment successful. IP: 10.45.0.102
RRC NR reconfiguration successful.

```
### Launch the KPM Monitoring xApp
After starting the 5G Core, FlexRIC, gNodeB, and UE, use the `./run_xapp_kpm_moni_xapp.sh` scripts within the RAN_Intelligent_Controllers/FlexRIC/additional_scripts directory to interact with the gNodeB and UE.

#### Expected Output
```
[XApp]: SUBSCRIPTION RESPONSE rx
[XApp]: Successfully subscribed to RAN_FUNC_ID 2
[XApp] Subscribing to KPM report style 3.
[XApp]: E42 RIC SUBSCRIPTION REQUEST tx RAN_FUNC_ID 2 RIC_REQ_ID 2
[XApp]: SUBSCRIPTION RESPONSE rx
[XApp]: Successfully subscribed to RAN_FUNC_ID 2
[XApp] Subscribing to KPM report style 4.
[XApp]: E42 RIC SUBSCRIPTION REQUEST tx RAN_FUNC_ID 2 RIC_REQ_ID 3
[XApp]: SUBSCRIPTION RESPONSE rx
[XApp]: Successfully subscribed to RAN_FUNC_ID 2

E2 node: DU:0

    1 KPM ind_msg latency = 252296672587512435 [μs]

DRB.AirIfDelayUl = 30.00
DRB.RlcDelayUl = 11.10
DRB.RlcPacketDropRateDl = 0
DRB.RlcSduDelayDl = 7.70 [μs]
DRB.RlcSduTransmittedVolumeDL = 246
DRB.RlcSduTransmittedVolumeUL = 13803
DRB.UEThpDl = 265.00 [kbps]
DRB.UEThpUl = 13872.00 [kbps]

RACH.PreambleDedCell = 0

RRU.PrbAvailDl = 105
RRU.PrbAvailUl = 2
RRU.PrbTotDl = 0 [%]
RRU.PrbTotUl = 98 [%]
RRU.PrbUsedDl = 1
RRU.PrbUsedUl = 104

E2 node: DU:0

    2 KPM ind_msg latency = 229372533753335962 [μs]

UE ID type = gNB-DU, gnb_cu_ue_f1ap = 0

DRB.AirIfDelayUl = 30.00
DRB.RlcDelayUl = 11.10
DRB.RlcPacketDropRateDl = 0
DRB.RlcSduDelayDl = 7.70 [μs]
DRB.RlcSduTransmittedVolumeDL = 246
DRB.RlcSduTransmittedVolumeUL = 13803
DRB.UEThpDl = 265.00 [kbps]
DRB.UEThpUl = 13872.00 [kbps]
```
### Monitor KPIs
The console output shows the xApp successfully subscribed to the KPM service model using RAN function ID 2. The xApp received periodic KPM indication message from the connected E2 node. 

#### Successful E2 Connectivity

- The FlexRIC xApp successfully established an **E2 connection** with the gNB-DU.
- One E2 node was detected and successfully registered with the **Near-RT RIC**.
- KPM subscriptions were successfully accepted, enabling continuous monitoring of RAN performance metrics.

---

#### Throughput Performance

- The measured **uplink throughput (~13.8 Mbps)** was significantly higher than the **downlink throughput (~265 kbps)**.
- This indicates that the test traffic was primarily **uplink-focused**, resulting in higher utilization of uplink radio resources.

---

#### Latency Performance

The measured latency values were:

| Metric | Value |
|---|---:|
| UL RLC Delay | ~11 µs |
| DL RLC SDU Delay | ~7.7 µs |
| UL Air Interface Delay | ~30 µs |

- The low latency values indicate efficient packet processing and fast communication between the **UE and gNB-DU**.
- The results demonstrate suitable performance for near-real-time RAN monitoring and optimization applications.

---

#### Packet Reliability

- The measured **downlink packet drop rate was 0%**.
- No significant packet loss or RLC retransmission issues were observed.
- This demonstrates stable radio communication and reliable data transmission.

---

#### Radio Resource Utilization

- **Uplink PRB utilization reached approximately 98%**, indicating that most available uplink radio resources were allocated to the UE.
- **Downlink PRB utilization remained close to 0%**, showing that downlink resources were mostly unused during the measurement period.
- The PRB utilization pattern matches the observed traffic profile, where uplink traffic dominated over downlink traffic.

---

# KPM Monitoring xApp Use Case

## Objective

The KPM Monitoring xApp provides **real-time visibility into RAN performance** without modifying the behavior of the network. Instead of controlling the scheduler or radio parameters, the xApp continuously collects standardized performance metrics from the gNB.

This enables operators and researchers to observe network behavior as UEs connect, disconnect, and generate traffic.

---

## xApp Responsibilities

The KPM Monitoring xApp performs the following tasks:

1. Establishes an E2 connection through FlexRIC.
2. Sends an E2 Subscription Request.
3. Receives periodic E2 Indication messages.
4. Decodes E2SM-KPM reports.
5. Displays live UE and cell performance metrics.
6. Stores collected measurements for analysis.

---
# Conclusion

In this tutorial, **OCUDU gNB** is integrated with **FlexRIC** and a **KPM Monitoring xApp** to collect standardized O-RAN KPM measurements from multiple connected UEs.

The KPM Monitoring xApp provides continuous visibility into radio network performance by subscribing to E2SM-KPM reports over the E2 interface. This setup serves as a foundation for network monitoring, performance analysis, AI/ML data collection, and the development of more advanced O-RAN xApps for optimization and closed-loop control.

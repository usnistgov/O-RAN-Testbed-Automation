# Deploying  OCUDU gNB with One UE, Grafana Monitoring, and Traffic Simulation

## Overview

This tutorial demonstrates how to deploy a complete Open RAN testbed using the NIST O-RAN Testbed Automation framework.

The deployment consists of:

- Open5GS Core Network
- OCUDU gNB
- One UE (srsRAN UE)
- O-RAN SC Near-RT RIC
- Grafana Monitoring
- Simulated user traffic using ping and iperf3

At the end of this tutorial you will be able to

- Deploy a complete 5G network
- Attach one UE
- Verify connectivity
- Generate network traffic
- Observe KPIs in Grafana
- Monitor packet throughput and latency

---



## Prerequisites

Ubuntu 22.04 LTS

Minimum hardware

- 6 CPU cores
- 8 GB RAM
- 60 GB storage

Software

- Git
- Docker
- Kubernetes
- kubectl
- Helm

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

The installation deploys

- Open5GS
- OCUDU
- O-RAN SC Near-RT RIC
- UE
- Kubernetes components

---

## Verify Installation

```bash
./is_running.sh
```

Expected output

```
5G Core ............. Running
Near-RT RIC ......... Running
OCUDU ............... Running
UE .................. Running
```

---

## Start the Testbed

```bash
./run.sh
```

---

## Verify UE Attachment

Expected console output

```
Random Access Complete

RRC Connected

PDU Session Establishment Successful

IP Address:
10.45.0.101
```

---

## Verify Network Connectivity

Inside the UE

```bash
ping 10.45.0.1
```

Expected

```
64 bytes from 10.45.0.1

time=12 ms
```

---

## Launch Grafana

To visuallize the performance metrics start the grafana WebUI from gNB directory.

- **Start Grafana WebUI**: Start the dashboard and its Docker Compose dependencies with `./start_grafana_webui.sh`.
- **Stop Grafana WebUI**: Stop the dashboard container with `./stop_grafana_webui.sh`.

The dashboard is hosted at: 
```
http://localhost:3300
```

Default credentials

```
admin
admin
```

---

## Observe Metrics

Useful dashboards include

- UE throughput
- Packet loss
- Latency
- Cell KPIs
- Downlink MCS
- Uplink MCS
- CQI

---

## Traffic Simulation

# Verify Network Connectivity

After the UE successfully attaches and receives a PDU session, verify that it can reach the UPF gateway.

Run the following command from the host machine:

```bash
sudo ip netns exec ue1 ping 10.45.0.1
```

Expected output:

```
PING 10.45.0.1 (10.45.0.1)
64 bytes from 10.45.0.1: icmp_seq=1 ttl=64 time=1.2 ms
64 bytes from 10.45.0.1: icmp_seq=2 ttl=64 time=1.1 ms
```

If the ping succeeds, the UE has end-to-end IP connectivity through the 5G core network.

<b>OCUDU Grafana WebUI Visualization</b><div align="center">
  <img src="grafana.png" alt="OCUDU Grafana WebUI" width="75%">
</div>


# Traffic Simulation

Network traffic can be generated using `ping` and `iperf3` to verify user-plane connectivity and observe performance metrics in Grafana.

The UE runs inside the `ue1` Linux network namespace. All UE traffic generation commands should be executed using:

```bash
sudo ip netns exec ue1 <command>
```

---

## Continuous Ping

Generate ICMP traffic from the UE to the UPF gateway:

```bash
sudo ip netns exec ue1 ping 10.45.0.1
```

Observe:

- Round-trip time (RTT)
- Packet loss
- Latency metrics in Grafana

Stop the ping using:

```
Ctrl+C
```

---

# iperf3 Throughput Test

`iperf3` can be used to generate user-plane traffic and measure throughput between the UE and the core network.

## Install iperf3 (if required)

On the host:

```bash
sudo apt update
sudo apt install iperf3
```

---

## Start iperf3 Server

Start the iperf3 server on the UPF-side interface:

```bash
iperf3 -s -B 10.45.0.1
```

The server listens on the 5G core data network interface.

---

## Generate Uplink Traffic

Run the iperf3 client from the UE namespace:

```bash
sudo ip netns exec ue1 iperf3 -c 10.45.0.1 -t 30
```

This generates a 30-second uplink traffic stream:

```
UE → 5G Core
```

---

## Generate Downlink Traffic

To test downlink throughput:

```bash
sudo ip netns exec ue1 iperf3 -c 10.45.0.1 -R -t 30
```

The `-R` option reverses the traffic direction:

```
5G Core → UE
```

---

## Example iperf3 Output

Expected output:

```
ubuntu@ip-172-31-18-66:~$ sudo ip netns exec ue1 iperf3 -c 10.45.0.1 -R -t 60
Connecting to host 10.45.0.1, port 5201
Reverse mode, remote host 10.45.0.1 is sending
[  5] local 10.45.0.101 port 49200 connected to 10.45.0.1 port 5201
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.04   sec  1.50 MBytes  12.1 Mbits/sec                  
[  5]   1.04-2.04   sec  1.50 MBytes  12.6 Mbits/sec                  
[  5]   2.04-3.07   sec  1.50 MBytes  12.2 Mbits/sec                  
[  5]   3.07-4.08   sec  1.50 MBytes  12.5 Mbits/sec                  
[  5]   4.08-5.02   sec  1.50 MBytes  13.3 Mbits/sec                  
[  5]   5.02-6.05   sec  1.62 MBytes  13.3 Mbits/sec                  
[  5]   6.05-7.02   sec  1.50 MBytes  13.0 Mbits/sec                  
[  5]   7.02-8.01   sec  1.50 MBytes  12.7 Mbits/sec                  
[  5]   8.01-9.10   sec  1.50 MBytes  11.6 Mbits/sec                  
[  5]   9.10-10.04  sec  1.50 MBytes  13.3 Mbits/sec  

iperf Done.
```

Throughput depends on:

- Host CPU resources
- Network configuration
- gNB configuration
- RF simulation parameters

---

# Observe Grafana Metrics

While running `ping` or `iperf3`, monitor the Grafana dashboard.

Expected changes:

- UE throughput
- Packet rate
- Latency
- Active UE statistics

---

# Troubleshooting Traffic

If no traffic is observed, verify UE connectivity first:

```bash
sudo ip netns exec ue1 ping 10.45.0.1
```

Check the UE namespace:

```bash
sudo ip netns exec ue1 ip addr
```

Check routing:

```bash
sudo ip netns exec ue1 ip route
```

Verify that the iperf3 server is running:

```bash
iperf3 -s -B 10.45.0.1
```

---

## Useful Commands

Check Kubernetes

```bash
kubectl get pods -A
```

Check RIC

```bash
k9s -A
```

Stop testbed

```bash
./stop.sh
```

Restart

```bash
./run.sh
```

---

## Expected Results

Successful deployment should show

✓ UE attached

✓ PDU session established

✓ Internet connectivity

✓ Active Grafana dashboard

✓ Live KPIs

✓ Traffic visible

✓ Near-RT RIC operational

---

## Troubleshooting

### UE does not attach

Check

```bash
./is_running.sh
```

Restart

```bash
./run.sh
```

---

### Grafana empty

Verify

- ZMQ broker active

---

### No traffic

Check

```bash
ping 10.45.0.1
```

Then

```bash
iperf3
```

---

## Learning Outcomes

After completing this tutorial you will understand

- Open RAN architecture
- OCUDU deployment
- UE attachment procedure
- PDU session establishment
- KPI monitoring
- Grafana dashboards
- Traffic generation
- Network performance analysis

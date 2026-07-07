# Deploying  OCUDU gNB with One UE, Grafana Monitoring, and Traffic Simulation

## Overview

This tutorial demonstrates how to deploy a complete Open RAN testbed using the NIST O-RAN Testbed Automation framework.

The deployment consists of:

- Open5GS Core Network
- OCUDU gNB
- One UE (srsRAN UE)
- O-RAN SC Near-RT RIC
- Grafana Monitoring
- Prometheus
- ZMQ metrics
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
- Grafana
- Prometheus
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
Grafana ............. Running
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

Open

```
http://<grafana-ip>:3000
```

Default credentials

```
admin
admin
```

---

## Observe Metrics

Useful dashboards include

- CPU utilization
- Memory
- UE throughput
- Packet loss
- Latency
- PRB utilization
- Cell KPIs
- KPM xApp metrics

---

## Traffic Simulation

### Continuous Ping

```bash
ping 8.8.8.8
```

Observe

- RTT
- Packet loss

---

### iperf3 Server

On the core network

```bash
iperf3 -s
```

---

### iperf3 Client

On the UE

```bash
iperf3 -c <core-IP>
```

Example

```
iperf3 -c 10.45.0.1
```

Expected throughput

```
30–90 Mbps
```

(depending on hardware)

---

## Observe Grafana

During iperf execution you should observe

- Throughput increases
- CPU usage
- PRB allocation
- UE activity
- Packet counters
- ZMQ metrics

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

- Prometheus running
- ZMQ broker active
- KPM xApp connected

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

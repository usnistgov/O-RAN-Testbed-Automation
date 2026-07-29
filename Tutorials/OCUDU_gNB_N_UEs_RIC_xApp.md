## Tutorial: OCUDU gNB with N UEs, FlexRIC, and KPM Monitoring xApp
## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Learning Objectives](#learning-objectives)
- [Prerequisites](#prerequisites)
- [Testbed Components](#testbed-components)
- [Tutorial Workflow](#tutorial-workflow)
  - [Step 1: Start the 5G Core](#step-1-start-the-5g-core)
  - [Step 2: Start FlexRIC](#step-2-start-flexric)
  - [Step 3: Launch the gNB](#step-4-launch-the-gnb)
  - [Step 4: Attach Multiple UEs](#step-5-attach-multiple-ues)
  - [Step 5: Launch the KPM Monitoring xApp](#step-6-launch-the-kpm-monitoring-xapp)
  - [Step 6: Monitor KPIs](#step-7-monitor-kpis)
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
## Enable Flexric
By default, the gNodeB's Distributed Unit (DU) connects to the O-RAN Software Community's Near-Real-Time RAN Intelligent Controller (O-RAN SC Near-RT RIC) E2 Terminator. To use FlexRIC instead of O-RAN SC's Near-RT RIC, set all occurrences of `USE_FLEXRIC` to `true`, then run `../generate_configurations.sh`.

```bash
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_install.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../full_uninstall.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../generate_configurations.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../run.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' ../stop.sh
sed -i 's/^USE_FLEXRIC=false$/USE_FLEXRIC=true/' generate_configurations.sh
```
# Tutorial Workflow

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

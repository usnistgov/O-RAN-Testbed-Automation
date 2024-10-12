# Open RAN Testbed
Installation scripts to automate the deployment process of the 5G O-RAN testbed.

## Setting Up on a Virtual Machine

### Operating System
Use an Ubuntu-based operating system (supported versions are 20, 22, and 24). Linux Mint 22 (based on Ubuntu 24) is the recommendation.

---
### Virtual Machine Preferences
If using VirtualBox, for optimal user experience consider using the following configuration parameters:
- **System**
  - **Base Memory**: Set the RAM to something reasonable, e.g., 4096 MB or 8192 MB.
  - **Extended Features**: Ensure that `Enable I/O APIC` is checked to improve interrupt handling.
  - **Extended Features**: Check `Enable PAE/NX` and if possible, also check `Enable Nested VT-x/AMD-V`.
  - **Paravirtualization Interface**: If the host machine is a Mac choose `Default`, if Windows choose `Hyper-V`, and if Linux choose `KVM`.
  - **Hardware Virtualization**: Ensure that `Enabled Nested Paging` is checked.
- **Display**
  - **Video Memory**: Set the slider to the maximum if using a Desktop environment.
- **Storage**
  - It is recommended not to have a hard drive less than 50 GB. If after installing the RIC, the xApp stays in the "pending" state then this is likely the cause.
  - If using a SSD hard drive, check the SATA controller's `Solid-state Drive` option.
- **Network**
  - **Attached to**: Select `NAT`.

---
## Installation Guide
Run the Update Manager to get everything up-to-date, then reboot.
```
sudo apt-get update -y && sudo apt-get upgrade -y
```

Install the VirtualBox Guest Additions, then type the following command into the terminal and reboot:
```
sudo adduser $USER vboxsf
```

Next install Git:
```
sudo apt-get install -y git
```

Then clone the O-RAN-Testbed repository over HTTPS:
```
git clone https://github.com/usnistgov/O-RAN-Testbed-Automation.git
```

Alternatively, you may clone the repository over SSH:
```
git clone git@github.com:usnistgov/O-RAN-Testbed-Automation.git
```

Next, start the installation process (it is recommended to run it as your current user rather than as root):
```
./full_install.sh
```
Note: Since `set -e` is set, the scripts will terminate upon reaching an error so that it can be corrected before trying again. Please be patient until you reach an error or a successful testbed installation:
```
################################################################################
# Successfully installed the 5G Core, gNodeB, UE, and RIC.                     #
################################################################################
```

After successful installation, ensure that the configs/ files are generated; they are generated with `./generate_configurations.sh`. Run the testbed with `./run.sh` to start the 5G Core and gNodeB as background processes, and the User Equipment in the foreground.

```
Attaching UE...
Random Access Transmission: prach_occasion=0, preamble_index=0, ra-rnti=0x39, tti=4174
Random Access Complete.     c-rnti=0x4601, ta=0
RRC Connected
PDU Session Establishment successful. IP: 10.45.0.2
RRC NR reconfiguration successful.
```

<!--
## Enabling KubeArmor for Kubernetes Runtime Security Enforcement

Optionally, to enable [KubeArmor](https://kubearmor.io/), please run the following.
```
./RAN_Intelligent_Controller/install_scripts/other_scripts/install_kubearmor.sh
```
This will install pods under namespace "kubearmor" and will terminate/restart the other pods to support the security engine. Check the status of the pods with `kubectl get pods -A`.
-->

## NIST Commercial Product Disclaimer

Certain equipment, instruments, software, or materials are identified in this paper in order to specify the experimental procedure adequately.  Such identification is not intended to imply recommendation or endorsement of any product or service by NIST, nor is it intended to imply that the materials or equipment identified are necessarily the best available for the purpose.

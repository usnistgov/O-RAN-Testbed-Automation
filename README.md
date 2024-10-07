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
  - **Extended Features**: Ensure that `Enable I/O APIC` is checked to improve the handling of interrupts.
  - **Extended Features**: Check `Enable PAE/NX` and if possible, also check `Enable Nested VT-x/AMD-V`.
  - **Paravirtualization Interface**: If the host machine is a Mac choose `Default`, if Windows choose `Hyper-V`, and if Linux choose `KVM`.
  - **Hardware Virtualization**: Ensure that `Enabled Nested Paging` is checked.
- **Display**
  - **Video Memory**: Set the slider to the maximum if using a Desktop environment.
- **Storage**
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

After successful installation, ensure that the configs/ files are generated; they are generated with `./generate_configurations.sh`.

## NIST Commercial Product Disclaimer

Certain equipment, instruments, software, or materials are identified in this paper in order to specify the experimental procedure adequately.  Such identification is not intended to imply recommendation or endorsement of any product or service by NIST, nor is it intended to imply that the materials or equipment identified are necessarily the best available for the purpose.

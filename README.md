# Automation Tool for Deploying 5G O-RAN Testbeds
A set of installation scripts designed to automate the deployment and configuration of a 5G Open Radio Access Network (O-RAN) testbed. The tool simplifies setting up the 5G Core components, gNodeB (Radio Unit, Distributed Unit, Centralized Unit), User Equipment (UE), and RAN Intelligent Controller (RIC) to facilitate reducing the complexity and time required to operationalize the testbed.

## Setting Up on a Virtual Machine

### Minimum System Requirements
- **Operating System**: Linux distributions based on Ubuntu 20, Ubuntu 22, and Ubuntu 24 are supported.
  - _Recommendation: Linux Mint 22, based on Ubuntu 24._
- **Hard Drive Storage**: Must be `≥ 35` GB.
- **Base Memory/RAM**: Must be `≥ 6000` MB.
- **Number of Processors**: Must be `≥ 2` processors.
  - _Recommendation: Between `6-8` processors for optimal performance._
- A stable internet connection must be maintained during the installation otherwise the process will fail and require starting over.

> [!NOTE]
> If any pods stay in a pending or crash loop state after installing the RIC and running the testbed, then limited resources may be the cause.

### Virtual Machine Preferences
For VirtualBox users, consider the following configuration parameters to improve performance.
- **System**
  - **Extended Features**: Ensure that `Enable I/O APIC` is checked to improve interrupt handling.
  - **Extended Features**: Check `Enable PAE/NX` and if possible, also check `Enable Nested VT-x/AMD-V`.
  - **Paravirtualization Interface**: If the host machine is a Mac choose `Default`, if Windows choose `Hyper-V`, and if Linux choose `KVM`.
  - **Hardware Virtualization**: Ensure that `Enabled Nested Paging` is checked.
- **Display**
  - **Video Memory**: Set the slider to the maximum if using a Desktop environment.
- **Storage**
  - Check the SATA controller's `Solid-state Drive` option if using an SSD hard drive.
- **Network**
  - **Attached to**: Select `NAT` to allow the components to communicate locally.

---
## Installation Guide
Run the Update Manager to get packages up-to-date, then reboot.
```console
sudo apt-get update -y && sudo apt-get upgrade -y
```

For VirtualBox, install the Guest Additions with the following commands, then reboot.
```console
sudo apt-get install -y dkms build-essential linux-headers-generic linux-headers-$(uname -r)
mkdir /media/cdrom
sudo mount /dev/cdrom /media/cdrom
cd /media/cdrom
sudo ./VBoxLinuxAdditions.run
sudo adduser $USER vboxsf
``` 

Next, install Git and clone the O-RAN-Testbed repository over HTTPS:
```console
sudo apt-get install -y git
git clone https://github.com/usnistgov/O-RAN-Testbed-Automation.git
```

> Alternatively, the repository may be cloned over SSH:
> ```console
> git clone git@github.com:usnistgov/O-RAN-Testbed-Automation.git
> ```

Begin the installation process, recommended to be run as your current user rather than as root:
```console
./full_install.sh
```
> [!TIP]
> Since `set -e` is set, the scripts will terminate upon reaching an error so that it can be corrected before trying again. Since the scripts are idempotent they will only restart the incomplete steps of the installation process unless specified otherwise. Please be patient until an error is reached or the testbed installation is successful.
```
################################################################################
# Successfully installed the 5G Core, gNodeB, UE, and RIC.                     #
################################################################################
```

After successful installation, verify that the configs/ files are generated for the 5G_Core, gNodeB, and User_Equipment using `./generate_configurations.sh`. Run the testbed with `./run.sh` to start the 5G Core and gNodeB as background processes, and the User Equipment in the foreground.

```console
Attaching UE...
Random Access Transmission: prach_occasion=0, preamble_index=0, ra-rnti=0x39, tti=4174
Random Access Complete.     c-rnti=0x4601, ta=0
RRC Connected
PDU Session Establishment successful. IP: 10.45.0.2
RRC NR reconfiguration successful.
```

## Contact Information

[USNISTGOV/O-RAN-Testbed-Automation][gh-ota] is developed and maintained
by the [Internet Technologies Research Group][nist-itrg], principally:

- Simeon J. Wuthier, @Simewu
- Peng Liu, @fjcintron
- Kyehwan Lee, @kyehwanlee
- Fernando J. Cintrón, @fjcintron

## NIST Commercial Product Disclaimer

Certain equipment, instruments, software, or materials are identified in this paper in order to specify the experimental procedure adequately. Such identification is not intended to imply recommendation or endorsement of any product or service by NIST, nor is it intended to imply that the materials or equipment identified are necessarily the best available for the purpose.

<!-- References -->

[nist-itrg]: https://www.nist.gov/ctl/wireless-networks-division
[gh-ota]: https://github.com/usnistgov/O-RAN-Testbed-Automation

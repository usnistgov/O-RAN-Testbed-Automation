# Automation Tool for Deploying 5G O-RAN Testbeds
These installation scripts automate the deployment and configuration of a 5G Open Radio Access Network (O-RAN) testbed on both bare metal and virtualized environments, based upon the blueprints described in [[1]][nist-tn]. The tool simplifies setting up the 5G testbed components, including the 5G Core; Next Generation Node B (gNodeB) composed of Radio Unit (RU), Distributed Unit (DU), and Centralized Unit (CU); User Equipment (UE); and RAN Intelligent Controller (RIC), thereby reducing the complexity and time required to operationalize the testbeds described in the report above.

## Setting Up the Testbed
The automation tool can be used in virtual machines and physical machines with the minimum system requirements listed below. More details on the build options, including the configuration of physical hardware and individual software components are described in the report [[1]][nist-tn].

### Minimum System Requirements
- **Operating System**: Linux distributions based on Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, and Ubuntu 24.04 LTS are supported.
  - _Recommendation: Linux Mint 22, based on Ubuntu 24.04 LTS._
- **Hard Drive Storage**: Must be `≥ 35` GB.
- **Base Memory/RAM**: Must be `≥ 6000` MB.
- **Number of Processors**: Must be `≥ 2` processors.
  - _Recommendation: Between `6-8` processors for optimal performance._
- A stable internet connection must be maintained during the installation otherwise the process will fail and require starting over.

> [!NOTE]
> If any pods stay in a pending or crash loop state after installing the RIC and running the testbed, then limited resources may be the cause.

### Virtual Machine Preferences
For users using a virtual machine, e.g., VirtualBox, the following configuration parameters may be considered to improve performance.
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
sudo apt-get update && sudo apt-get upgrade -y
```

If using VirtualBox, insert the Guest Additions CD image then install the Guest Additions with the following commands, and reboot.
```console
sudo apt-get install -y dkms build-essential linux-headers-generic linux-headers-$(uname -r)
sudo mkdir /media/cdrom
sudo mount /dev/cdrom /media/cdrom
cd /media/cdrom
sudo ./VBoxLinuxAdditions.run
sudo adduser $USER vboxsf
``` 

Next, install Git and clone the O-RAN-Testbed-Automation repository over HTTPS.
```console
sudo apt-get install -y git
git clone https://github.com/USNISTGOV/O-RAN-Testbed-Automation.git
cd O-RAN-Testbed-Automation
```
Alternatively, you may clone the repository using SSH: `git clone git@github.com:USNISTGOV/O-RAN-Testbed-Automation.git`

---

> _**Recommendation:** Before beginning, increase the file descriptor limits set by the system with the following command, then reboot._
> ```console
> sudo ./Additional_Scripts/increase_file_descriptor_limits.sh
> ```

#

Begin the installation process, recommended to be run as your current user rather than as root:
```console
./full_install.sh
```
> [!TIP]
> Due to `set -e`, the scripts will halt upon encountering an error so that it can be corrected before trying again. Since the scripts are idempotent, only the incomplete steps of the installation process will be executed unless specified otherwise. Please be patient until an error occurs or the testbed installation completes successfully.
```
################################################################################
# Successfully installed the 5G Core, UE, gNodeB, and RIC.                     #
################################################################################
```

After successful installation, verify that the configs/ files are generated for the 5G Core, gNodeB, and UE using `./generate_configurations.sh`. Run the testbed with `./run.sh` to start the 5G Core and gNodeB as background processes, and the UE in the foreground. Use `./is_running.sh` to check if the components are running, and `./stop.sh` to stop the components.

```console
Attaching UE...
Random Access Transmission: prach_occasion=0, preamble_index=0, ra-rnti=0x39, tti=4174
Random Access Complete.     c-rnti=0x4601, ta=0
RRC Connected
PDU Session Establishment successful. IP: 10.45.0.2
RRC NR reconfiguration successful.
```

The RIC starts automatically on boot and can be accessed with `k9s -A`. For more information about a specific component, refer to the README.md files in the respective subdirectories.

## Contact Information

USNISTGOV/O-RAN-Testbed-Automation [[2]][gh-ota] is developed and maintained
by the NIST Wireless Networks Division [[3]][nist-wnd], as part of their 
Open RAN Research Program [[4]][nist-oran].  Contacts for this software:

- Simeon J. Wuthier, @Simewu
- Peng Liu, @pengnist
- Kyehwan Lee, @kyehwanlee
- Fernando J. Cintrón, @fjcintron

## NIST Disclaimers

- #### NIST Software Disclaimer [[5]][gh-nsd]
- #### NIST Commercial Software Disclaimer [[6]][gh-cpd]
- #### Fair Use and Licensing Statements of NIST Data/Works [[7]][gh-license]

## References
1. Liu, Peng, Lee, Kyehwan, Cintrón, Fernando J., Wuthier, Simeon, Savaliya, Bhadresh, Montgomery, Douglas, Rouil, Richard (2024). Blueprint for Deploying 5G O-RAN Testbeds: A Guide to Using Diverse O-RAN Software Stacks. National Institute of Standards and Technology. [https://doi.org/10.6028/NIST.TN.2311][nist-tn]
2. National Institute of Standards and Technology. GitHub. [https://github.com/USNISTGOV/O-RAN-Testbed-Automation][gh-ota]
3. Wireless Networks Division. National Institute of Standards and Technology. [https://www.nist.gov/ctl/Wireless-Networks-Division][nist-wnd]
4. Open RAN Research at NIST. National Institute of Standards and Technology. [https://www.nist.gov/programs-projects/Open-RAN-Research-NIST][nist-oran]
5. NIST Software Disclaimer. [NIST Software Disclaimer.md][gh-nsd]
6. NIST Commercial Software Disclaimer. [NIST Commercial Product Disclaimer.md][gh-cpd]
7. Fair Use and Licensing Statements of NIST Data/Works: [LICENSE][gh-license]

#
<p align="center">
  <a href="https://www.nist.gov" target="_blank">
    <img src="./NIST.png" alt="National Institute of Standards and Technology" width="85%"/>
  </a>
</p>

<!-- References -->

[nist-tn]: https://doi.org/10.6028/NIST.TN.2311
[gh-ota]: https://github.com/USNISTGOV/O-RAN-Testbed-Automation
[nist-wnd]: https://www.nist.gov/ctl/Wireless-Networks-Division
[nist-oran]: https://www.nist.gov/programs-projects/Open-RAN-Research-NIST
[gh-nsd]: ./NIST%20Software%20Disclaimer.md
[gh-cpd]: ./NIST%20Commercial%20Product%20Disclaimer.md
[gh-license]: ./LICENSE

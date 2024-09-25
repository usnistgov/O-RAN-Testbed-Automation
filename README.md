# Open RAN Testbed
An installation guide and scripts to set up a testbed for O-RAN R&D.

## Setting Up on a Virtual Machine

### Operating System
Use an Ubuntu-based operating system. Linux Mint is a great operating system for the testbed.

---
### Virtual Machine Preferences
If using VirtualBox, for optimal user experience consider using the following configuration parameters:
- **System**
  - **Base Memory**: Set the RAM to something reasonable, e.g., 4096 MB or 8192 MB.
  - **Extended Features**: Ensure that `Enable I/O APIC` is checked to improve the handling of interrupts.
  - **Processors**: Between `6 and 8` (Note: To reduce scheduling overhead and improve performance, do not exceed 8 processors).
  - **Extended Features**: Check `Enable PAE/NX` and if possible, also check `Enable Nested VT-x/AMD-V`.
  - **Paravirtualization Interface**: If the host machine is a Mac choose `Default`, if Windows choose `Hyper-V`, and for Linux choose `KVM`.
  - **Hardware Virtualization**: Ensure that `Enabled Nested Paging` is checked.
- **Display**
  - **Video Memory**: Set the slider to the maximum.
<!--
  - **Graphics Controller**: Use `VBoxSVGA` rather than VMSVGA for a more responsive UI when the resources are at capacity.
  - **Extended Features**: Please uncheck `Enable 3D Acceleration` since it is not supported by VBoxSVGA, and the graphics controller will switch back to VMSVGA this option is checked.
-->
- **Storage**
  - If using a SSD hard drive, check the SATA controller's `Solid-state Drive` option.
<!--
- **Audio**
  - Optionally, consider disabling `Enable Audio`.
-->

---
## Installation Guide
The first thing to do before anything else is to run the Update Manager and ensure everything is up-to-date, then reboot.

Next, install the VirtualBox Guest Additions, type the following command into the terminal to make Shared Folders work properly, then reboot:
```
sudo adduser $USER vboxsf
```

Next install Git:
```
sudo apt install -y git
```

Then clone the O-RAN-Testbed repository:
```
cd ~/Desktop
git clone https://github.com/Simewu/O-RAN-Testbed.git
```

Then start the installation process (it is recommended to run it as your current user rather than as root):
```
./full_install.sh
```
Note: Since `set -e` is set, the script will terminate upon reaching an error so that it can be corrected before trying again.
You will then need to wait patiently until you reach an error, or a successful testbed installation:
```
################################################################################
# Successfully installed the 5G Core, gNodeB, UE, and RIC.                     #
################################################################################
```

After successful installation, ensure that the config/ files are generated; they are generated with `./generate_configurations.sh`.

---
### Custom PLMN and TAC Identifiers
To select a different PLMN and TAC ID, modify the contents of `5G_Core/options.yaml`, then apply the changes with:
```
cd 5G_Core
./generate_configurations.sh
./stop.sh
./run.sh
cd ../gNodeB
./generate_configurations.sh
cd ..
```

---
### Installation Guide For Separate Machines
If instead you would like to run the 5G Core, gNodeB, UE, or RIC on a different machine connected to the same network, then you can install each component individually.

Installing the 5G Core Components (MME, SGWC, SMF, AMF, SGWU, UPF, HSS, PCRF, NRF, SCP, AUSF, UDM, PCF, NSSF, BSF, UDR):
```
cd 5G_Core
./full_install.sh
cd ..
```

Installing the gNodeB:
```
cd gNodeB
./full_install.sh
cd ..
```

Installing the UE:
```
cd User_Equipment
./full_install.sh
./generate_configurations.sh
cd ..
```

Installing the RIC:
```
cd RAN_Intelligent_Controller
./full_install.sh
```

Note: If the E2 Terminator (inside the RIC) will be outside of the network, you may need to set `inside_cluster="no"` in gNodeB/generate_configurations.sh, which will use the E2 Terminator port 32222 instead of 36422.

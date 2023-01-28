---
author: Till wegmüller <till.wegmueller@openflowlabs.com>
state: predraft
---

# Abstract
To support native device enumeration on ARM and Risc-V (and others) a Mechanism called device tree
is used next to bus enumeration support like PCI-e or USB. This is used by the Kernel to configure
drivers at boot and runtime if the bus supports runtime changes (Most don't).


# Background and Research
Device tree support is mainly used for configuration of Hardware extensions and GPIO in the Embedded world. SPARC also used to
have a Device Tree support, thus our internal format is at least somewhat similar if not directly an ancestor to the
modern device tree files used in Linux and FreeBSD. Open Firmware Device trees are standardised in IEEE 1275 which later also got 
extended to PPC by IBM and to CHRP by Apple. On SPARC a Device tree blob was placed in the PROM and a partial device tree could be supplied
by Extension baords. 
> In most systems, the CPU's FCode interpreter will store each device's identification information in a device tree that has a node for each device. Each device node has a property list that identifies and describes the device. The property list is created as a result of interpreting the program in the FCode PROM.

On x86 ACPI was used for these tasks. While Arm boards may have some support for UEFI and ACPI nowadays their use is limited and not 
native to the platform and only a Translation layer in the UEFI firmware.

# Purpose
This IPD exists to coordinate further development of our device tree support and thus support a wider range of Devices and their extension cards.


# References
- [Device Tree History](https://elinux.org/images/0/06/ELCE_2019_DeviceTree_Past_Present_Future.pdf)
- [SPARC Device Tree Docs SBus Card and FCode](https://docs.oracle.com/cd/E19957-01/802-3239-10/sbusandfc.html)
- [Raspberry 4 Device Tree Overview](https://blog.stabel.family/raspberry-pi-4-device-tree/)
- [Fediverse Research Thread](https://chaos.social/@Toasterson/109766721243396979)
- [ACPI Wikipedia](https://en.wikipedia.org/wiki/ACPI)
- [DeviceTree.org](https://www.devicetree.org/)
- [U-Boot Driver Model](https://elinux.org/images/c/c4/Order_at_last_-_U-Boot_driver_model_slides_%282%29.pdf)

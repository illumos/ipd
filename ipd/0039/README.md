---
author: Till wegmüller <till.wegmueller@openflowlabs.com>
state: predraft
---

# Abstract
On ARM and many other Platforms the originally OpenFirmware Device tree standard is used to provide information
how to configure drivers. Since this is Originally a Sun Microsystems invention all our basic infrastructure already
exists however over the years PowerPC, ARM, et al have made changes to the file formats and some things are breaking changes.
This IPD's purpose is to Coordinate all work to provide facilities that embedded and non x86 Systems developers expect
from an OS using Device tree. 


# Background and History
Device tree support is mainly used for configuration of Hardware extensions and GPIO in the Embedded world. SPARC also used to
have a Device Tree support, thus our internal format is a directl ancestor to the modern FDT files used in many Platforms and Os's. 
Open Firmware Device trees are standardised in IEEE 1275 which later also got extended to PPC by IBM and to CHRP by Apple. 
On SPARC a Device tree blob was placed in the PROM and a partial device tree could be supplied by Extension baords. 
> In most systems, the CPU's FCode interpreter will store each device's identification information in a device tree that has a node for each device. Each device node has a property list that identifies and describes the device. The property list is created as a result of interpreting the program in the FCode PROM.

On x86 ACPI was used for these tasks. While Arm boards may have some support for UEFI and ACPI nowadays their use is limited and not 
native to the platform and only a Translation layer in the UEFI firmware.

EFI also has Device tree passthrough support since Apple has been using Device trees throughout History on it's ARM devices. Only Intel
Mac's are different there. FreeBSD Loader has Integrated FDT support and overlay support in the default build but hidden behind a flag `make buildworld -DWITH_FDT`.

# What we will need to do
Since we already have most of the plumbing for thing even linux does not have at the moment (Runtime modification) we only need to focus on the details that we need to change.
- *Supplying overlays to the Kernel.* On linux and specifically the Raspberry PI and thus other embedded systems this is done with u-boot assembling the overlayed dtb files at boot into
a flattened and complete tree and passing that to the Kernel. FreeBSD added that functionality to loader but loader also translates the FDT format to the FreeBSD format. //TODO input from tsoome how much is already 
defined/implemented with the new nvlist boot protocol.
- *Driver support* Several drivers that we have generically on or in early boot need to be configured via Device trees (Serial Console/CPU/platform general) it may also result in cases where drivers become more generic
- *Allowing users to modify overlay settings* On the Raspberry PI and other boards a config.txt format can be used as a final kind of overlay that sets some user configurable device settings. This may
be done on runtime but may also end up needing a machnism to configure loader appropriately.
- *Storage of FDT Blobs* While in the old SPARC days Device trees where specifically stored in PROM (or EEPROM) on more modern Systems the Trees are mostly stored on Flash Storage next to the rootfs of the OS.
While the bootloader needs access to those files, since we have FreeBSD loader we can skip putting the overlay files on a FAT32 formated partition. Although we could put it into the EFI System Partition, 
which however would make the ESP also a dependency for every platform that support s Device Tree (PowerPC/ARM/Risc-V). Some Firmware (Raspberry Pi) supplies device trees to the boot loader/OS from ROM but not all Boards do.
- *FDT Binary Format Changes* Over the years the FDT binary format has received changes to what it originally was in 1994. So we will need to include those or switch to libfdt or similar.


# References
- [Device Tree History](https://elinux.org/images/0/06/ELCE_2019_DeviceTree_Past_Present_Future.pdf)
- [SPARC Device Tree Docs SBus Card and FCode](https://docs.oracle.com/cd/E19957-01/802-3239-10/sbusandfc.html)
- [Raspberry 4 Device Tree Overview](https://blog.stabel.family/raspberry-pi-4-device-tree/)
- [Fediverse Research Thread](https://chaos.social/@Toasterson/109766721243396979)
- [ACPI Wikipedia](https://en.wikipedia.org/wiki/ACPI)
- [DeviceTree.org](https://www.devicetree.org/)
- [U-Boot Driver Model](https://elinux.org/images/c/c4/Order_at_last_-_U-Boot_driver_model_slides_%282%29.pdf)
- [Device Tree Specification v0.4-rc1](https://github.com/devicetree-org/devicetree-specification/releases/download/v0.4-rc1/devicetree-specification-v0.4-rc1.pdf)
- [Device Tree Past Present and Future](https://elinux.org/images/0/06/ELCE_2019_DeviceTree_Past_Present_Future.pdf)
- [Kernelovr Docs](https://illumos.org/books/wdd/kernelovr-77198.html#kernelovr-43)
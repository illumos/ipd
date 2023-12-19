---
author: Toomas Soome <tsoome@me.com>, Richard Lowe <richlowe@richlowe.net>, Michael van der Westhuizen <r1mikey@gmail.com>
state: predraft
---

# IPD 24 Support for 64-bit ARM (AArch64)

## Introduction

The ARM/AArch64 platform is gaining momentum, and with a range of systems
available, we should port illumos to ARM/AArch64.

## ABI Details (in no particular order)

_ALL OF THESE DETAILS ARE SUBJECT TO CHANGE AT THE MOMENT_
and the references to draft IPDs don't imply endorsement; we have just come
to the same conclusions for a subset of issues.

- LP64 only, no-multilib
- preprocessor token is `__aarch64__` (the GCC default)
- unsigned characters, as is usual on ARM
- `unix` per-platform, because we lack coherent boot services for early
  console etc.  On ARMSBSA and perhaps other platforms this may be a
  shared `unix` + `platmod`, but not right now.
- platform (`uname -p`) aarch64
- machine (`uname -m`) armv8
- implementation (`uname -i`) per-target board/system/platform
- root nexus name is taken from the implementation as on SPARC and on i86pc/i86xpv.
- kernel search paths `/kernel/.../aarch64`, keeping the ISA directory as on
  other platforms (see [IPD34](../0034/README.md))
- userland search paths `/lib/ /usr/lib`, no ISA directory
- `.../lib/64 -> .`, compatibility for things which use /64/ in runpaths, etc.
  (see [IPD36](../0036/README.md))
- plugin-like search paths, no ISA directories (with the exception that mdb
  keeps them, again, to look more like the other platforms)
- kernel source paths `aarch64` (isa) `armv8` (platform)
  (aarch64 : armv8 :: intel : i86pc)
- no legacy backward compatibility pieces (`libm.so.1`, `libresolv.so.1`,
  `/usr/ucb`, `/usr/has`, etc.)
- thread-local storage [variant 1](https://www.akkadia.org/drepper/tls.pdf)

## Arm SystemReady

[Arm SystemReady](
https://www.arm.com/architecture/system-architectures/systemready-certification-program)
is a certification programme built on hardware and firmware standards that
create an environment where generic operating systems can boot and run on
compliant systems without modification.  Ultimately, the goal of SystemReady is
to create a platform that is competitive with the experience that users have
on x86_64 systems.

The SystemReady-related standards fall into hardware and firmware, with many
supplemental and referenced standards in each category.

SystemReady defines profiles to address the needs of various market segments;
these are:
- [SystemReady SR](
  https://www.arm.com/architecture/system-architectures/systemready-certification-program/sr)
  addresses the server and workstation market, defining evolving levels of
  compliance that keep the certification modern and secure.  The SR branch of
  the programme used to be known as ServerReady.
- [SystemReady ES](
  https://www.arm.com/architecture/system-architectures/systemready-certification-program/es)
  targets the embedded server market and is similar to the SR profile.
  Many commonly available embedded systems would be able to meet the ES
  requirements were it not for firmware and bootloader quirks.
- [SystemReady IR](
  https://www.arm.com/architecture/system-architectures/systemready-certification-program/ir)
  defines a profile for embedded systems, introducing devicetree as a firmware
  configuration table format.  The IR level of certification represents the
  complexity of significant hardware diversity on tailored embedded systems.
- [SystemReady LS](
  https://www.arm.com/architecture/system-architectures/systemready-certification-program/ls)
  specifically targets Hyperscaler environments running Linux and is,
  therefore, of little interest to illumos.

### Target Hardware

SystemReady SR hardware tends to be expensive (think of systems based on SoCs
like Ampere's [Altra Max and AmpereOne](
https://amperecomputing.com/products/processors) and Nvidia's [Grace](
https://www.nvidia.com/en-gb/data-center/grace-cpu/)).  Fortunately, there are
no meaningful differences between the lower SystemReady SR compliance levels
and SystemReady ES.

The port supports, at present, only a basic SystemReady IR profile, with
specific board support for:
- [Raspberry Pi 4](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
  (containing a Broadcom BCM2711 SoC).  This board is the previous Raspberry Pi
  generation but is still widely available.
- Meson GXBB ([Odroid C2](https://www.hardkernel.com/shop/odroid-c2/) or
  similar), based on the [Amlogic S905](
  https://dn.odroid.com/S905/DataSheet/S905_Public_Datasheet_V1.1.4.pdf) SoC.
  This board is obsolete.
- The [Qemu virt](https://qemu-project.gitlab.io/qemu/system/arm/virt.html)
  platform.

To build out support for SystemReady ES, the following hardware could be used:
- [Raspberry Pi 4](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
  with Arm Trusted Firmware and an edk2 UEFI firmware.
  - The Pi 4 has achieved SystemReady ES certification with this firmware.
  - This hardware is relatively cheap and readily available.
- The [Qemu virt](https://qemu-project.gitlab.io/qemu/system/arm/virt.html)
  platform, when run with either PFLASH containig Arm Trusted Firmware and edk2
  UEFI firmwares or a combined "BIOS" firmware containing the same.
- [Honeycomb LX2 Workstation](
  https://www.solid-run.com/arm-servers-networking-platforms/honeycomb-lx2/), a
  mini-ITX board built on the NXP Layerscape [LX2160A](
  https://www.nxp.com/products/processors-and-microcontrollers/arm-processors/layerscape-processors/layerscape-lx2160a-lx2120a-lx2080a-processors:LX2160A)
  SoC.
  - This board has sixteen Cortex A72 cores (four times the number found in the
    Raspberry Pi 4) and significantly better I/O than the Pi 4.
  - The board supports up to 64G of RAM.
  - The SoC contains a GICv3, which the port does not yet support.

To test SystemReady SR support, the only cost-effective option for bringup
activities is the [Qemu sbsa-ref](
https://www.qemu.org/docs/master/system/arm/sbsa.html) platform.

### The Arm Base System Architecture

A base set of hardware support requirements can be extracted from the [Arm Base
System Architecture](https://developer.arm.com/documentation/den0094/)
(BSA) specification. The BSA is a fairly dense document, and you can find a
digestible overview in the [SystemReady Pre-Silicon Reference Guide BSA
integration and compliance](
https://developer.arm.com/documentation/102858/latest/) document.

The BSA describes both the hardware interfaces that a platform must support and
how that hardware should be integrated. From the point of view of a 64-bit
operating system, the following major functional blocks are required:
- A CPU compliant to Armv8.0-A, described in [Arm Architecture Reference
  Manual for A-profile
  architecture](https://developer.arm.com/documentation/ddi0487/latest/).
  - VMSAv8-64 support as per the Arm ARM (this covers the MMU).
  - Generic Timer (Arm Architected Timer) support as per the Arm ARM.  From a
    BSA point of view, the generic timer is further documented in
    [DEN0094](https://developer.arm.com/documentation/den0094/latest/) in
    section 3.8 (Clock and timer subsystem).
- A programmable interrupt controller conforming to the Arm Generic Interrupt
  Controller specification at one of the following specification levels:
  - [GICv2](https://developer.arm.com/documentation/ihi0048/latest/) for
    supporting up to eight CPUs with _no_ PCIe support.
  - GICv2m for supporting up to eight CPUs with PCIe support (MSI/MSIX mapped
    to shared peripheral interrupts).
  - [GICv3](https://developer.arm.com/documentation/ihi0069/latest/) _without_
    the Interrupt Translation Service for support of up to 2<sup>28</sup> CPUs
    with _no_ PCIe support.
  - GICv3 _with_ the Interrupt Translation Service for support of up to
    2<sup>28</sup> CPUs with PCIe support (MSI/MSIX mapped via
    [Locality-Specific Peripheral
    Interrupts](https://developer.arm.com/documentation/102923/latest/).
- A UART conforming to one of the following two specifications:
  - BSA Generic UART as defined in
    [DEN0094](https://developer.arm.com/documentation/den0094/latest/).  A
    PrimeCell UART (PL011) at revision r1p5 complies with the BSA. See
    [DDI0183](https://developer.arm.com/documentation/ddi0183/latest/) for a
    full description of this IP and DEN0094 for the register subset required
    for the Generic UART.
  - A fully
    [16550](https://www.scs.stanford.edu/10wi-cs140/pintos/specs/pc16550d.pdf)
    compatible UART.

The following IP blocks are optional for BSA compliance:
- An IOMMU is required under certain conditions and, when required, must
  conform to one of the following specifications:
  - Arm System Memory Management Unit Architecture Specification - SMMU
    architecture version 2.0, as described by
    [IHI0062](https://developer.arm.com/documentation/ihi0062/latest/).
  - Arm System Memory Management Unit Architecture Specification - SMMU
    architecture version 3, as described by
    [IHI0070](https://developer.arm.com/documentation/ihi0070/latest/).
    - The BSA makes further reference to SMMUv3.2.
- A watchdog as described in
  [DEN0094](https://developer.arm.com/documentation/den0094/latest/) as the
  Generic Watchdog.

#### Hardware Support Summary

| Hardware         | Existing Support | Required    |
| ---------------- | ---------------- | ----------- |
| Armv8.0-A        | Yes              | Yes         |
| Generic Timer    | Yes              | Yes         |
| GICv2/GICv2m     | Partial          | Yes         |
| GICv3/GICv3-ITS  | No               | Yes         |
| Generic UART     | Implicit         | Yes         |
| NS16550 UART     | Yes              | Yes         |
| SMMUv2           | No               | Conditional |
| SMMUv3           | No               | Conditional |
| Generic Watchdog | No               | No          |

### The Arm Server Base System Architecture

The [Arm Server Base System Architecture](
https://developer.arm.com/documentation/den0029/latest/) (SBSA) is a
supplement to the [BSA](
https://developer.arm.com/documentation/den0094/latest/), defining levels of
compliance and refining the requirements of the Base System Architecture
(essentially making the BSA stricter and more modern at higher compliance
levels).

While the illumos Arm port is in its infancy, there are no additional
requirements on the operating system imposed by the SBSA.  As this work
matures, we may want to support hardware features described at higher
conformance levels, such as RAS extensions.

## Arm Base Boot Requirements

The [Arm Base Boot Requirements](
https://developer.arm.com/documentation/den0044/) describe firmware and
bootloader requirements as applied to Arm systems.  Similarly to SystemReady
itself, the BBR defines recipes for types of firmware support:
- SBBR for server-class systems
  - UEFI as a bootloader and provider of runtime services
  - ACPI for system description
  - SMBIOS for systems management data
- [EBBR](https://github.com/ARM-software/ebbr/releases) for embedded systems
  - UEFI 2.10 as a bootloader and provider of runtime services
  - Either (but not both):
    - ACPI for system description
    - Devicetree for system description
  - When devicetree is used for system description, _/chosen/stdout-path_ is
    required.
  - All UEFI Runtime Servies are optional.
    - Specifically, _GetTime_ and _SetTime_ might not be implemented after
      _ExitBootServices_ when their bus accesses might conflict with the
      operating system.
    - _ResetSystem_ is optional. When present, it should be used. When not
      present, the operating system should fall back to [PSCI](
      https://developer.arm.com/documentation/den0022/latest/).
- LBBR for LinuxBoot-based systems
  - Not relevant to illumos

The Embedded Base Boot Requirements suggest that firmware could offer the user
(or integrator) the choice of ACPI and devicetree.

## Boot protocol

The illumos kernel on x86 platform is started using the Multiboot 2 (default)
or Multiboot 1 (compatibility) protocol. The multiboot protocol provides data
structures which pass various information to the kernel, but it seems to be
x86 centric.

At present the port boots via bespoke booter derived from `inetboot` by
[Hayashi Naoyuki](https://github.com/n-hys), and delivered per target
platform.

As part of UEFI and ACPI exploration, the illumos UEFI loader has been [ported
to aarch64](
https://github.com/r1mikey/illumos-gate/commit/be9a9ee13d660819202677b912dee60cb3b38613)
(tested on the Qemu sbsa-ref board) and works with minimal architecture changes.
This work is minimally usable but makes expedient decisions around how to boot
that have not been widely discussed.

## References

* [Hayashi Naoyuki's Original Port](https://github.com/n-hys/illumos-gate/wiki)
* [ARM Developer Documentation](https://developer.arm.com/documentation/#sort=relevancy&f:@navigationhierarchiesproducts=[Architectures,CPU%20Architecture,A-Profile,Armv8-A])
* [Multiboot2 Specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)
* [IPD 34 Rationalize Kernel Architecture Module Paths](../0034/README.md)
* [IPD 36 Rationalize $(MACH64) Command Paths](../0036/README.md)
* [ELF Handling For Thread-Local Storage](https://www.akkadia.org/drepper/tls.pdf)
* [DEN0094](https://developer.arm.com/documentation/den0094/): Arm Base System
  Architecture
* [DEN0029](https://developer.arm.com/documentation/den0029/): Arm Server Base
  System Architecture
* [DEN0044](https://developer.arm.com/documentation/den0044/): Arm Base Boot
  Requirements
* [EBBR](https://github.com/ARM-software/ebbr/releases): Embedded Base Boot
  Requirements Specification
* [DEN0107](https://developer.arm.com/documentation/den0107/): Base Boot
  Security Requirements
* [DEN0069](https://developer.arm.com/documentation/den0069/): Arm Server Base
  Manageability Requirements
* [DEN0028](https://developer.arm.com/documentation/den0028/): SMC Calling
  Convention (SMCCC)
* [DEN0022](https://developer.arm.com/documentation/den0022/): Arm Power State
  Coordination Interface
* [DEN0054](https://developer.arm.com/documentation/den0054/): Software
  Delegated Exception Interface (SDEI)
* [DEN0115](https://developer.arm.com/documentation/den0115/): Arm PCI
  Configuration Space Access Firmware Interface
* [DDI0487](https://developer.arm.com/documentation/ddi0487/): Arm Architecture
  Reference Manual for A-profile architecture
* [IHI0048](https://developer.arm.com/documentation/ihi0048/): ARM Generic
  Interrupt Controller Architecture version 2.0
* [IHI0069](https://developer.arm.com/documentation/ihi0069/): Arm Generic
  Interrupt Controller Architecture Specification, GIC architecture version 3
  and version 4
* [DDI0183](https://developer.arm.com/documentation/ddi0183/): PrimeCell UART
  (PL011) Technical Reference Manual
* [IHI0062](https://developer.arm.com/documentation/ihi0062/): ARM System
  Memory Management Unit Architecture Specification - SMMU architecture
  version 2.0
* [IHI0070](https://developer.arm.com/documentation/ihi0070/): Arm System
  Memory Management Unit Architecture Specification - SMMU architecture
  version 3
* [PC16550D](
  https://www.scs.stanford.edu/10wi-cs140/pintos/specs/pc16550d.pdf): Universal
  Asynchronous Receiver/Transmitter with FIFOs
* [SMBIOS](https://www.dmtf.org/standards/smbios): System Management BIOS
* [ACPI](https://uefi.org/specifications) Specification
* The [Devicetree](https://www.devicetree.org) Specification
* [UEFI](https://uefi.org/specifications) Specification
* [Booting AArch64 Linux](
  https://www.kernel.org/doc/html/latest/arch/arm64/booting.html) - specifically
  the spin table format and interactions

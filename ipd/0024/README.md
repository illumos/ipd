---
author: Toomas Soome <tsoome@me.com>
state: predraft
---

# IPD 24 Support for 64-bit ARM

## Introduction

arm64 platform is gaining momentum and with range of systems available, we should port illumos to arm64.

## Prerequisites

Platform and architecture related names?

* `MACH=` ?
* `MACH32=` ?
* `MACH64=` ?
* `SI_ARCHITECTURE=arm` ?
* `SI_ARCHITECTURE_64=arm64` ?
* `SI_PLATFORM=` ?

## Boot protocol

illumos kernel on x86 platform is started using Multiboot2 (default) or Multiboot1 (compatibility) protocol. Multiboot protocol is providing data structures to pass various information to kernel, but it seems to be x86 centric. 

## References

* [The OpenSolaris Porting Project](https://github.com/n-hys/illumos-gate/wiki)
  (Hayashi Naoyuki)
* [ARM Developer Documentation](https://developer.arm.com/documentation/#sort=relevancy&f:@navigationhierarchiesproducts=[Architectures,CPU%20Architecture,A-Profile,Armv8-A])
* [Multiboot2 Specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)

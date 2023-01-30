---
author: Toomas Soome <tsoome@me.com>, Richard Lowe <richlowe@richlowe.net>
state: predraft
---

# IPD 24 Support for 64-bit ARM (AArch64)

## Introduction

The ARM/AArch64 platform is gaining momentum and with range of systems available, we
should port illumos to ARM/AArch64.

## ABI Details (in no particular order)

_ALL OF THESE DETAILS ARE SUBJECT TO CHANGE AT THE MOMENT_
and the references to draft IPDs don't imply endorsement, we have just come
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
- kernel search paths `/kernel/.../aarch64` as on other platforms
  (see [IPD34](../0034/README.md))
- userland search paths `/lib/ /usr/lib`
- `.../lib/64 -> .`
  (see [IPD36](../0036/README.md))
- plugin-like search paths _XXX UNDECIDED_
- kernel source paths `aarch64` (isa) `armv8` (platform)
  (aarch64 : armv8 :: intel : i86pc)
- no legacy backward compatibility pieces (`libm.so.1`, `libresolv.so.1`,
  `/usr/ucb`, `/usr/has`)
- thread-local storage [variant 1](https://www.akkadia.org/drepper/tls.pdf)

## Boot protocol

The illumos kernel on x86 platform is started using the Multiboot 2 (default)
or Multiboot 1 (compatibility) protocol. The multiboot protocol provides data
structures which pass various information to the kernel, but it seems to be
x86 centric.

At present the port boots via bespoke booter derived from `inetboot` by
[Hayashi Naoyuki](https://github.com/n-hys), and delivered per target
platform.

## References

* [Hayashi Naoyuki's Original Port](https://github.com/n-hys/illumos-gate/wiki)
* [ARM Developer Documentation](https://developer.arm.com/documentation/#sort=relevancy&f:@navigationhierarchiesproducts=[Architectures,CPU%20Architecture,A-Profile,Armv8-A])
* [Multiboot2 Specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)
* [IPD 34 Rationalize Kernel Architecture Module Paths](../0034/README.md)
* [IPD 36 Rationalize $(MACH64) Command Paths](../0036/README.md)
* [ELF Handling For Thread-Local Storage](https://www.akkadia.org/drepper/tls.pdf)

---
authors: Joshua M. Clulow <josh@sysmgr.org>, Andy Fiddaman <illumos@fiddaman.net>
state: draft
---

# IPD 23 Xen and the Art of Operating System Maintenance: A Removal of a Platform

## Goal

Reduce maintenance burden and allow clean-up by removing special cases for the
`i86xpv` platform.  This platform exists solely to allow illumos to operate as
a Xen paravirtualised guest, which is made effectively obsolete by
hardware-assisted virtualisation features in modern CPUs; "hardware virtual
machine" or HVM in Xen parlance.

## Background

When the [Xen hypervisor](https://en.wikipedia.org/wiki/Xen) was first
released, x86 CPUs did not provide hardware-assisted virtualisation features.
In order to provide both isolation and reasonable performance on these CPUs,
Xen provided a "paravirtualised" platform; i.e., one where the guest operating
system must be modified to work.

The `i86xpv` platform in illumos is a modification of the mainstream x86
platform (`i86pc`) that operates as a paravirtualised Xen guest.  Because of
the kind of modifications required, most of the code is common with `i86pc`,
except for a soup of `#ifdef` and other conditional code.  A coarse estimate
suggests many points of modification in both the `i86pc` platform code,
and the `intel` architecture-level code:

```
$ grep -lr '#if.*def.*xpv' uts/intel | wc -l
28
$ grep -rc '#if.*def.*xpv' uts/intel | awk -F: '{ q += $NF; } END { print q }'
125

$ grep -lr '#if.*def.*xpv' uts/i86pc | wc -l
63
$ grep -rc '#if.*def.*xpv' uts/i86pc | awk -F: '{ q += $NF; } END { print q }'
458
```

These modifications are often present in parts of the code that are complex,
and already challenging to maintain, such as in the virtual memory subsystem
and early boot code.

This code is largely unmaintained, because guest modification for
paravirtualisation has not been necessary under Xen for many years.  AWS was
probably the most commercially relevant venue for Xen paravirtualisation, and
they have long since replaced it:

* first with Xen HVM, which uses some of the original Xen drivers but on the
  `i86pc` platform; this covers instance types like T2, M4, etc.
* then later with KVM and the Nitro platform; this covers newer instance types
  like T3, etc.

Removing this platform is, in many senses, analogous to removing the 32-bit x86
kernel: it presents a maintenance burden for mainstream 64-bit x86 work,
without seeing any serious deployment in the field.

## Proposal

Care must be taken to preserve drivers that are still useful in Xen HVM guests
such as those available in AWS EC2.  These drivers are built under
`uts/i86pc/i86hvm`, and a partial list appears below:

* `xpv`, a support driver for operating under Xen HVM
* `xpvd`, the "virtual device nexus driver", which enumerates PV devices
* `xdf`, the Xen block device driver
* `xnf`, the Xen ethernet device driver
* `hvm_bootstrap`, a misc module that configures the `xdf` and `xnf` devices
  early in boot so that the root file system and a network boot interface can
  be found

The source for these drivers should be relocated from its present split of
locations (`uts/common/xen`, `uts/i86xpv` and `uts/i86pc/i86hvm`) into
`uts/i86pc/io/xen`.  The module builds for the relevant modules will be moved
to the top level of `uts/i86pc`, as with other drivers.  They cannot move to
`uts/intel`, as with `vioblk` and `vioif`, because `xpv` depends on the
`i86pc`-specific `pcplusmp` module.  The headers that the drivers share with
the `i86xpv` platform, `xen_mmu.h` and `evtchn_impl.h`, will move to
`uts/common/xen/sys`.

Once these drivers are moved aside, we should remove the rest of the
`uts/i86xpv` tree altogether, and anything else that builds software specific
to the `i86xpv` platform.  This includes:

* the `i86xpv` kernel and its platform modules
* the paravirtualised-only source in `uts/common/xen`, such as the dom0 back
  end drivers
* the `xVM` userland in `cmd/xvm`, the `devfsadm` Xen link module, and the
  hypervisor boot entry support in `bootadm`
* the `i86xpv` `mdb` modules, and the `mdb_kb` backend used to read `i86xpv`
  crash dumps
* the `#ifdef __xpv` conditional code in the `i86pc` and `intel` trees, along
  with run-time checks for the `i86xpv` platform elsewhere

### Xen HVM `cmdk` and `rtls` stub drivers

An unfortunate historical decision in Xen means that block devices are often
exposed concurrently via two separate storage controller interfaces: an
emulated PCI IDE controller, and the Xen `xdf` device.  To prevent confusion,
we must not try to access the disks via IDE, preferring `xdf`.  The same
applies to networking, where Xen may expose an emulated Realtek RTL8139 NIC,
driven by `rtls`, alongside the `xnf` device.

PCI IDE devices on illumos involve several drivers.  During PCI enumeration,
an IDE class device that doesn't match any entry in `/etc/driver_aliases` is
given the node name `pci-ide`, and the `pci-ide` nexus driver binds to it.  The
`ata` driver attaches below that, and in turn uses `cmdk`, the ATA disk
driver, to attach child nodes for detected disks, and `sd` for ATAPI devices
such as CD-ROM drives.

#### The `i86hvm` semi-platform today

To prevent `cmdk` and `rtls` from attaching on Xen HVM systems, we have
invented the fiction of an "`i86hvm` semi-platform".  It works by shadowing
modules on the kernel module search path:

* The Xen modules (`xpv`, `xpvd`, `xdf`, `xnf` and `hvm_bootstrap`), their
  driver configuration files, and stub `cmdk` and `rtls` modules are
  only delivered under `/platform/i86hvm/kernel`.
* Early in boot, `startup_modules()` checks `get_hwenv()` and, if it reports
  `HW_XEN_HVM`, prepends `/platform/i86hvm/kernel` to the module search path.
* `krtld` loads the first module with a given name that it finds on the
  search path, so on Xen HVM the stubs are loaded in place of the real `cmdk`
  and `rtls` drivers in `/kernel/drv`.  The `cmdk` stub's attach entry point
  succeeds without doing anything, so the emulated disk is claimed by a
  driver that creates no minor nodes.  The `rtls` stub has no attach entry
  point, so the emulated NIC is left unattached.
* On other systems, `/platform/i86hvm` is not on the search path, so neither
  the Xen drivers nor their configuration files are found.  In particular,
  the `xpvd` root nexus node that `xpvd.conf` creates does not exist.
* `rootconf()` calls `hvmboot_rootconf()` through a module stub.  On Xen HVM
  this loads `hvm_bootstrap`, which configures the `xdf` and `xnf` nodes
  before the root file system is mounted.  On other systems the module cannot
  be found and the stub returns 0.

#### Replacing the semi-platform

Once the drivers are delivered under `/platform/i86pc`, there will be nothing
left to shadow and the search path change will be removed.  The Xen modules
will then be present on every `i86pc` system, so they must do nothing outside
Xen HVM.  `hvm_bootstrap` will return immediately, and `xpvd` will fail to
attach, unless `get_hwenv()` reports `HW_XEN_HVM`.

The `/boot/solaris/devicedb/master` database, which was used to register
`pci-ide`, no longer exists.  An alias in `/etc/driver_aliases` can claim an
IDE controller ahead of `pci-ide`.  In an AWS guest, we can see the PCI device
has these aliases:

* `pci8086,7010.5853.1.0`
* `pci8086,7010.5853.1`
* `pci5853,1,s`
* `pci5853,1`
* `pci8086,7010.0`
* `pci8086,7010,p`
* `pci8086,...7010`
* `pciclass,010180`
* `pciclass,0101`

It would, as is becoming a theme, regrettably seem that _every_ PCI device Xen
exposes has the same subsystem ID, `0001`.  Fortunately, `pci8086,7010.5853.1`
would represent the combination of Xen and (emulated) 82371SB PIIX3 IDE, and
we could bind a stub driver to that.  Alternatively, `pci-ide` could refuse to
enumerate devices when Xen is the vendor.

Both of these approaches remove the whole IDE controller, so an emulated
ATAPI CD-ROM drive, which attaches through `ata` and `sd`, would disappear
along with the disks.  A stub bound to the subsystem ID also depends on the
device model that a particular Xen deployment presents, and others, such as
upstream QEMU, may not use the same IDs.

Instead, `cmdk` will decline to probe, and `rtls` will decline to attach,
when `get_hwenv()` reports `HW_XEN_HVM`.  `pci-ide` and `ata` will continue to
attach, so emulated ATAPI devices remain available through `sd`, while the
disks are reachable only through `xdf`.

Without the stubs, the rest of the "semi-platform" can be collapsed into
`i86pc` without further issues.

## Related Tickets

* [14628 ancient devicedb should be removed](https://www.illumos.org/issues/14628)
* [18574 Xen HVM paravirtual drivers should move into i86pc](https://www.illumos.org/issues/18574)

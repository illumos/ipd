---
authors: Joshua M. Clulow <josh@sysmgr.org>
state: predraft
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
25
$ grep -rc '#if.*def.*xpv' uts/intel | awk -F: '{ q += $NF; } END { print q }'
105

$ grep -lr '#if.*def.*xpv' uts/i86pc | wc -l
67
$ grep -rc '#if.*def.*xpv' uts/i86pc | awk -F: '{ q += $NF; } END { print q }'
496
```

These modifications are often present in parts of the code that are complex,
and already challenging to maintain, such as in the virtual memory subsystem
and early boot code.

This code is largely unmaintained, because guest modification for
paravirtualisation has not been necessary under Xen for many years.  AWS was
probably the most commercially relevent venue for Xen paravirtualisation, and
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

The source for these drivers should be relocated from its present split of
locations (`uts/i86xpv` and `uts/i86pc/i86hvm`) into `uts/i86pc/io/xen`.  The
module builds for the relevant modules should be moved to either the top level
of `uts/i86pc`, as with other drivers, or possibly even to `uts/intel`, as with
`vioblk` and `vioif`.

Once these drivers are moved aside, we should remove the rest of the
`uts/i86xpv` tree altogether, and anything else that builds software specific
to the `i86xpv` platform.

### Xen HVM `cmdk` stub driver

An unfortunate historical decision in Xen means that block devices are often
exposed concurrently via two separate storage controller interfaces: an
emulated PCI IDE controller, and the Xen `xdf` device.  To prevent confusion,
we must not try to access the disks via IDE, preferring `xdf`.

PCI IDE devices on illumos involve several drivers: at the top, the `pci-ide`
nexus binds to the `pciclass,0101` alias.  That driver then uses `cmdk`, the
ATA disk driver, to attach child nodes for detected disks.

To prevent `cmdk` from attaching on Xen HVM systems, we have invented the
fiction of an "`i86hvm` semi-platform".  A stub module that does nothing is
delivered as `/platform/i86hvm/kernel/drv/amd64/cmdk` and it would appear we
prefer modules in `/platform/i86hvm` to `/platform/i86pc` on Xen HVM.

Another historical wart is that we do not appear to register `pci-ide` through
`/etc/driver_aliases`, but rather through the obscure and outdated
`/boot/solaris/devicedb/master` database.  This should likely be corrected
first.  Then, we can either modify `pci-ide` to ignore Xen devices, or provide
a HVM-specific stub device that will attach to a Xen-specific alias.

In an AWS guest, we can see the PCI device has these aliases:

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
we could bind a stub driver to that.

Alternatively, `pci-ide` could refuse to enumerate devices when Xen is the
vendor.

Other than `cmdk` stub shenanigans, the rest of the "semi-platform" can likely
be collapsed into `i86pc` without further issues.

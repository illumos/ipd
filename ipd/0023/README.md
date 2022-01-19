---
authors: Joshua M. Clulow <josh@sysmgr.org>
state: predraft
---

# Xen and the Art of Operating System Maintenance: A Removal of a Platform

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

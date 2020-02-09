---
author: Andy Fiddaman, Hans Rosenfeld
state: predraft
---

# IPD 15 bhyve integration/upstream

## Introduction

bhyve, pronounced beehive, is a hypervisor/virtual machine manager that
supports most processors which have hardware virtualisation support.

bhyve was originally integrated into FreeBSD by NetApp in around 2011 where it
became part of the base system with FreeBSD 10.0-RELEASE. It continued to
evolve and was ported to illumos by Pluribus Networks in around 2013 and they
contributed the resulting code to the illumos community in late 2017. From
there, Joyent worked on integrating bhyve into their illumos fork, bringing it
up-to-date with bhyve from FreeBSD-11.1 and making many improvements along the
way.

Some slides on Joyent's work in this area were presented
[at bhyvecon 2018](https://www.youtube.com/watch?v=90ihmO281GE)

bhyve has also been successfully side-ported from SmartOS into OmniOS and has
been available there since release r151028 (November 2018).

This IPD is for discussion around upstreaming bhyve to illumos-gate.

## Approach

As part of their porting effort, the OmniOS developers tagged the relevant
commits that were taken from SmartOS. This means that it is relatively
easy to identify the commits that need to be considered as part of the
upstreaming work, and it will be possible to compare the resulting branches
with both SmartOS and OmniOS. OmniOS is closer to gate which will help in
finding any conflicts or missing pieces.

It is proposed to upstream code in several phases:

1. Bhyve pre-requisites
1. Bhyve (driver and userland component)
1. Viona pre-requisites
1. Viona driver
1. PCI Pass-through support
1. MDB support
1. Bhyve zone brand (TBC)

Hans has been working on collating the list of required commits from and the
current state of play is available at
https://us-east.manta.joyent.com/hrosenfeld/public/bhyve.html

## 1. Bhyve pre-requisites

There are a number of SmartOS features and changes which are necessary to
support bhyve. At the time of writing, 10 have been identified which are
self-contained and can be integrated independently. When integrated,
not all will have any current consumers but they lay the groundwork for
the next phase.

Note - some of the text here is taken directly from the associated Joyent
issue.

1. sdev plugin framework

   This is a generic sdev (/dev) plugin framework from Joyent, part of their
   Bardiche/vnd networking project that has not been upstreamed. We need this
   for bhyve since it uses a dynamic sdev plugin to manage entries within
   /dev/vmm/

1. [OS-6549](https://smartos.org/bugview/OS-6549) vmm segment driver

   Applications such as the coming bhyve will want userspace access to the
   regions of kmem allocated to be the guest memory. While seg_umap exists to
   achieve a similar purpose, it was designed to be very constrained (a single
   page) in its capabilities. Rather than updating that for now, a new segment
   driver with lessened restrictions could be created.

1. [OS-6627](https://smartos.org/bugview/OS-6627) increase get_max_pages

   This increases the maximum pages that can be retrieved in order to allow
   virtual machines to consume a significant portion of the system's memory.

1. [OS-6688](https://smartos.org/bugview/OS-6688) combine misc_link_i386 handlers

   Several handlers in usr/src/cmd/devfsadm/i386/misc_link_i386.c are
   essentially the same: they name their /dev/ entry after the minor name. In
   preparation for some new bhyve entries, let's use common code for these.

1. [OS-6633](https://smartos.org/bugview/OS-6633) add cyclic_move_here()

   When they are initially created, cyclics are generally placed on the cpu
   which was running the thread which allocated them. Reprogramming operations
   for the cyclic result in cross-call-like behavior when performed from other
   CPUs. This is fine for many cases, but certain applications may wish to
   localize that cyclic for better reprogramming performance.

1. [OS-6684](https://smartos.org/bugview/OS-6684) cyclic reprogramming can race with removal

   Bug fix for cyclic reprogramming

1. [OS-7034](https://smartos.org/bugview/OS-7034) ctxops should use stack ordering for save/restore

   bhyve uses ctxop functions to ensure that guest FPU state is maintained on
   the CPU when the thread is running (and is properly stashed when a context
   switch occurs. In the past (prior to bhyve and eagerFPU, especially) there
   weren't ordering constraints between ctxop handlers, since they were largely
   independent of one another. Bhyve makes the case that now, they should be
   associated with the thread in such a way that allows stack-like traversal for
   savectx/restorectx. That is: most-&gt;least recent for save,
   least-&gt;most recent for restore.

1. [OS-7096](https://smartos.org/bugview/OS-7096) installctx needs kpreempt_disable protection

   Fix race in ctxops

1. [OS-7104](https://smartos.org/bugview/OS-7104) export hrtime params for pvclock impls

   There is an associated commit for KVM that goes along with this.
   Any distribution using KVM will need to consider this in conjunction with the
   update to gate.

1. Add HMA framework

   Add a hypervisor management framework to allow KVM and bhyve to co-exist.

   This will require distributions to make concurrent changes to KVM and
   Virtualbox if they ship them.

## 2. Bhyve (driver and userland component)

With the pre-requisites in place, the main bhyve component can be integrated.
At this point it will be usable from the global zone.

## 3. Viona pre-requisites
## 4. Viona driver

The accelerated viona network driver for bhyve will be integrated separately.
Stand-alone pre-requisites first (there are currently 11 identified
pre-requisites) followed by the driver itself.

## 5. PCI Pass-through support

Support for passing PCI devices through to Bhyve guests.

## 6. MDB support

Add bhyve target support to mdb.

## 7. Bhyve zone brand

A zone brand for deploying bhyve VMs in non-global zones.

To be confirmed...

SmartOS and OmniOS each have a bhyve zone brand, but they are not the same.
If a brand is upstreamed to gate, it is likely to be based on a combination of
the two.


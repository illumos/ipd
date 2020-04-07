---
author: Andy Fiddaman, Hans Rosenfeld, Patrick Mooney
state: draft
mail: https://illumos.topicbox.com/groups/developer/Tcc767c8497fb4c78/ipd-15-bhyve-integration-upstreaming
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
2. Bhyve (driver and userland component)
3. Viona pre-requisites
4. Viona driver
5. PCI Pass-through support
6. MDB support
7. Bhyve zone brand (TBC)

Hans has been working on collating the list of required commits from and the
current state of play is available at
https://us-east.manta.joyent.com/hrosenfeld/public/bhyve.html

### 1. Bhyve pre-requisites

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

2. [OS-6549](https://smartos.org/bugview/OS-6549) vmm segment driver

   Applications such as the coming bhyve will want userspace access to the
   regions of kmem allocated to be the guest memory. While `seg_umap` exists to
   achieve a similar purpose, it was designed to be very constrained (a single
   page) in its capabilities. Rather than updating that for now, a new segment
   driver with lessened restrictions could be created.

3. [OS-6627](https://smartos.org/bugview/OS-6627) increase `get_max_pages`

   This increases the maximum pages that can be retrieved in order to allow
   virtual machines to consume a significant portion of the system's memory.

4. [OS-6688](https://smartos.org/bugview/OS-6688) combine `misc_link_i386` handlers

   Several handlers in usr/src/cmd/devfsadm/i386/misc\_link\_i386.c are
   essentially the same: they name their /dev/ entry after the minor name. In
   preparation for some new bhyve entries, let's use common code for these.

5. [OS-6633](https://smartos.org/bugview/OS-6633) add `cyclic_move_here()`

   When they are initially created, cyclics are generally placed on the cpu
   which was running the thread which allocated them. Reprogramming operations
   for the cyclic result in cross-call-like behavior when performed from other
   CPUs. This is fine for many cases, but certain applications may wish to
   localize that cyclic for better reprogramming performance.

6. [OS-6684](https://smartos.org/bugview/OS-6684) cyclic reprogramming can race with removal

   Bug fix for cyclic reprogramming

7. [OS-7034](https://smartos.org/bugview/OS-7034) ctxops should use stack ordering for save/restore

   bhyve uses ctxop functions to ensure that guest FPU state is maintained on
   the CPU when the thread is running (and is properly stashed when a context
   switch occurs. In the past (prior to bhyve and eagerFPU, especially) there
   weren't ordering constraints between ctxop handlers, since they were largely
   independent of one another. Bhyve makes the case that now, they should be
   associated with the thread in such a way that allows stack-like traversal for
   savectx/restorectx. That is: most-&gt;least recent for save,
   least-&gt;most recent for restore.

8. [OS-7096](https://smartos.org/bugview/OS-7096) `installctx` needs `kpreempt_disable` protection

   Fix race in ctxops

9. [OS-7104](https://smartos.org/bugview/OS-7104) export hrtime params for pvclock impls

   There is an associated commit for KVM that goes along with this.
   Any distribution using KVM will need to consider this in conjunction with the
   update to gate.

10. Add HMA framework

    Add a hypervisor management framework to allow KVM and bhyve to co-exist.

    This will require distributions to make concurrent changes to KVM and
    Virtualbox if they ship them.

### 2. Bhyve (driver and userland component)

With the pre-requisites in place, the main bhyve component can be integrated.
To allow proper attribution we'll do this in two changesets:

1. [OS-6409](https://smartos.org/bugview/OS-6409) import Pluribus bhyve port

   This is the original code drop that Joyent received from Pluribus Networks, Inc.
   It is not wired up for build or any checks, it's essentially dead code without
   the following commit.

2. Everything else that is currently in the branch
   [bhyve/bhyve](https://github.com/hrosenfeld/illumos-gate/commits/bhyve/bhyve),
   squashed together as one big commit.

   This will update bhyve to the state of illumos-joyent as of late January
   2020. It will be wired up for building and packaging. At this point it will
   be usable from the global zone.


### 3. Viona pre-requisites

The accelerated viona network driver for bhyve does have a few prerequisites,
too. They can all be found in the branch
[bhyve/viona-prereq](https://github.com/hrosenfeld/illumos-gate/commits/bhyve/viona-prereq).

1. [OS-6761](https://smartos.org/bugview/OS-6761) hcksum routines are too verbose\
   [OS-6762](https://smartos.org/bugview/OS-6762) want `mac_hcksum_clone` function
2. [OS-4600](https://smartos.org/bugview/OS-4600) vnd can receive packets without checksums
3. [OS-7727](https://smartos.org/bugview/OS-7727) want mac rx barrier function
4. [OS-5845](https://smartos.org/bugview/OS-5845) lx aio performance improvements and move into kernel
5. [OS-2340](https://smartos.org/bugview/OS-2340) vnics should support LSO\
   [OS-6778](https://smartos.org/bugview/OS-6778) MAC loopback traffic should avoid cksum work\
   [OS-6794](https://smartos.org/bugview/OS-6794) want LSO support in viona\
   [OS-7319](https://smartos.org/bugview/OS-7319) dangling ref in `mac_sw_cksum()`\
   [OS-7331](https://smartos.org/bugview/OS-7331) `mac_sw_cksum()` drops valid UDP traffic
6. [OS-7556](https://smartos.org/bugview/OS-7556) IPv6 packets dropped after crossing MAC-loopback
7. [OS-7564](https://smartos.org/bugview/OS-7564) panic in `mac_hw_emul()`
8. [OS-7520](https://smartos.org/bugview/OS-7520) OS-6778 broke IPv4 forwarding\
   [OS-6878](https://smartos.org/bugview/OS-6878) `mac_fix_cksum` is incomplete\
   [OS-7806](https://smartos.org/bugview/OS-7806) cannot move link from NGZ to GZ
9. [OS-7924](https://smartos.org/bugview/OS-7924) OS-7520 regressed some instances of IP forwarding
10. [OS-8027](https://smartos.org/bugview/OS-8027) reinstate mac-loopback hardware emulation on Tx (undo OS-6778)
11. [OS-7904](https://smartos.org/bugview/OS-7904) simnet has bogus `mi_tx_cksum_flags`\
   [OS-7905](https://smartos.org/bugview/OS-7905) `mac_tx()` is too eager to emulate hardware offloads

The first four changes can be upstreamed independently. The individual changes
beginning at OS-2340 and ending at OS-8027 need to be squashed and upstreamed
as one change, the initial work caused issues that were fixed or partially
backed out in later commits. The remaining commit for OS-7904 and OS-7905 seems
to depend on those changes, even if only to avoid merge conflicts.

### 4. Viona driver

The accelerated viona network driver for bhyve will be integrated separately.
The changes in the branch
[bhyve/viona](https://github.com/hrosenfeld/illumos-gate/commits/bhyve/viona)
will be squashed into one commit with Patrick Mooney set as the author.
All other contributors will be listed in the commit message.

### 5. PCI Pass-through support

Support for passing PCI devices through to Bhyve guests. The changes in the
branch [bhyve/passthru](https://github.com/hrosenfeld/illumos-gate/commits/bhyve/passthru)
will be squashed into one commit with Hans Rosenfeld as the author. All other
contributors will be listed in the commit message.

### 6. MDB support

Add bhyve target support to mdb. The changes in the branch
[bhyve/mdb-bhyve](https://github.com/hrosenfeld/illumos-gate/commits/bhyve/mdb-bhyve)
will be squashed into one commit with Hans Rosenfeld as the author. All other
contributors will be listed in the commit message.

### 7. Bhyve zone brand

A zone brand for deploying bhyve VMs in non-global zones.

SmartOS and OmniOS each have a bhyve zone brand, but they are not the same.
If a brand is upstreamed to gate, it is likely to be based on the OmniOS one,
perhaps with useful additions from SmartOS.


## Additional components

Unlike FreeBSD, where a specialized loader (bhyveload) is able to boot FreeBSD
guests directly, bhyve on illumos typically makes use of a boot ROM for initial
VM start-up and loading of the guest bootloader/OS.  There is a bhyve-specific
fork of the uefi-edk2 repository bearing the necessary patches to make it
functional under the hvm environment.  For now, it will be left up to the
downstream distributions to decide on how (if at all) they wish to build and
ship such a ROM.  (Integrating that build process into smartos-live proved to be
a challenge at Joyent, so the boot ROM artifacts were periodically built "by
hand" and stashed as binaries in the repository.)

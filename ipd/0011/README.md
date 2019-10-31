---
author: Dan McDonald
state: predraft
---

# IPD 11 NFS Server for Zones (NFS-Zone)

## Introduction

Currently the Network File System (NFS) server can only be instantiated in
the global zone.  This document describes how NFS will be able to instantiate
in any non-global zone.  This document assumes the reader has some
understanding of NFS.

## History and Fundamentals

Before Oracle closed OpenSolaris, there was a work-in-progress to solve this
problem.  Unfortunately, even a larval version of it did not escape into the
open-source world.  Post-illumos, multiple attempts tried to make NFS service
in a zone (abbreviated to NFS-Zone for the rest of this document).

One distro, NexentaStor, managed to implement a version in their child of
illumos.  This work from Nexenta forms the basis for what is planned to be
brought to illumos-gate.

Prior to this project, NFS instantiated its state assuming it would only run
in the global zone.  This state covers three different modules: `nfssrv` (the
NFS server kernel module), `klmmod` (kernel lock manager module), and
`sharefs` (the kernel "sharetab" filesystem).

### NFS Server State

A majority of the NFS server state can be instantiated into Zone-Specific
Data (ZSD).  Earlier implementations instantiated ZSD for each of:

- NFS Export Table (`nfs_export_t`)

- NFS server instances for common (`struct nfs_srv`), NFSv3 (`struct
  nfs3_srv`), and NFSv4 (`struct nfs4_srv`)

- NFS Authentication data

These are all now pointers from a single `nfs_globals_t` structure, which
contains a zone ID, and a link in a list of all per-zone NFS globals.

One structure needs to be globally tracked, because they directly reference
vnodes, which are only scoped globally.  Each NFS Export Information
(`exportinfo_t`) is kept in a global-zone tree.  With this project, each
`exportinfo_t` also includes a zone ID, AND a backporter to its zone-specific
NFS Export Table.  The Implementation section will discuss this linkage
further.

### Kernel Lock Manager State

The kernel lock manager's `struct nlm_globals` already instantiated per-zone.
This project introduces a cached zone ID (`nlm_zoneid`) to make other
operations simpler, especially those that use other modules' per-zone data
structures.

### ShareFS State

ShareFS now instantiates its globals per-zone in `sharetab_globals_t`.
Unlike the lock manager, sharefs does not depend directly on data structure
in NFS itself.

## Implementation

As mentioned in the Fundamentals section, to create per-zone NFS services,
data structures that were global-zone exclusive must become instantiable
per-zone.  The Zone-Specific Data (ZSD) mechanism for illumos zones provides
a clean interface to perform straightforward per-zone instantiations of what
would be considered global state in a single-global-zone machine.

Complicating the use of ZSD, however, is that especially during bring-up and
tear-down, some of the functionality of NFS assumed its state was always run
in the same zone context as the data itself.  Experimentation during bring-up
showed that not to be the case.  To see the problem, and its solution, we
must first examine the workings of Zone-Specific Data (ZSD).

### Zone-Specific Data (ZSD)

Zone-Specific Data (ZSD) for a kernel module is well-described.  Every zone
instance will have ZSD associated for the module if it so chooses.  When a
kernel module's init() function gets called, it can choose to register ZSD by
calling `zone_key_create()` and providing three callback functions:
zone_init(), zone_shutdown(), and zone_fini().  The zone_init function
returns a pointer to module-allocated ZSD, which are then passed to the
zone_shutdown and zone_fini functions.

### ZSD Handling Outside Zone Context

What is not obvious is that whatever zone's thread loads the kernel module
will be the thread that also invokes zone_init() for ALL RUNNING ZONES.  This
means any function called by zone_init() MUST NOT assume its ZSD is part of
the thread manipulating it.  The initial work on this project made this
mistake.  It is hard to detect this condition because most of the time the
global zone loads the kernel module prior to zones bringup.  Only if a zone
kicks off a kernel module load can this condition occur.

### Distribution Differences Matter

During bringup of this project, bringing SmartOS in for testing illustrated
the above ZSD handling issues.  Since the global zone on SmartOS is almost
always minimally used, the NFS server modules are almost always brought up by
the first zone that shares via NFS.

SmartOS zones ("joyent" or "joyent-minimal" brand) do NOT have their zone's
root at a proper filesystem boundary.  In SmartOS a zones/<UUID> dataset gets
created, and /zones/<UUID>/root is merely a directory in that filesystem.
This means NFS code that traverses a directory tree upwards until a
filesystem boundary or "/" must not only check for a filesystem boundary
(vnode's VROOT flag set), but also check for a vnode that is the zone's root.

### Data Structure Linkages

This project brings NFS "globals" under per-zone structures, and may augment
other "globals" already instantiated per-zone.  They are laid out in the
following sets of ZSD:

#### ALREADY EXISTING

- struct nlm_globals (klmmod): Lock Manager ZSD

- struct flock_globals (genunix): File-locking state used exclusively by klmmod

#### NEW WITH THIS PROJECT

- nfs_globals_t (nfssrv): NFS server ZSD; contains other sub-fields which are
per-zone:
  - nfs_export_t: NFS Export Table
  - struct nfs_srv: Generic NFS server state
  - struct nfs3_srv: NFSv3 state
  - struct nfs4_srv: NFSv4 state
  - struct nfsauth_globals: NFS Authentication state

- nfscmd_globals_t (nfs): NFS command state for in-zone nfsd.

Because of the Lock Manager globals, the NFS Server globals, and the
needs-to-be-globally-indexed exportinfo_t are all in
different sets of ZSD, each of these contains a Zone ID in them.  When
searching both sets of structures from an arbitrary zone context,
correspondence can be done with Zone ID comparisons.

In some cases (usually involving exportinfo_t), a few pointer dereferences
can determine a zone's root vnode.  It is important to track this, because as
pointed out in the Distribution Differences Matter section, in some zone
brands, the zone's root vnode is NOT a filesystem boundary (i.e. the VROOT
flag is not necessarily set), and in-zone NFS share must stop at the zone
root, instead of the global zone's root.

## Possible man page changes

The initial version of this project made no manual page changes.  A survey of
manual pages that reference two or more of NFS, zones, or sharefs yielded the
following list of potential man pages:

./man1m/dfshares.1m

./man1m/dfshares_nfs.1m

./man1m/kadmin.1m

./man1m/kclient.1m

./man1m/mount.1m

./man1m/mount_nfs.1m

./man1m/mountd.1m

./man1m/nfs4cbd.1m

./man1m/nfsd.1m

./man1m/nfslogd.1m

./man1m/nfsmapid.1m

./man1m/nfsstat.1m

./man1m/rquotad.1m

./man1m/share.1m

./man1m/share_nfs.1m

./man1m/shareall.1m

./man1m/sharectl.1m

./man1m/sharemgr.1m

./man1m/statd.1m

./man1m/unshare.1m

./man1m/unshare_nfs.1m

./man1m/zfs.1m

./man4/dfstab.4

./man4/nfs.4

./man4/nfslog.conf.4

./man4/nfssec.conf.4

./man4/rpc.4

./man4/sharetab.4

./man5/nfssec.5

./man5/zones.5

./man7fs/sharefs.7fs

These should be further audited for possible changes to make administrators
aware of per-zone NFS service.

## Testing

<XXX KEBE SAYS FILL ME IN.)

## Potential Future Issues

XXX ONLY REAL ONE I SEE IMMEDIATELY IS PRIVILEGES FOR SHAREFS

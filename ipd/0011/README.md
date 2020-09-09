---
author: Dan McDonald
state: published
---

# IPD 11 NFS Server for Zones (NFS-Zone)

## Introduction

Formerly the Network File System (NFS) server could only be instantiated in
the global zone.  This document describes how NFS is now able to instantiate
in any non-global zone.  This document assumes the reader has some
understanding of NFS.

illumos issue [11083](https://illumos.org/issues/11083/) tracks the main
thrust of this effort.  Precursor issues
[2988](https://illumos.org/issues/2988/) and
[11945](https://illumos.org/issues/11945) are also part of the fallout from
this project, and have been integrated into illumos-gate as of December 2019.

## History and Fundamentals

Before Oracle closed OpenSolaris, there was a work-in-progress to solve this
problem.  Unfortunately, even a larval version of this work did not escape
into the open-source world.  Post-illumos, multiple attempts tried to make
NFS service in a zone (abbreviated to NFS-Zone for the rest of this
document).

One distribution, NexentaStor, managed to implement a version in their child
of illumos.  This work from Nexenta forms the basis for what is planned to be
brought to illumos-gate.

Prior to this project, NFS instantiated its state assuming it would only run
in the global zone.  This state spans three different kernel modules:
`nfssrv` (the NFS server kernel module), `klmmod` (kernel lock manager
module), and `sharefs` (the kernel "sharetab" filesystem).

### NFS Server State

A majority of the NFS server state can be instantiated into Zone-Specific
Data (ZSD).  Prior to this project, modules instantiated ZSD for each of:

- NFS Export Table (`nfs_export_t`)

- NFS server instances for NFSv2 (`struct nfs_srv`), NFSv3 (`struct
  nfs3_srv`), and NFSv4 (`struct nfs4_srv`)

- NFS Authentication data

These are all now pointers from a single `nfs_globals_t` structure, which
contains a zone ID, and a link in a list of all per-zone NFS globals.

One structure needs to be globally tracked, because each structure instance
directly references vnodes, which are only scoped globally.  Each NFS Export
Information (`exportinfo_t`) is kept in a global-zone tree.  With this
project, each `exportinfo_t` also includes a zone ID, AND a backpointer to
its zone-specific NFS Export Table.  The Implementation section will discuss
this linkage further.

### Kernel Lock Manager State

The kernel lock manager's `struct nlm_globals` are already instantiated
per-zone.  This project introduces a cached zone ID (`nlm_zoneid`) to make
other operations simpler, especially those that use other modules' per-zone
data structures.

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
root at a proper filesystem boundary.  In SmartOS a zones/$ZONE_UUID dataset
gets created, and /zones/$ZONE_UUID/root is merely a directory in that
filesystem.  This means NFS code that traverses a directory tree upwards
until a filesystem boundary or "/" must not only check for a filesystem
boundary (vnode's VROOT flag set), but also check for a vnode that is the
zone's root.

### Data Structure Linkages

This project brings NFS "globals" under per-zone structures, and may augment
other "globals" already instantiated per-zone.  They are laid out in the
following sets of ZSD:

#### ALREADY EXISTING

- struct nlm_globals (`klmmod`): Lock Manager ZSD

- struct flock_globals (`genunix`): File-locking state used exclusively by klmmod 

#### NEW WITH THIS PROJECT

- nfs_globals_t (`nfssrv`): NFS server ZSD; contains other sub-fields which are
per-zone:
  - nfs_export_t: NFS Export Table
  - struct nfs_srv:  NFSv2 server state
  - struct nfs3_srv: NFSv3 server state
  - struct nfs4_srv: NFSv4 server state
  - struct nfsauth_globals: NFS Authentication state

- nfscmd_globals_t (`nfs`): NFS command state for in-zone nfsd.

Because of the Lock Manager globals, the NFS Server globals, and the
needs-to-be-globally-indexed `exportinfo_t` are all in
different sets of ZSD, each of these contains a Zone ID in them.  When
searching both sets of structures from an arbitrary zone context,
correspondence can be done with Zone ID comparisons.

In some cases (usually involving `exportinfo_t`), a few pointer dereferences
can determine a zone's root vnode.  It is important to track this, because as
pointed out in the Distribution Differences Matter section, in some zone
brands, the zone's root vnode is NOT a filesystem boundary (i.e. the VROOT
flag is not necessarily set), and in-zone NFS share must stop at the zone
root, instead of the global zone's root.

## Man page changes

The initial version of this project made no manual page changes, and the
initial push to illumos-gate will not as well.  A survey of manual pages that
reference two or more of NFS, zones, or sharefs yielded the following list of
potential man pages:

- `dfshares`(1m)
- `dfshares_nfs`(1m)
- `kadmin`(1m)
- `kclient`(1m)
- `mount`(1m)
- `mount_nfs`(1m)
- `mountd`(1m)
- `nfs4cbd`(1m)
- `nfsd`(1m)
- `nfslogd`(1m)
- `nfsmapid`(1m)
- `nfsstat`(1m)
- `rquotad`(1m)
- `share`(1m)
- `share_nfs`(1m)
- `shareall`(1m)
- `sharectl`(1m)
- `sharemgr`(1m)
- `statd`(1m)
- `unshare`(1m)
- `unshare_nfs`(1m)
- `zfs`(1m)
- `dfstab`(4)p
- `nfs`(4)
- `nfslog.conf`(4)
- `nfssec.conf`(4)
- `rpc`(4)
- `sharetab`(4)
- `nfssec`(5)
- `zones`(5)
- `sharefs`(7fs)

These will be further audited for possible changes to make administrators
aware of per-zone NFS service.  illumos issue
[12278](https://illumos.org/issues/12278/) tracks the subsequent man page
changes.

## Testing

Testing has included a series of smoke, use, and mild-stress testing on a
SmartOS compute node that is serving NFS both from its global zone and a
non-global zone.  It has been done so under both DEBUG and non-DEBUG kernels,
the former of which found several issues after the initial code drop which
are now fixed.  Some of those same tests were done on an OmniOSce bloody with
this project, running on VMware Fusion.

The Linux "nfstest" package:  https://wiki.linux-nfs.org/wiki/index.php/NFStest
can be used (as long as NFSv4.1 is excluded) as a regression and
interoperability test.  As of December, 2019, this project's changes have
not affected the results of the Linux NFS tests.  See
http://kebe.com/~danmcd/webrevs/nfs-zone/linux-nfs-test/ for results and
details.  (NOTE: Later these may be moved to the `old` directory inside
Dan's webrevs directory, insert "old/" between "webrevs/" and "nfs-zone".)

illumos issue [11083](https://illumos.org/issues/11083/) has additional
testing details.

## Potential Future Issues

The sharefs filesystem does not have its own set of privileges that can be
delegated into a zone.  The sharetab.c source file has a block comment
describing this:

```
 * TODO: This basically overloads the definition/use of
 * PRIV_SYS_NFS to work around the limitation of PRIV_SYS_CONFIG
 * in a zone. Solaris 11 solved this by implementing a PRIV_SYS_SHARE
 * we should do the same and replace the use of PRIV_SYS_NFS here and
 * in zfs_secpolicy_share.
```

And this should be addressed as a separate bug as well.

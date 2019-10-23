---
author: Dan McDonald
state: predraft
---

# IPD 11 NFS Server for Zones (NFS-Zone)

## Introduction

Currently the NFS server can only be instantiated in the global zone.  This
document describes how NFS will be able to instantiate in any non-global
zone.

## History and Fundamentals

Before Oracle closed OpenSolaris, there was a work-in-progress to solve this
problem.  Unfortunately, even a larval version of it did not escape into the
open-source world.  Post-illumos, multiple attempts tried to make NFS service
in a zone (abbreviated to NFS-Zone for the rest of this document).

One distro, NexentaStor, managed to implement a version in their child of
illumos.  This work from Nexenta forms the basis for what is planned to be
brought to illumos-gate.

<XXX KEBE SAYS explain the fundamentals of NFS, and how they need to change
for NFS-Zone.)

## Implementation

<XXX KEBE SAYS FILL ME IN.>

## Testing

<XXX KEBE SAYS FILL ME IN.>


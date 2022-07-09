---
author: Garrett D'Amore
sponsor:
state: draft
---

# Remove obsolete SCSA functions

## Introduction

SCSA is the API provided for SCSI HBAs and targets.
It has evolved quite a lot over the years, but we still
have a number of interfaces which are completely unused,
and may actually be unsafe.

It's time to finally clean up this technical debt, which
may ease other work later.

## Description

The following interfaces have been marked Obsolete for a
very, very long time (Solaris 8 at least).  Furthermore,
they have no known consumers (possible legacy closed source
SPARC HBA drivers not withstanding).

* scsi_dmaget
* scsi_dmafree
* scsi_pktalloc
* scsi_resalloc
* scsi_resfree
* scsi_pktfree
* makecom
* makecom_g0
* makecom_g1
* makecom_g5
* scsi_slave
* get_pktiopb
* free_pktiopb

In a few cases removing these functions will potentially make life better by
removing code paths which actually hurt sustaining efforts.
For example, cleaning up and optimizing the core DMA logic would be easier if
the get_pktiopb interface didn't need to be updated.

We propose to remove the implementation and all references to these
functions.

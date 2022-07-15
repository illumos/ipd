---
author: Garrett D'Amore
sponsor:
state: predraft
---

# Obsolete old style SCSI HBA API

## Introduction

There are two interfaces used for initializing SCSI
packets in HBAs:

tran_setup_pkt(9e):

       int prefix_tran_setup_pkt(struct scsi_pkt *pkt,
            int (*callback) (caddr_t), caddr_t arg);

tran_init_pkt(9e):

       struct scsi_pkt *prefixtran_init_pkt(struct scsi_address *ap,
            struct scsi_pkt *pkt, struct buf *bp, int cmdlen,
            int statuslen, int tgtlen, intflags, int (*callback,
            caddr_t),caddr_t arg);

Newer drivers should use the *vastly* simpler (to use)
tran_setup_pkt (which also involves the use an explicit
tran_pkt_constructor).  By so doing, the HBA framework takes
care of a ton of complexity around DMA windows (partial DMA
mapping for example), setting up DMA binding, and so forth.

This works very well for most situations.

Use of the scsi_init_pkt interfaces, which was the old way
to write a driver, is fairly error prone, and many older
drivers had bugs in this area of code.

The other area where SCSI drivers wind up having complexity
and confusion is around the scsi_hba_attach vs
scsi_hba_attach and handling of SCSI addresses.

Today, unless one uses iport(9), it is impossible to
write a DDI compliant SCSI HBA unless one wishes to only
support SPI with a maximum of 7 targets per bus.
That's not typical for most situations today.

Additionally the following flags are at best confusing:

* SCSI_HBA_ADDR_CLONE - clones the scsi_address per target (old style)
* SCSI_HBA_ADDR_COMPLEX - modern HBAs should use this
* SCSI_HBA_TRAN_CDB - allocates CDB area, modern HBA should always supply
* SCSI_HBA_TRAN_SCB - allocates SCB area, modern HBA should always supply
* SCSI_HBA_HBA - used to indicate driver is using iport(9)

It would be better if everyone stopped using the older APIs.

Unfortunately the documentation makes this somewhat less
than obvious, as it simply refers the new style APIs as
an "alternative", and the mixed docuumentation for legacy
APIs makes the task of writing a driver a lot more challenging.

## Proposal

This proposal does not change any *code*, but it does
propose to change the Stabiliy level for some SCSI APIs.

The following APIs would be marked Obsolete:

* tran_init_pkt(9e)j
* tran_destroy_pkt(9e)
* tran_sync_pkt(9e)
* tran_quiesce(9e) - only for SPI drivers
* tran_unquiesce(9e) - only for SPI drivers
* scsi_hba_attach(9f)
* SCSI_HBA_TRAN_CLONE

We propose a new flag, which is the combination of several other
flags:

SCSI_HBA_TRAN_V3 combines:

  * SCSI_HBA_TRAN_CDB
  * SCSI_HBA_TRAN_SCB
  * SCSI_HBA_ADDR_COMPLEX
  * SCSI_HBA_HBA

This "V3" means that the driver is fully compliant to SCSAv3
and uses no legacy SCSI APIs.
(TODO: IS THIS A GOOD NAME? PERHAPS A BETTER ONE?  OR WE COULD
REPLACE scsi_hba_attach_setup() with a function that takes
no flags and simply passes the combination of these three?)

Additionally, tran_setup_pkt should be marked "mandatory" for new drivers.
We propose a new API be added.  This would only be supported for
use with drivers that use tran_setup_pkt(9e).

Legacy entry points should have their details combined into a single
manual page, that it makes it clear that these interfaces are
obsolete and provides clear guidance about newer APIs to use.


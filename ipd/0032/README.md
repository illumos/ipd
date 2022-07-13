---
author: Garrett D'Amore
sponsor:
state: predraft
---

# Introduce scsi_hba_pkt_mapin

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

However, very occasionally a driver needs to access the address
associated with the bp from kernel space.  

For example, some HBAs require certain commands to be emulated,
or for the results of commands to be massaged.  For example the
hv_storvsc driver from Delphix adjusts INQUIRY responses to
work around limitations in older versions of Windows.

Some RAID cards emulate responses as well, but only for a very
small set of commands.

The only way to do this right now is to keep the bp passed in
to tran_init_pkt, and call bp_mapin(9F) when this is needed.

Today, drivers that need to access the data region associated with
the buffer have to pay the entire cost of supporting the legacy
API.

It would be nice if they could get a way to do the bp_mapin() and
get the associated addresses so that they could access data fields
directly.

## Proposal

We propose a new API be added.  This would only be supported for
use with drivers that use tran_setup_pkt(9e):

int scsi_hba_pkt_mapin(scsi_pkt_t *pkt, caddr_t *addrp, size_t *lenp);

This function would only be usable once tran_start(9e) is called,
and before scsi_hba_comp(9F) is called.  It should be callable
from user and kernel contexts (like bp_mapin).

Note that because of this requirement, drivers that need to do
this mapping may need to do so using a helper taskq or similar to get
out of interrupt context as tran_start() may be called in interrupt
context. However, the most frequent use case of this is for commands
like INQUIRY, which generally are not executed from interrupt context.

On success, this function:

* Maps in the buffer (bp_mapin()).
* Stores in addrp the kernel address corresponding to the physical address
  pkt->pkt_cookies[0].dmac_laddress
* Stores in lenp the sum of the pkt cookie sizes.
* Returns 1 (like other SCSA functions - corresopnding to TRUE)

On failure, this function:

* Returns false

## Failure conditions

The failure conditiosn we anticipate are:

* No cookies (no transfer for the packet), e.g. for TEST UNIT READY
  commmand.
* The packet was not initialized using tran_setup_pkt.

## No mapout needed

The framework for bufs automatically does a bp_mapout when the buf is done.
So there is no need to do so explicitly.  We expect that this API will
be only rarely used anyway.

However, if need be, we could explicitly do a bp_mapout() in the
code for scsi_hba_comp().

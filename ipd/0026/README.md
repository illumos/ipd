---
author: Garrett D'Amore
sponsor:
state: draft
---

# Sunset CardBus and PC Card

## Introduction

The CardBus (PC Card) stack in illumos dates from OpenSolaris, and was
introduced as a contribution from Tadpole, extending the legacy 16-bit PCMCIA
support already present in Solaris. It was used on SPARC laptops.

CardBus is 32-bit extension of the PCMCIA standard, and more or less can
be thought of as an extension of PCMCIA to support PCI-style semantics,
including 32-bit transfers and bus mastering.

CardBus itself is long obsolete, and was replaced by ExpressCard (and really
USB) in the early 2000s.  Apparently some special purpose systems were
still produced with CardBus as late as 2012.

Our kernel no longer has any support for devices likely to be found
on CardBus nodes, with the possible exception of CompactFlash devices
masquerading as IDE on CardBus or (more likely!) PCMCIA.

The CardBus APIs in our kernel are modeled on APIS specified by JEIDA,
and are very unlike every other nexus interface in the kernel.
It is one of the last things using certain legacy kernel APIs as well.

The PCI nexus implementation contains certain code that exists only
to support CardBus as well.

We are unaware of any use of CardBus by anyone using illumos in the
last decade or so.

## Proposal

We propose to simply remove the cardbus stack altogether.
This will also remove the last vestiges of PCMCIA support.

Kernel APIs related to cardbus -- the `csx_Put8()`, `csx_Get8()`, and similar
functions (generally all starting with `csx_`) would be removed.
These are currently not in a dedicated cardbus module, but part of the
common kernel DDI.

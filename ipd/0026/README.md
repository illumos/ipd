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

## Prior Discussion

This has been discussed before. Pure 16-bit PCMCIA support was
removed around a decade ago, and back in 2014 a proposal to remove
CardBus itself was floated, along with a review.
This discussion was on the illumos mailing lists, in the following
threads:

* [obsolete legacy PCMIA](https://illumos.topicbox.com/groups/developer/Te2c90b02ebe5b0aa-M526606b14e4160e4e3231875/obsolete-legacy-pcmcia)

* [proposed EOF of PCMCIA](https://illumos.topicbox.com/groups/developer/T3be2124e9f17aa04-Maa11cbaf947ea116077801cf/proposal-eof-pcmcia-bits)

* [webrev for removing cardbus (2014)](https://illumos.topicbox.com/groups/developer/T5edf352487b49a3b-Mcf2cecc58cdd912926f8bd63/webrev-removal-of-cardbus)

## Related Issues

* [680 pm_create_components out to be cleaned up](https://www.illumos.org/issues/680)
* [2398 pcs driver should be removed](https://www.illumos.org/issues/2398)
* [5075 EOF cardbus & pcmcia](https://www.illumos.org/issues/5075)
* [8510 pcmcia: typo in pcmcia_prop_op](https://www.illumos.org/issues/8510)

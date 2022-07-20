---
authors: Garrett D'Amore <garrett@damore.org>
sponsors:
state: draft
---

# IPD 35 Sunset VTOC - SPARC

## Abstract

We propose to eliminate support for the legacy VTOC format used
on SPARC systems (with a maximum of 8 slices).  The 16 slice
format used on x86 systems is not affected by this IPD.

## Background

Solaris on SPARC had a legacy going back to SunOS 4 (and likely further back
to SunOS 3 or even 2) of partitioning a disk into "slices", and assigning
minor numbers for each device.

For reasons lost to memory, the decision to support a maximum of 8 slices
per physical disk was made, with some slices (slice 2 in particular) being
special (slice 2 refers to the whole disk.)

When Solaris was ported to x86, a different format was chosen -- likely
to accommodate other SYSV UNIX implementations available on the platform
at the time.  Instead of 8 slices, a maximum of 16 are supported on
x86 platforms.

To this day, even for GPT disks, a maximum of 16 slices are available.

While arguably 7 is more than sufficient (and arguably in the modern era almost
every uses the entire disk without slicing using GPT instead of FAT
partitions), the current convention is still up to 16.  Additionally
minor numbers have been allocated to refer to the "whole disk", instead of
making slice 2 "magical".

There are a number of places (scattered throughout the driver stack, FMA,
various user utilities and libraries) that have to cope with this dichotomy.
Generally this is done via #ifdef sparc etc.  In some cases, if neither
sparc nor i386 is defined, then a compilation error is triggered.

IPD 19 approved the sunset of SPARC altogether, and work is underway
to remove it.

## Proposal

We think it would be better, and easier for future platform porters,
to just firmly adopt the conventions used on the x86 platform, and
discard all support for legacy SPARC VTOCs.

This means that ifdef's can be removed, and we can assume that the i386
implementation for disk labeling is the only one we support.

(As an aside, we hope new platforms will adopt GPT rather than FAT style
partitioning.)

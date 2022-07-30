---
author: Garrett D'Amore
sponsor:
state: draft
---

# Rationalize $(MACH64) Command Paths

## TLDR (Abstract)

This IPD provides guidance on the use of architecture specific
paths in runtime search paths such as /usr/bin and library
search paths such as /usr/lib.

It helps establish a set of guidelines leading to more
comprehensive support for 64-bit architectures.

It also proposes that no new 32-bit architectures will be
introduced to illumos.

## Goals

The purpose of this IPD is to provide guidance for developers
working on new platform ports, as well as for the eventual migration
of much of our user space to being fully 64-bit compatible.

A hard requirement is not to break binary compatibility for the
large set of existing 32-bit binaries for i386.

## Background

In the early days of Solaris, for a given system there was only
one architecture suppored for a given system (either sparc or i386).

When 64-bit support was introduced, it was introduced incrementally,
such that somethings that needed to be 64-bit (to facilitate working
with larger amounts of data in commands like "tar") were added, but
32-bit equivalents were left behind.
These additions were made in a subdirectory called $(MACH64) --
sparcv9 for sparc, and amd64 for i386.

Additionally, at the time, it was possible to select the architecture
(i386 or amd64, and sparc or sparcv9) at boot time.

For user commands, the decision was to generally prefer 64-bit versions
over the 32-bit ones, when it was possible to do so.
To facilitate this, those commands that were delivered as dual
architecture commands had a 32-bit version delivered in a subdirectory
called $(MACH) (i386 or sparc), and the parent (e.g. /usr/bin)
directory had the program hardlinked to isaexec, which would choose
the optimal version (from the subdirectory appropriate) and execute it.

Additionally, to facilitate development of both 32 and 64-bit programs,
as well as binary compatibility, shared libraries were organized along
similar lines, except that the 32-bit versions were left behind in the
parent (/usr/lib, etc.) in order to avoid breaking binary compatibility.

This organization allowed coexistence of 32 and 64 bit binaries, but
it complicated delivery of software, as well as rules for linking
software, etc.

Today, illumos does not supports only 64-bit kernels.
It is unlikely that support for 32-bit mode kernel operation is likely
to ever occur again.  At present core illumos only supports amd64,
although work is in progress to support other architectures, most
notably aarch64.

A number of user space components exist which are not today capable
of running in 64-bit mode.  We consider this a defect in those
components.

## Proposal

In recognition of the following:

* No new 32-bit architectures will be introduced which support 32-bit mode execution.
* No support for bi-architecture is likely to occur, and we should not attempt to facilitate it.
* We should try to make the system easier to understand for administrators, users, and developers.

we therefore propose:

* "Deprecation" of /usr/bin/${MACH} and /usr/bin/${MACH64}, as well as /usr/lib/${MACH64}
  - this includes other prefixes such as /usr/platform, etc. as well as notionally equivalent
    directories like /usr/sbin.
  - new ports should refrain from introducing these directories
* Packaging manifests should have their references to the above directories qualified with i386_ONLY.
* For i386/amd64 only, the *LIBRARY* 64-bit may continue to be used for new deliveries, as existing
  search directories already exist. 
* For new 64-bit platforms, the following symbolic link should be installed /usr/lib/64 -> .
  - also for /usr/platform/*/lib, /lib, etc.
  - this allows Makefiles to still use /64 in link rules
  - it moves towards using simpler linker paths elsewhere
* Distributions on amd64 MAY choose to dispense with 32-bit compatibility, and use the same appraoch
  discussed here for other architectures.  This will come at an expense to binary compatibility with
  other i386 distributions.
* All user-space commands and libraries should be made to function in 64-bit mode, treating any
  failure to do so as a bug.
  - this is necessary to support some new architectures
  - it may facilitate work towards Y2038 compliance (see [IPD 14](../0014/README.md)).
* Commands which currently deliver executables into usr/bin/amd64 should, when the command is
  converted to 64-bit by default, leave behind a symbolic link in usr/bin/amd64 to help any
  scripts or users that have muscle memory tied to the 64-bit path.
* Use of /usr/bin/i386 should be exceedingly rare.  In general we would prefer that nothing
  deliver there, although there may be specific exceptional cases for it, such as for tools that
  have to be 32-bit to support the 32-bit environment (for example 32-bit mdb is required for
  full support when debuggin 32-bit binaries.)

## Future Directions

It may be desirable in the future to relegate 32-bit libraries to a separate directory for legacy libraries, such as `/usr/lib/i386`.
This can be done without breaking binary compatibility if the loader is modified to explicitly search
these paths when resolving symbols for a 32-bit binary.

At that time, it may be possible and desirable to move the contents of /usr/lib/amd64 to /usr/lib (and leave
behind a symbolic link).

## Related Cases

* [IPD 14 illumos and Y2038](../0014/README.md)
* [IPD 19 Sunset SPARC](../0019/README.md)
* [IPD 34 Rationalize Kernel Architecture Module Paths](../0034/README.md)

---
author: Garrett D'Amore
sponsor:
state: draft
---

# Sunset luxadm

## Introduction

luxadm is part of the tooling used to support FC-AL (fibre-channel
arbitrated loop) devices, such
as the Sun Enterprise Network Array (SENA) and the Sun Fire 880
storage subsystem.

In theory luxadm could be used for x86, because we deliver this command for
both x86 and SPARC, but in practice it seems unlikely to have been used on
x86 hardware outside of Sun Microsystems.
Removal of this command may represent a reduction in functionality
for users of certain SPARC hardware such as the Sun Fire 880, but
we have already approved the removal of support for SPARC
as part of [IPD 19](../0019/README.md).

Modern FC enterprise storage arrays offer management through either
SCSI Enclosure Services, or more frequently, proprietary
management interfaces.
They are not manageable with luxadm.

This utility is also built upon libHBAAPI, which at this point
is unmainted, and is one of the last pieces of C++ in our system.

## Proposal

Remove luxadm.

## Future Directions

We would like to see the fcinfo and fcadm commands, updated to avoid the use of
libHBAAPI, and libHBAAPI retired as well.
That library was designed to SNIA specifications that apparently only
Sun Microsystems implemented.
It's also a chunk of complex C++ code, that can likely be distilled to
a much simpler subset of functionality.

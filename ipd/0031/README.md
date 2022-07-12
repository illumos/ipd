---
author: Garrett D'Amore
sponsor:
state: draft
---

# Kernel Interace Stability Documentation

## Introduction

Hearkening back to the days of early Solaris 2,
we have documentation which discrens the difference
between SVR4 standard DDI and Solaris (now illumos) extensions.

This was deemed important when there was an attempt to
harmonize the various SVR4 flavors of UNIX, back in the 1990s.

There is no longer any real meaningful compatibility
between SVR4 systems and Solaris or illumos.
Driver developers must write a device driver that
utilizes illumos-specific functions.

Additionally, the author is unaware of *anyone* who has
ever used this discriminating information for any useful
purpose for at least two decades.

It's quite possible that the information was *never* useful,
to anyone, ever.  It's only conceivable use would have been
to facilitate porting drivers from another SVR4 to Solaris.
This is not something that the author believes anyone has undertaken
this millenium.

Conversely, Interface Stability as used in other sections
(section 2 and 3 of the Reference Manual) is very useful, as
it conveys details such as Committed or Obsolete, and may
also convey additional clarifying information.

Sometimes this information was presented in the INTERFACE LEVEL
chapter, and sometimes it was in the Stability entry for the
ATTRIBUTES table, and sometimes it wasn't presented at all.
Ocassionally it was presented in both places.

## Description

We propose to fold the Interface Stability (Committed, Evolving, and Unstable.)
and any clarifying text into the INTERFACE STABILITY chapter as has been done
for other sections.
This should utilize content from INTERFACE LEVEL or the ATTRIBUTES table
when present.

The actual INTERFACE LEVEL chapter should then be removed, as well as
any references to illumos vs. "generic" DDI/DKI.
(All of these interfaces are the illumos DDI.)

The ATTRIBUTES table should be removed as well.
In some cases an ARCHITECTURE field may be present.
For those cases, that information should be placed into an
ARCHITECTURE chapter as is done for other sections of the manual.

Note that the INTERFACE STABILITY and ARCHITECTURE chapters are
well documented by mdoc(4).

## Implementation

We should opportunistically fix manual pages.
Alternatively, a single large change to update
the manual all at once can be contemplated.

Conceivably we could update mandoc so that linting man pages
complains when it finds an INTERFACE LEVEL chapter.
Perhaps this should also be done if an ATTRIBUTES chapter is found.

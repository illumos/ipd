---
author: Garrett D'Amore
sponsor:
state: draft
---

# Retire INTERFACE LEVEL category

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

Documenting the details here presents a burden on
writers working with man pages, and adds useless content
to every one our manual pages related to kernel content.
There are are also technical errors and inconsistencies in
this information.

## Description

Remove the INTERFACE LEVEL chapter and references to illumos vs.
generic DDI/DKI from all section 9, 9f, 9e, and 9s manual pages.

This can be done opportunistically as pages are edited, or
done all at once.

Conceivably we could update mandoc so that linting man pages
complains when it finds an INTERFACE LEVEL chapter.

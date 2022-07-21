---
author: Garrett D'Amore
sponsor:
state: draft
---

# Rationalize Kernel Architecture Module Paths

## TLDR (Abstract)

This IPD proposes to end the notion of "special" or "privileged"
kernel architectures, by including the kernel architecture (e.g.
amd64, or in the future arm64 or whatever) in the kernel directory
paths.  This matches the existing practice for 64-bit amd64, as
well as for there recently removed sparcv9 architecture.  It would
prohibit another architecture (say arm) from following the old
approach of 32-bit architectures not including the architecture
name in the module path.

## Background

In the beginning, the only architecture possible for
Solaris was sun4.  A 32-bit architecture, with kernel
modules located directories based solely on their function,
such as /kernel/drv or /usr/kernel/strmod.

When platforms got added, we added a /platform directory,
so that different platforms ("implementations") 
based on the same architecture could deliver different
versions of modules.  For example, we used to have
/platform/SUNW,Ultra-1 and /platform/SUNW,Ultra-450,
eacho of which had subdirectories such as kernel, etc.

At some point we added i386 as an architecture, with the
single platform "i86pc".  In all other respects it followed
the same model as sparc.

In the Solaris 7 time frame, we grew support for 64-bit kernels,
and a new "architecture", sparcv9 was born.  However, this 64-bit
architecture could coexist with 32-bit binaries on the same system.
To discriminate between 32-bit and 64-bit kernel modules (and remember
the choice to boot 32- or 64-bit was able to be made at boot time),
the 64-bit kernel architecture was inserted into the module path.

For example, a SCSI driver might have paths like this:

	/kernel/drv/fas  	<- 32-bit sparc binary
	/kernel/drv/sparcv9/fas	<- 64-bit sparcv9 binary

Or on x86:

	/kernel/drv/mpt		<- 32-bit i386 binary
	/kernel/drv/amd64/mpt	<- 64-bit amd64 binary

Before illumos was forked from OpenSolaris, the 32-bit SPARC platform
support had been retired.  Not too long ago we also retired support
for 32-bit i386 kernels.  And even more recently, we retired
support for SPARC altogether.

That leaves us with

	/kernel/drv/amd64/mpt

(And similarly for /platform paths or /usr/kernel, and also for
other kinds of modules besides drivers.)

## Proposal

We propose to codify the current practice, and forever prohibit the
old practice of kernel load paths that do not include the kernel
architecture.  At present the only kernel architecture supported by
illumos is "amd64", although we might expect "aarch64" (or perhaps
it will be called "arm64") to be added to this list, as well as
perhaps "riscv".)

Thus there will no longer be an "implied" architecture if none is
specified.

This approach should simplify packaging and documentation.

Note that there are no changes needed to code to effect this change
today.  The only things that should probably be fixed here would
be clarifications in man pages that list explicit architecture load
paths. (They can change to listing e.g. /kernel/drv/${KARCH}/driver
instead of enumerating them for each architecture.)

None of this has any effect on platform names (i86pc, i86hvm, or
possible future platform implementation names.  Multiple platforms
can share the same kernel architecture.)

## Future Directions

It seems somewhat unlikley that we will ever need to support both
32- and 64-bit architecture kernels on the same system, or even
to deliver "dual" architecture systems in the future.  Likely at
some point even legacy i386 32-bit userland bits will be something we
do not deliver, and even if we do, 32-bit support for i386 may be
something of a special case rather than something we do again as part
of our mainstream design.

Thus, we may wish to change the packaging code to eliminate the
ARCH64 variable, and just replace it with a KARCH variable for packaging.
Arguably this would eliminate some of the special cases.

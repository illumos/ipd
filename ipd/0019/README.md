---
authors: Joshua M. Clulow <josh@sysmgr.org>
sponsors: Robert Mustacchi <rm@fingolfin.org>, Garrett D'Amore <garrett@damore.org>
state: published
---

# IPD 19 Sunset SPARC

## Goal

Officially end SPARC support in illumos and remove the SPARC code from the
tree.

## Background

When the illumos project was formed in 2010 as a fork of OpenSolaris, the
operating system contained support for 32-bit and 64-bit x86 machines, and for
various 64-bit SPARC machines from Sun Microsystems.  In 2018, we [officially
dropped support for 32-bit x86 systems](https://www.illumos.org/issues/8685),
leaving just 64-bit x86 and SPARC.

The most recent SPARC machines for which we have relatively direct and complete
support were contemporary at the time of the fork; viz., the UltraSPARC T2
family of servers, such as the T5120 and T5220.  The last of these systems
reached their end-of-life between 2011 and 2012.  In the decade hence, the size
and quality of the pool of second hand systems available through eBay and other
vendors has dwindled, and prices have risen to match.  Desktop systems in
particular are popular for collectors, and are thus now staggeringly expensive
if you can find them at all.  As a result, the pool of machines available to
build the software is extremely limited; the project does not currently have
access to a permanent official SPARC build machine.

Without ready access to build machines, one might consider cross compilation.
Though we have some support for cross-architecture software generation in the
tools, the operating system does not currently support being cross compiled in
full.  Work would be needed to complete surgery to Makefiles and arrange for
packaged cross-architecture C compilers, amongst other things.

In theory one might emulate SPARC systems with QEMU, but reports in the field
suggest that this does not work well enough to run modern illumos.  Even if it
did, it may take a very long time -- e.g., weeks! -- to build the operating
system under full emulation.

In addition to the core of illumos, the external software ecosystem has changed
a lot in ten years.  Many new projects have emerged that generate program text
at runtime (JIT) or which do not use established code generation systems like
LLVM or GCC that have SPARC support; e.g., Go and Node.js.  Some projects could
in theory support illumos on SPARC, like Rust, but it will still require a not
inconsiderable amount of work to get there.  There is growing interest for
use of Rust in the development of the core of illumos, and lack of current
support for SPARC inhibits those efforts.

If a community of users was going to emerge to provide engineering effort and
build resources for SPARC, it likely would have done so by now.  It is always
sad to close a chapter in our history, and SPARC systems represent a strong and
positive memory for many of us.  Nonetheless, the time has arrived to begin the
process of removing SPARC support from the operating system.

## What Would This Enable?

A non-exhaustive list of project work that members of the project would like
to undertake, where SPARC support presents a barrier today includes:

- retiring the now-ancient GCC 4.4.4 shadow compiler that remains chiefly
  to support the SPARC platform
- use of newer GCC versions and newer C standards to enable improvements
  such as better compile-time assertions (`CTASSERT()`, see
  [12994](https://www.illumos.org/issues/12994), etc)
- cleanup of some of the internals of [mac(9E)](https://illumos.org/man/9E/mac)
  which have some facilities that exist only for specific SPARC hardware
- reworking of some of the interpreted programs in `usr/src/tools` with faster
  and more featureful tools written in Rust
- use of Rust to implement new facilities in the kernel, in libraries and in
  commands

## Strategy and Timeline

1. **Replace GCC 4.4.4 shadow with GCC 10 shadow** *(done, see [bug
   14149](https://www.illumos.org/issues/14149))*
1. **Update project documentation to make a clear statement about platform support** *(immediate)*
   - e.g., https://illumos.org/docs/about/#supported-hardware-platforms
   - Only 64-bit x86 systems are supported
1. **Stop accepting changes to code for SPARC** *(immediate)*
1. **Delete the SPARC code from the tree** *(coming months)*
   - Care must be taken not to break anything, but one benefit of dropping the platform is cleaning up a _lot_ of code that is mostly not relevant anymore so we should likely do this deliberately and not just clean up occasional files "as we go"
   - Even though there will be just one architecture after the removal, any machinery that exists to support multiple architectures must be kept to enable future porting work (e.g., ARM or RISC-V)
   - We should retain support for interpreting SPARC _data_ where it is not in the way; e.g.,
     - `mdb` can retain support for SPARC core files, ELF notes, etc
     - `dis`, `libdisasm`, etc, can continue to disassemble SPARC program text

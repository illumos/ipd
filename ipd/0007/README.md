---
author: Richard Lowe
state: draft
---

# IPD 7 illumos GCC maintenance

## Introduction

Currently the GCC used to build illumos is maintained on GitHub in
http://github.com/illumos/gcc, and only those versions endorsed by illumos are
present.  This proposes to change this to a more generally useful approach
that nevertheless aims to still make clear the compilers we actually believe
to be good, and also generally discusses the maintenance of the patched GCC
used by illumos.

## Status Quo

At present, we maintain two branches of GCC.

| name       | description                                                   |
| ---------- | --------------------------------------------------------------|
| `il-4_4_4` | GCC 4.4.4 used as the primary compiler                        |
| `il-7_3_0` | GCC 7.3.0 used as the shadow compiler, and intended to be the |
|            |  next primary compiler                                        |
  
Each version of the compiler we intended to endorse/insist upon the use of
during the RTI process is tagged in the form `gcc-X.Y.Z-il-N` where _X.Y.Z_ is
the GCC version, and _N_ is a monotonically increasing integer to
differentiate versions of our patches.

Newer versions of GCC are worked on in forks of `illumos/gcc`, or via other
means by distribution, and coordination is minimal.  This is what this
proposal hopes to change.

## Proposal

### Use of the `illumos/gcc` repository

In future, `illumos/gcc` will not only contain the compilers endorsed for
building `illumos-gate`, but also works in progress towards upgrading those
compilers (such as were previously kept in personal repositories), on branch
names matching the pattern used thus far (that is `il-X_Y_Z`).  Using other
branch names, and personal repositories has thus far not hindered people
taking these compilers and using them in production, and has only served to
hinder cooperation on their maintenance.  As such, it is abandoned.

Versions of the compiler endorsed for use with `illumos-gate`, and only those
versions, will be tagged in the current format (`gcc-X.Y-Z-il-N`).

### Method of Shipping the Patched GCC

Distributions can take the tarball provided from the github tags and versions,
and integrate that into their build systems as the upstream tarball, not
needing to maintain a patch set based on our git repository.

Distributions wishing to update or further patch GCC can easily take a fork of
`illumos/gcc` work within it, and use that tree with their build system.
Allowing much easier contribution of those changes upstream.

### Developing the illumos GCC

People wishing to work on newer versions of gcc may have the appropriate
branch created in `illumos/gcc` early in the development cycle to facilitate
cooperation with anyone else who may be planning a similar update.

Changes wishing to be integrated to illumos/gcc should be submitted in the
form of pull requests where that is possible, or github issues requesting a
branch be created onto which pull requests may be submitted, or a branch be
pulled up into `illumos/gcc` to establish a new version branch.

### Endorsing a new version of GCC for use with `illumos-gate`

New versions of GCC for `illumos-gate` need to be discussed with the
advocates.

Test results from the GCC suite should show no regressions from a mainline
GCC of equivalent version, and any regressions relative to the last endorsed
GCC must be carefully evaluated (hopefully, there would be none).

Test results from the illumos tests should be favourably comparable to a
baseline with the current compiler, manual testing of debug facilities
(`-msave-args`/`libsaveargs`) should show no regressions.

A special class of bug which has proved difficult in the past is one which
influences _observability_ but not necessarily correctness.  Special care must
be taken to verify that the compiler has not regressed.  No fbt or pid probe
previously visible to DTrace should now be invisible.  Care should be taken
that GCC has not produced cloned special purpose versions of symbols (these
tend to be named in the form `foo.xy.N` where _foo_ is the original symbol,
_xy_ is an optimizer pass, and _N_ a sequence number).  CTF type information
should be checked compared to the old compiler (diffs of `ctfdump -c` are
helpful here).

### Submitting Patches to GCC

It would be good to begin the process of submitting patches upstream to GCC,
though historically we have not for various reasons.  Some of our patches are
particularly opinionated and unsuitable for general use, and will likely be
our own forever.  Patches not in this category should at least be considered
for submitting upstream.

---
author: Richard Lowe, John Levon
state: published
---

# IPD 7 illumos GCC maintenance

## Introduction

This IPD describes the use and maintainence of the illumos-specific GCC branch
used for building, found on GitHub at http://github.com/illumos/gcc.

## Status Quo

The currently used branches of `illumos/gcc` are:

| name       | description                                                   |
| ---------- | --------------------------------------------------------------|
| `il-7_3_0` | GCC 7.3 branch: current primary used illumos-joyent           |
|            |  next primary compiler                                        |
| `il-7_4_0` | GCC 7.4 branch: current primary, basis for OpenIndiana and    |
|            | OmniOS compilers                                              |
| `il-4_4_4` | GCC 4.4.4 still used for shadow compiler                      |

Right now, the GCC 4 shadow is only there in case we discover a bug serious enough
that we need to back away from GCC 7.

Each version of the compiler we intended to endorse/insist upon the use of
during the RTI process is tagged in the form `gcc-X.Y.Z-il-N` where _X.Y.Z_ is
the GCC version, and _N_ is a monotonically increasing integer to
differentiate versions of our patches.

Other branches may exist in the form of work-in-progress or candidate builds.

Note that as per above, both OI and OmniOS have some slight differences so don't
use the branch as it is exactly.

## Method of Shipping the Patched GCC

Distributions can take the tarball provided from the github tags and versions,
and integrate that into their build systems as the upstream tarball, not
needing to maintain a patch set based on our git repository.

Alternatively, distributions wishing to update or further patch GCC can easily
take a fork of `illumos/gcc` work within it, and use that tree with their build
system. Allowing much easier contribution of those changes upstream. The intent
is that any suitable changes are folded back into the official branch and release
tags as needed.

## Developing the illumos GCC

People wishing to work on newer versions of gcc may have the appropriate
branch created in `illumos/gcc` early in the development cycle to facilitate
cooperation with anyone else who may be planning a similar update.

Changes wishing to be integrated to illumos/gcc should be submitted in the
form of pull requests where that is possible, or github issues requesting a
branch be created onto which pull requests may be submitted, or a branch be
pulled up into `illumos/gcc` to establish a new version branch.

## Endorsing a new version of GCC for use with `illumos-gate`

New versions of GCC for `illumos-gate` need to be discussed with the
advocates. In general, moving to a newer version of GCC involves co-ordination
between the main stakeholders (OpenIndiana, Joyent, and OmniOS, most usually),
and a set of testing/validation.

### Testing

Updating the compiler, especially over a major version, has historically been
a tricky proposition, often involving new optimizations that break code (admittedly,
usually code relying on undefined behaviour). Careful testing should be done
of any change.

Test results from the GCC suite should show no regressions from a mainline
GCC of equivalent version, and any regressions relative to the last endorsed
GCC must be carefully evaluated (hopefully, there would be none).

Test results from the illumos tests should be favourably comparable to a
baseline with the current compiler, manual testing of debug facilities
(`-msave-args`/`libsaveargs`) should show no regressions. The DTrace test
suite in particular is relevant here.

A special class of bug which has proved difficult in the past is one which
influences _observability_ but not necessarily correctness.  Special care must
be taken to verify that the compiler has not regressed; some specific things
to look out for are:

1. No fbt or pid probe previously visible to DTrace should now be invisible.  Care should be taken
that GCC has not produced cloned special purpose versions of symbols (these
tend to be named in the form `foo.xy.N` where _foo_ is the original symbol,
_xy_ is an optimizer pass, and _N_ a sequence number).

1. CTF type information should be checked compared to the old compiler (diffs of `ctfdump -c` are
helpful here). There is often some natural churn, but any significant differences in missing or different types should be evaluated carefully.

1. Some spot checking of fbt probe location is good: check that fbt begin probes
are placed before any branches at the start of the function. This is what `-fno-shrink-wrap`
is for.

1. It's worth reviewing the list of https://gcc.gnu.org/onlinedocs/gcc-7.4.0/gcc/Optimize-Options.html for
any new compiler version, to see if there's any pernicious things we might want to disable. The list of
optimizations we need to disable seems to grow every time we update.

1. Check through the list of changes (e.g. https://gcc.gnu.org/gcc-7/changes.html) for anything that might affect us

## Submitting Patches to GCC

It would be good to begin the process of submitting patches upstream to GCC,
though historically we have not for various reasons.  Some of our patches are
particularly opinionated and unsuitable for general use, and will likely be
our own forever.  Patches not in this category should at least be considered
for submitting upstream.

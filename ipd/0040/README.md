---
author: Richard Lowe
sponsor:
state: draft
---

# Cross compilation for illumos

As part of the [ARM project](../0024/README.md) a cross compilation
environment is necessary.  This has also been mooted as a desirable step for
restoring SPARC to life, or for any other future platform support in illumos.

Here we attempt to describe what has been done as part of the ARM project, and
any necessary future work, in terms separated from the specifics of that
project.

## Goals

We need to be able to build a full, valid, set of illumos packages on an
illumos host of a different architecture than that which we target.

## Non-Goals

Building on non-illumos hosts is a specific non-goal, but a future project is
welcome (and able) to tackle that using this as a starting point.

## Theory

### Build system

Within the illumos build system, we already refer to the target machine
symbolically via the `$(MACH)` and `$(MACH64)` macros, which are used
throughout to refer to the host or target machine architecture (`i386` and
`amd64`, and previously `sparc` and `sparcv9` respectively).

We separate this into macros used for the target -- `$(MACH)` and `$(MACH64)`
as before -- and those for the host, `$(NATIVE_MACH)` and `$(NATIVE_MACH64)`.

All software built for the host machine must now use the `NATIVE` prefixed
macros (`NATIVECC` etc.) to do its work, and all native paths must be built in
terms of `$(NATIVE_MACH)` etc where relevant.

As an example, the tools install binary becomes
`$(ONBLD_TOOLS)/bin/$(NATIVE_MACH)/install` as `$(MACH)` now exclusively
refers to the target machine.

This leaves the majority of the non-native build system alone, as `$(MACH)`,
settings based on `$(MACH)` all continue to -- correctly -- refer to the
target environment.

### `ADJUNCT_PROTO`, or sysroot

We in illumos have the concept of an adjunct to the proto area where
dependencies for the target system required by illumos but not part of illumos
can be found.

This unfortunately was done to solve two somewhat related but actually
separate problems.

1. A desire to build in a logically cross-compilation environment where other
   software for the target system does not match that on the host.
2. A need, on SmartOS from where this work originated, to not rely on the
   contents of /usr which are read-only and derived from the boot media.

We make the treatment of #1 more thorough, at the expense of making #2
somewhat more problematic.

The concept of the adjunct proto is extended to make it an actual sysroot,
rather than just one in spirit.

This means that (for builds targeting the target rather than the build
system), `ADJUNCT_PROTO` is used fully instead of the root file system, rather
than in addition to it.  This fulfils both our goal of not using any
build-system files for a target build (which would otherwise either fail
mysteriously, or succeed erroneously), and one of the original goals of
`ADJUNCT_PROTO`, that a native build in an adjunct environment is _really_ a
cross compilation to a different system of the same ISA.

The #2 use of the adjunct proto makes life more complicated.  Theoretically,
anything not in the (incomplete, SmartOS) adjunct will be found from the
build proto area.  Unfortunately this is not _quite_ true for complex reasons,
and likely SmartOS will need to arrange to have, at least, the C runtime
objects in their proto area.  It would be better, both from a correctness and
a maintenance standpoint, for SmartOS to switch to a complete sysroot, but I
understand that their build system does not allow for this in practice.

We have elected to solve the larger problems thoroughly, and trust in the
SmartOS maintainers to fix the problems specific to their system.

It is envisioned that in the majority of situations a suitable system root can
be constructed via the operating system packaging facilities installing into
an alternate root directory.

Using the image packaging system as an example one can `pkg image-create` a
zone image, and install precisely that software into it that is suitable for
the target machine.  Archives of these images can be distributed to end-users
or other build machines, either in the form of tarballs, package `.p5p`
archives, etc.

Other systems could use their native package format to do the equivalent, or
otherwise use the root filesystem image output from an appliance build
process.

### Tools

We will require all our build tools to be capable of operating in a cross
environment, ideally without further help (such as is the case with `ld(1)`,
etc.), at worst the addition of a `--target` type argument.

Tools such as `cw(1ONBLD)` have been modified to remove all their
target-specific knowledge, other tools are innately ok, some tools, such as
`dtrace(8)` and `elfwrap(1)` require future work.

## Operation

A new `-T` flag is added to `nightly(1ONBLD)` and `bldenv(1ONBLD)` allowing the
specification of the machine the build is to target, it is envisioned that
environment files will be specified such as to be correct regardless of
machine by overriding the `$(MACH)`-prefixed variables rather than their uses.
For instance, one would set `i386_PRIMARY_CC` and `aarch64_PRIMARY_CC` not
`PRIMARY_CC`.

`nightly` and `bldenv` are further adjusted to make clear what is being built,
with `bldenv` saying:

```
Build type   is aarch64/DEBUG (cross)
VERSION      is arm64/pkgdepend-0-g18528b4d131
RELEASE_DATE is April 2023
```

For a cross build from i386 to aarch64, for example, and nightly's output
including the target in its header lines

```
==== Build errors (aarch64/DEBUG) ====
```

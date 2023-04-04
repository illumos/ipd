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

### Tools

We will require all our build tools to be capable of operating in a cross
environment, ideally without further help (such as is the case with ld(1),
etc.), at worst the addition of a `--target` type argument.

Tools such as cw(1ONBLD) have been modified to remove all their
target-specific knowledge, other tools are innately ok, some tools, such as
`dtrace(8)` and `elfwrap(1)` require future work.

## Operation

A new `-T` flag is added to nightly(1ONBLD) and bldenv(1ONBLD) allowing the
specification of the machine the build is to target, it is envisioned that env
files will be specified such as to be correct regardless of machine by
overriding the `$(MACH)`-prefixed variables rather than their uses.  For
instance, one would set `i386_PRIMARY_CC` and `aarch64_PRIMARY_CC` not
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

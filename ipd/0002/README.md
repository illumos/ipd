---
authors: John Levon <john.levon@joyent.com>
state: predraft
---

# IPD 2 Running smatch for Illumos builds

## Introduction

As part of Illumos's historical inheritance we, until very recently, ran lint
against a significant portion of the source code (as mostly defined by
[Makefile.lint](https://github.com/illumos/illumos-gate/blob/master/usr/src/Makefile.lint)).

This was a continuing pain point for Illumos developers: we don't have the lint
source, and the current version we have access to is gradually getting less and
less able to compile the source it's given. Use of lint was also a blocker for
other improvements, such as an improved definition of `NULL`.

Recent consensus has led to us removing the requirement for developers to lint
their changes.

However, lint was still finding real bugs. In particular, complaining about code
that fails to check the return value of functions still seems useful; it's
highlighted real bugs in the past, and seems likely to continue to do so.

While newer GCC versions have greatly improved checks, this particular checking
behaviour is not supported by any warning option. GCC can only check return
values for functions explicitly marked, and does not respect cast-to-void, which
we use to silence lint right now.

There is an alternative: [smatch](https://repo.or.cz/w/smatch.git).
This is a [sparse](https://sparse.wiki.kernel.org/index.php/Main_Page)-based
static checker, mainly aimed at the Linux kernel. While it has a large number of
Linux-specific checks, it's also usable as a general static checker. What is
particularly interesting about smatch is that it is written in C, and is easily
hackable. This should be considered a great advantage over many other checkers,
which are either closed source, written in a language understood by few, or
both.

A proof of concept has demonstrated that smatch can be used to replace at least
the checked-return functionality of lint across the Illumos source base. In
fact, the POC is already far superior to that of lint: the parser catches calls
through function pointers that lint does not, does not complain about `memset()`
or `printf()` etc.

The approachability of smatch is also appealing for other reasons, as it would
also to add source-specific checks relatively easily. For example, unchecked
`kmem_alloc(..., KM_NOSLEEP)`, unchecked user-supplied integers, Spectre gadget
discovery, etc.

## Implementation

Currently smatch is able to compile all of the Illumos gate, modulo some code
that uses `_Complex` and related types. This is implemented by defining smatch
as a shadow compiler: since smatch is designed to effectively take all of GCC's
options, this works relatively well.

A number of options were considered for disabling or modifying smatch checks for
parts of the source. For example, it makes little sense for us to run smatch
against some 3rd-party source integrated into `illumos-gate`.  A source base
with some ... history ... uncovered quite a few peculiarities that required
smatch changes. Code like:

```
#define elink_cb_get_friendly_name(cb) ''
```

or

```
char *
copyn(s1, s2, n)
register char *s1, *s2;
{
```

requires either disabling smatch for that code, or disabling one or more of the
smatch checks. Some of the latter are sparse-level, and may lack a disabling
flag in upstream; these are being added to smatch as needed.

As smatch is a shadow compiler, it runs against *all the code*, as opposed to
lint, which was a separate pass defined in Makefiles. The approach being taken
is to modify the Makefiles as needed. For example, to completely disable smatch
in a sub-directory:

```
CERRWARN += $(DISABLE_SMATCH)
```

which becomes `-_smatch=off`. *cw* will spot this and not run smatch against
those source files. `usr/src/Makefile.smatch` also defines a few default flags,
where the checks are triggered by too many false positives, or too much legacy
code.

Specific checks can also be disabled (or enabled) like this:

```
CERRWARN += -_smatch=--disable=uninitialized,check_check_deref,unreachable
CERRWARN += -_smatch=-Wno-vla
```

(The latter is an example of sparse-level check.)

This will mean a large number of one-line changes to Makefiles, but ultimately
seems preferable to disabling large sections of the source base like
`Makefile.lint` does. Where infeasible, we will still be disabling smatch for
particular sub-directories.

A related question is how to integrate smatch itself into the build environment.

smatch itself ships with data files that are closely tied to the source base
under inspection. The current version defines two different projects,
`illumos_kernel` for `usr/src/uts` and `illumos_user` for the rest of Illumos,
and specific function names are listed there for various reasons. We also
anticipate some source-specific checks being added as described above.

For these reasons, it seems preferable to ship a version of smatch source under
`usr/src/tools`, and build and run it directly from there. Exactly how that
deliver should work is not yet clear. The most obvious way would be a git
submodule, but it also seems reasonable to just directly import by hand as
needed (an identical copy of `github.com/illumos/smatch/tree/illumos`).

## Upstreaming changes

As mentioned above, there have already been several changes as part of the proof
of concept, and upstreaming is progressing well. There will inevitably be some
changes not relevant for upstreaming though. In particular, it doesn't seem to
make sense to upstream the Illumos data files themselves, as they are tied to
the source revision, not smatch itself. There is also at least one change
rejected by upstream that we rely on.

## Updating smatch

If we need to resync with upstream smatch, the procedure is as follows:

1. Pull upstream into the `master` branch of `https://github.com/illumos/smatch`
1. Merge into the `illumos` branch.
1. Tag as e.g. `0.9.1-il-1`
1. Copy sources over to `illumos-gate` `usr/src/tools/smatch/src`
1. Update `usr/src/tools/smatch/Makefile` with the new tag information
1. RTI

## Caveats and Risks

smatch does not cover C++ code or SPARC code, unlike lint. Other architectures
are unknown.

smatch integration/compatibility with clang/LLVM is unknown.

smatch cannot parse everything in our gate, and has known deficiencies (for
example, `__NORETURN` is not properly respected).

Several locations cause smatch to time out (after 60 seconds typically). We
should investigate why, and potentially fix smatch.

sparse's handling of the default macro definitions is extremely basic: essentially,
we define just enough of the expected compiler and hardware environment to enable us
to compile the sources by hand. Even the `cgcc` wrapper provided with sparse hard-codes
a bunch of these macros. The risk here is that we miss significant checks by not defining
the right set of macros we expect.

If the upstream project dies for whatever reason, we will have the burden of
maintaining smatch, and potentially sparse, ourselves. However, if needed, the
size and scope of these projects mean this is fairly doable.

A larger risk is the upstream sparse project taking a radical direction that
does not suit our needs.

## Policy changes

It's anticipated that at some point we would require a clean smatch build for
changes submitted to RTI.

## Future work

As mentioned, there are a lot of additional checks that could be added.

smatch can also be used in a looser analysis sense, for investigating properties
of the source. For example, it's possible to use smatch for tainting data.

We could gradually enable more smatch across the source base.

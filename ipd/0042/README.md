---
authors: Peter Tribble <peter.tribble@gmail.com>
sponsors:
state: draft
---

# IPD 42 Sunset native printing

## Introduction

The native print system in illumos has received essentially no attention
throughout the lifetime of the project. Distributions, by and large,
ship CUPS - a modern, supported print system that is also widely used
elsewhere.

At this time the native printing components are dead weight, and are
potentially blockers for other projects, such as

* [IPD 14 illumos and Y2038](../0014/README.md)
* [IPD 24 Support for 64-bit ARM](../0024/README.md)

largely due to the current implementation being purely 32-bit.

The actively supported printing consumer in illumos is the smb stack, which
uses CUPS.

A combination of lack of use, lack of maintenance, no 64-bit code, and the
presence of a superior alternative, suggests that removal of our implementation
would be beneficial.

## Packages

The following packages (under usr/src/pkg/manifests) would be affected. All
content would be removed and the packages marked obsolete.

* compatibility-ucb.p5m
* print-lp-compatibility-sunos4.p5m

The lp links are in the 2nd package; the man pages are in the first.

* library-print-open-printing-ipp.p5m
* library-print-open-printing-lpd.p5m
* library-print-open-printing.p5m

This is libpapi. There's also usr/src/man/man3/Intro.3 and
usr/src/man/man3lib/libpapi.3lib.

* print-lp-filter-postscript-lp-filter.p5m
* print-lp-ipp-ipp-listener.p5m
* print-lp-ipp-libipp.p5m
* print-lp-print-client-commands.p5m
* print-lp-print-manager-legacy.p5m
* print-lp.p5m

There are some packages that contain print-related files:

* consolidation-osnet-osnet-message-files.p5m
* system-trusted.p5m

There are html files really associated with trusted. Given that the
auths are only implemented for our print system, not CUPS, we should
probably remove these and at least the reference to the html help from
auth_attr, if not the actual auths themselves.

There are also print files associated with putting labels on printed
files.

## Source code

This implies the removal of

* usr/src/cmd/print
* usr/src/cmd/lp
* usr/src/lib/print

And man pages

* cancel.1
* download.1
* dpost.1
* enable.1
* lp.1
* lpstat.1
* postio.1
* postprint.1
* postreverse.1

* lpc.1b
* lpq.1b
* lpr.1b
* lprm.1b
* lptest.1b

* printers.5

* accept.8
* lpadmin.8
* lpfilter.8
* lpforms.8
* lpget.8
* lpmove.8
* lpsched.8
* lpset.8
* lpshut.8
* lpsystem.8
* lpusers.8

And references exist in

* nsswitch.conf.5

## Open Questions

Should printer support be removed from nsswitch?

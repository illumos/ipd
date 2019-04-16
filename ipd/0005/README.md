---
authors: Peter Tribble <peter.tribble@gmail.com>
state: draft
---

# IPD 5 Rationalize SPARC platform support


## Introduction

The illumos codebase contains support for a large variety of Sun
desktops and servers. Given that some models are old, rare, and expensive,
there's a likelihood that nobody running illumos will ever possess some
of these hardware models, and some of the code we have may not only be
useless, but also untestable.

What of this code is useful and worth keeping and fixing, and what should
be dropped?

The aim of this project is twofold: to reduce the maintenance burden by
removing code that has no utility, and enabling better code quality and
support for the platforms that remain.

This project takes place in the context of significant changes within the
illumos ecosystem, namely: the addition of gcc7 as a shadow compiler (and
its potential promotion to the primary compiler), the replacement of lint
by smatch, redefinition of NULL, and other potential modernizations of the
toolchain (amongst which, on SPARC, we might include replacemnt of the
old Sun assembler with the GNU assembler). Clearly, reducing the volume
of code to be modernized would be a benefit.

The plan is to keep support largely as-is for the sun4v platform, but to
limit sun4u support to those systems which current users either have or
might easily be able to obtain. This essentially means that we will support
desktop or volume server systems, but remove support for the specialist
high-end server ranges.

An informal survey of SPARC models known to be currently running an illumos
distribution, or that have run illumos in the past, generated no surprises:

* Ultra 5
* Ultra 60
* Sun Blade 1000
* Sun Blade 1500
* Sun Blade 2000
* Sun Blade 2500
* V210
* V240
* V245
* V490
* T1000
* T2000
* T5120
* T5220
* T5140
* T5240

## Candidates for removal include:

The starfire range - the venerable Sun E10K. This has already been removed
in [10318](https://www.illumos.org/issues/10318).

The V880z, a dedicated graphics variant of the V880 with an XVR-4000 graphics
card, was removed in [6027](https://www.illumos.org/issues/6027).

The sunfire servers - E3000-E600, E3500-E6500. While not a terribly complex
platform, there are no known users, it's 2 decades old, and ties us to sbus,
sf, and socal.

The starcat range - The F15K and variants. Like the starfire, these were big
expensive systems requiring dedicated controller hardware.

The serengeti range, which are the newer Sun-Fire E2900-E6800 systems. Although
more modern, there are no known users, and there's a big blob of complex
code.

The Lightweight 8, or V1280, which is some serengeti boards in a
volume server chassis.

Certain Netra systems, specifically the NetraCT compactPCI blade chassis
systems. (Code names are montecarlo for the SUNW,UltraSPARC-IIi-Netract;
makaha for SUNW,UltraSPARC-IIe-NetraCT-40; sputnik for
SUNW,UltraSPARC-IIe-NetraCT-60; and snowbird for SUNW,Netra-CP2300.)

The B100s server blade.

## Candidates not marked for removal at this time

Certain platforms bring in a certain amount of code complexity which
would qualify them for removal, but there are good reasons for keeping
them.

The opl, or Olympus platform, which is the Fujitsu-derived M-series.
The reason here is that the M3000 model is readily available and cheap.
It may be possible to thin out the opl support to exclude the complex
domain and DR operations.

The Ultra-2, which would be the last remaining sbus system. The issue here
is that the Ultra-2 is the base platform from which many of the smaller
desktop systems are inherited.

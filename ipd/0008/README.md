---
authors: Peter Tribble <peter.tribble@gmail.com>
sponsors: Garrett D'Amore <garrett@damore.org>
state: published
---

# IPD 8 EOF NCA/NL7C

NCA/NL7C is a kernel-based web cache accelerator.

The current implementation in illumos is a compatible Network Layer 7 Cache
(NL7C) as part of SOCKFS. It's a replacement for the older SNCA product that
was designed to be more generic while implementing the same interfaces.

However, that generic extension never happened. So we have a subsystem that
only caches http, not https or http/2. Not only that, it doesn't work in
zones, which is where users expect applications to run, and it only supports
IPv4.

The web has moved on. Secure http is now expected and ubiquitous. Load
balancers and reverse proxies are commonplace. Modern web servers are
much more performant than in the past. Content Delivery Networks shoulder
the main burden of accelerating delivery of static assets to end users.

NCA in its current form is obsolete, misaligned with current practice, and
should be removed.

Removing NCA from the path also simplifies the implementation of sockfs and
sendfile.

## Implementation Tickets

Removing these bits is occurring in at least the following changes:

- [14767 retire kssl](https://www.illumos.org/issues/14767)
- [14768 retire nca](https://www.illumos.org/issues/14768)

---
author: Garrett D'Amore
sponsor:
state: draft
---

# EOF legacy Network Driver interfaces

## Introduction

Solaris networking has long heritage of supporting many different
networking technologies, and over the years numerous changes
to the network stack have occurred, but as each of these changes
has happened, more and more baggage (technical debt) has been
kept in the name of compatibility.

It's time to clean this up.

## Description

This technical debt adds to the maintenance burden, and winds up
bit rotting as the code paths no longer are executed or even testable.

Specifically, the following technologies are obsolete, and unlikely
to be used by any current illumos users.  (In some cases they have
been obsolete even before illumos was founded.)

1. Token Ring

   Token ring, aka IEEE 802.5, is a technology from the 1980s.
   In theory peak speeds of 100 Mbps were possible, but such
   devices were very rare, and users are more likely to have
   experienced 16 Mbps in the early 1990s.  PCI cards for this
   existed, but no driver for such hardware is known to have
   exist for Solaris or illumos.

2. FDDI

   Fiber distributed data interface, aka IEEE 802.4, was an optical
   networking technology.  It was used in some data centers on SPARC
   and Sbus cards. It has a maximum speed of 200 Mbps, and a larger
   4K MTU, which made it interesting in the 1990s.  It is unknown if
   an x86 driver for any hardware for illumos existed; a PCI form-factor
   was known to exist.  (Ethernet owes a lot to work done by FDDI.)
   
3. DLPI (specifically driver support)

   Historically, SYSVR4 network drivers (and Solaris drivers by
   derivation) implemented to a standard called the Data Link Provider
   Interface (and most recently -- in the 1990s, DLPIv2).

   The DLPI is a streams based interface for device drivers.
   It was replaced in Solaris 10, as it was found that the lock
   contention caused by STREAMS greatly limited scalability.

   Not all device drivers were converted -- specifically some
   network device drivers produced exclusively for SPARC were
   never converted.  (The most famous of these is Cassini.)

   Some enhancements were made (extensions) to help DLPI drivers
   perform better.  The M_MULTIDATA message type being the primary
   one.  The Cassini driver is the only known consumer of this, and
   that driver has never been made open source, nor is it supported
   on x86 illumos systems.

   Note that the DLPI is still provided by the GLDv3 (mac) framework,
   for application use.  Applications may use the DLPI to access
   low-level details or for accessing raw link layer protocols.
   This IPD does not propose to change the support by GLDv3 for DLPI
   applications.

4. GLDv2

  Because the DLPI (and STREAMS) was difficult to write to, the
  Solaris team created a generic layer, the GLD (generic LAN driver)
  that was intended to make writing typical network drivers easier,
  and move much of the common trickier parts of the STREAMS and
  DLPI logic into a common driver maintained by the OS team.
  This layer was enhanced at one point to be the GLDv2 we have now.

  The GLDv2 was used by a number of drivers before GLDv3 was
  widely available.  Note that GLDv3 is a completely different beast,
  and there is no code shared between GLDv2 or GLDv3.

  In the Solaris 10 time frame, some open source developers
  (including the author!) wrote GLDv2 drivers, and there were a
  few GLDv2 drivers in the core OS as well.  Since that time, all
  such drivers have been converted to GLDv3.

  It is believed that there are no longer any users of the GLDv2.

5. Softmac (partial)

  The Softmac was created mostly as an adaptive layer between the
  GLDv3 and DLPI and GLDv2 drivers.  Every driver uses it indirectly,
  as it plays a role in the vanity network naming logic, and it
  collaborates with dlmgmtd for this purpose.  However, the vast
  majority of the code in it is an attempt to provide compatibilty
  for legacy networks.  With the sunset of SPARC, the last such
  legacy network card of any possible interest (Cassini) is no longer
  a concern.  We can clean all this up.

6. M_MULTIDATA

  In order to help legacy Cassini and DLPI hardware perform well,
  a special message format was provided to help amortize the cost
  of traversing the STREAMS boundaries.

  However, the complexity of this means that numerous STREAMS
  functions have to specifically check each message to see if they
  are of this form.  This is a tax on all network traffic,
  as well as a lot of non-network traffic (e.g. serial ports
  and ttys are implemented using STREAMS).

7. DLPI style 2 nodes.

  DLPI drivers historically could support minor node cloning
  by creating a special "UNBOUND" minor instance, e.g. "/dev/hme".

  An open of this special minor number was not associated with
  any real instance, but the STREAM would be bound to a specific
  interface (PPA) using a DLPI message. This style of access was
  common with most legacy SPARC network drivers.  It was also
  responsible for many race conditions and bugs in the early 2000s.
  (It is also partly why we need getinfo(9e).)

  A simpler interface exists, where the PPA is part of the device
  minor node.  For example, instead of "/dev/hme" we have "/dev/hme0".
  This is the style 1 interface, and is supported by GLDv3.
  (Historically GLDv2 supported both style 1 and style 2 minor nodes.)
  
## Implementation Steps

In order to clean this up, there are distinct bodies of work that
can be taken.
Some of these have dependencies with each other, and some don't.


1. M_MULTIDATA support can just be removed.

   This is mostly finding and removing the references to it.
   This occurs mainly in the STREAMS utility functions, but also
   in the network layer.
  
2. Retire GLDv2.

   There are no more consumers for it.
   Removing it wil facilitate some of the other work, since
   it won't have to be changed as individual bits are removed.

3. Remove compatibility supoprt in the Softmac.
 
   This involves removing some special handling for Token Ring,
   as well as the entirety of the conversion support for non-GLDv3
   drivers.
   What's left should be scrutinized further -- perhaps net_dacf
   and the logic associated with setting up the vanity names can
   just be moved into the GLDv3 proper, since there won't be any
   other form of network driver.
   This should only happen once GLDv2 is removed.

4. Review remaining DLPI consumers -- if they have code implementing
   handling for style 2 nodes, that should be removed, assuming that
   style 1 is fully supported.

   If possible, these applications should be moved onto a more
   modern and mainstream socket interface.

5. Remove any remaining vestiges of FDDI and/or Token Ring.

   (There shouldn't be any.)
   Leaving behind defines to avoid reallocating numbers may
   be acceptable, but this should ideally be done in such a
   way to clean up the namespace pollution from such definitions.

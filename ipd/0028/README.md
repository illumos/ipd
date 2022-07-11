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
   experienced 16 Mbps in the early 1990s. No driver for such
   hardware exists for illumos (legacy SPARC drivers were closed
   source) and we do not believe anyone has ever used token ring with
   modern illumos or on Solaris x86, or in the past decade on SPARC
   for that matter.

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

  It is generally fairly trivial to convert a GLDv2 to GLDv3 -- the
  author of this IPD did numerous such conversions, including one that
  was done in a half-day on a bet (Stephen Lau, I think you still owe
  me something for that, but I don't remember what the stakes were!)

  In the Solaris 10 time frame, some open source developers
  (including the author!) wrote GLDv2 drivers, and there were a
  few GLDv2 drivers in the core OS as well.

  In the illumos source code, the only remaining direct consumer of
  GLDv2 is chxge. (The USB GEM module has code to support GLDv2, but
  it is a compile time option, and it uses GLDv3 by default.)

  Note that GLDv2 still sadly has aspects that are linked to STREAMs.
  The GLDv3 hides all streams based APIs from the driver author.

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
  
2. Convert chxgbe to use GLDv3

   This step is necessary before GLDv2 can be eliminated.
   Fortunately, the effort to perform such a conversion is generally
   not very large, and in so doing, we may expose additional capabilities
   to chxge (such as better support for multiple RX and TX rings)
   to take advantage of in future work.

3. Remove the #ifdef'd out for GLDv2 from usbgem.

   Not strictly required, but a nice clean up.
   This can happen immediately.

4. Mark GLDv2 and DLPI *Provider* Sides Obsolete.

   This means updating man pages and such to direct users towards
   GLDv3.  This can happen immediately upon approval.

5. Remove support for non-ethernet transports from GLDv2.

   There are no such consumers.  This can happen *now*.
   (GLDv2 retains code for FDDI, Token Ring, and Infiniband.
   Infiniband is already moved over to GLDv3, and the other two
   are already obsolete.  This can happen immediately upon approval.

   While here, we should remove support for style 2 nodes from GLDv2.
   There are exactly zero GLDv2 providers who need to export style 2 nodes.

6. Remove support for Token Ring and FDDI in any other places

   There is at least some special handling for TPR in softmac.
   Probably in other places (snoop?) that can be cleaned up.

7. Retire GLDv2.

   Once there are no more consumers for it, we can remove it.
   This may take some time, and we may need to figure out if there
   are other providers in the system.

8. Provide a modern TAP driver.

   The current TAP driver used with OpenVPN is based on DLPI.
   This could (and should!) be converted to a GLDv3 driver.
   The driver masquerades as an Ethernet device.  We should
   deliver this in-tree as well.

9. Remove the legacy DLPI logic in softmac. 

   This step can only happen once there are no more GLDv2 or
   pure DLPI providers left to worry about.  In particular,
   both chxgbe and tap will need to be addressed.  There may
   be others.

10. Remove DLPI conversion support in the Softmac.
 
   Most of softmac is a compatilibity shim to facilitate the
   use of DLPI (and also GLDv2) by making them appear as GLDv3.
   (There are some compromises made here, however.)  This code
   can go, once we have no such drivers any more.
   
11. Move the vanity naming from softmac to GLDv3.

  If we only have GLDv3 drivers, then GLDv3 can handle the part
  of softmac that exists to support vanity names.  This will
  simplify the logic, and allow us to remove net_dacf as well.

12. Consider eliminating support for style 2 DLPI PPAs.

  Some special providers (legacy tun/tap) behave as style 2
  providers.  If those are converted to GLDv3, then there won't
  be any further need for style 2.  Applications such as snoop that
  have code to work with style providers can be cleaned up.

  (Historical note: Originally some applications *only* had supoprt
  for style 2, because legacy Sun SPARC drivers only supported style 2.)

## References

* [PSARC 2002/276 TCP Multi-Data Transmit](https://illumos.org/opensolaris/ARChive/PSARC/2002/276/)
* [PSARC 2004/594 Multi-Data Transmit Extensions](https://illumos.org/opensolaris/ARChive/PSARC/2004/594/)

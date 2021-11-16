---
authors: Robert Mustacchi <rm@fingolfin.org>
state: predraft
---

# IPD 21 PCI Platform Unification

## Goal

Unify more of the PCI configuration and implementation logic to make it
easier to add support for more features and port the system to
additional platforms. This will serve as a template for other parts of
the system as well.

## Background

Due to the rather disparate nature of the PROM on SPARC systems and the
BIOS on x86, illumos has traditionally ended up with several different
drivers that re-implement major portions of PCI device enumeration and
root complexes. Sometimes, this is a case where an x86 driver was at one
point copied from SPARC and vice-versa. In particular, this has led to
several cases where the following are duplicated and different depending
on the platform:

* PCI device enumeration at boot time
* Entirely separate logic for hotplug enumeration
* Basic parts of nexus drivers
* Pieces like ioctls on devices can easily end up cross-platform

This has made things more challenging to fix in the system. For example,
consider the following:

1. Even on x86, the logic for how base properties are added to device
nodes varies between whether the device was hotplugged or not, leading
to more places to try and find things to catch.

2. Hotplug logic can deal with a bridge that doesn't have a valid PCI
bus assigned; however, boot-time code assumes that some firmware entity
(e.g. BIOS, PROM, etc.) has gone through and set up all the devices.
This makes it harder to actually run illumos on other systems and get
them going.

3. Adding support for new platforms and architectures means duplicating
a bunch of these and trying to figure out what it should be, which only
makes the problem worse.

The crux of this is that the platforms today are not well factored. This
will only get worse and makes it harder to add support for new
platforms. We know that there will be more coming with support for
aarch64, RISC-V, and even alternative firmware implementations on x86
which don't rely on ACPI/UEFI.

There are already several parts of the system that are generally
factored this way, even inside of the existing PCI code. For example:

* Most of the PCIe initialization and error handling has been
generalized.

* The PCIe bridge driver is mostly common code, with a bit of platform
specific code (e.g. pcieb_x86.c and historically pcieb_sparc.c).

* PCIe cfgacc bits are mostly common today, with callouts into platform
specific code.

This is a good step in the right direction, we just need to take this
another step further and continue this across the broader PCIe
implementation.

### Proposal

The primary thrust of this IPD is that we should take the existing x86
implementations of PCI functionality and over time, refactor it so that
there is a platform specific and general part to it. Concretely, this
means:

* Isolating things like ACPI. In particular, ACPI can be used on
multiple platforms (e.g. ARM SBSA); however, right now it is intimately
tied to an x86 implementation. Similarly, there are platforms that don't
use it.

* Either separating out platform-specific knowledge or being OK with
actually sharing that information between platforms.

More specifically, we'd like to do the following:

* First, introduce a new series of headers that describe platform
specific functionality that something needs to implement. The goal with
this is to be a general trend that other subsystems can use. These
headers would not be shipped and would reside in a new sys subdirectory:
`uts/common/sys/plat/`. The goal is to move platform-specific needs into
one location to make it easier to answer the question, 'what is required
to port illumos to a new architecture'.

* Introduce the first header and split into this which would be
`uts/common/sys/plat/pci_prd.h` which stands for PCI Platform Resource
Discovery. The goal of this would be to abstract the myriad resource
discovery initialization pieces from this. The initial split would would
leave the existing `pci_autoconfig` module still specific to x86 and
would transform a large chunk of the existing `pci_resource.c` logic
into an i86pc specific implementation.
    - This would require platforms to implement a new `pci_prd` module,
      which would become a dependency.
    - PCI bus renumbering is a specific feature that exists partially on
      x86 today. It theoretically uses the ACPI `_BBN` to renumber unit
      addresses; however, this has only ever been enabled for the Sun
      X8400. We would remove this logic from `pci_boot.c`. Importantly,
      this would only impact a single machine and even then, only if
      someone performed a fresh installation. Because every other x86
      system in the past decade has never utilized this, and this only
      comes into play upon first installation (because unit addresses
      are all cached), there is very litle impact from removing this.

Even just implementing this much will make it easier for folks who are
looking to port illumos to new systems by making it easier to see what
is actually platform specific here.

Once this is done there are several parallel pieces of work that can be
done:

* Right now there are three to four copies of the memlist code that all
work in slightly different circumstance and expect different things
around allocation. Some of these use both the forward and rear pointers,
while others don't. This makes it very hard to actually move memlists
around between subsystems. The various files all expect this to be moved
to common code, but none have been done today. This would seek to merge
the different implementations and allow this to be exercised by userland
test suites to aid in testing. We have found several bugs and
assumptions while prototyping various systems at Oxide in this disparate
logic.

* We could then fold in the PCI hotplug enumeration and the boot
enumeration into one. This would allow us to be able to handle PCI bus
renumbering at boot time which is becoming equally important for hotplug
systems when the platform firmware may not be able to accurately set
things up. This also would be a way to get rid of multiple settings of
the various reg properties.

* We could make the ACPI PCI platform resource discovery common code,
allowing for use on other architectures where ACPI is becoming more
prevalent for better and for worse.

* We could finally make the x86 `pci_autoconfig` module actually common
code, which would make it simpler to support a broader set of platforms.

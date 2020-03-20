---
authors: Robert Mustacchi <rm@joyent.com>
state: published
---

# IPD 9 PCI Alias Disambiguation

When a device is discovered, the operating system uses different
mechanisms to come up with a list of names that could be used to search
for drivers. In cases such as with USB and PCI, these IDs come from the
devices themselves. Such devices are called self-identifying, because
they can identify what they are compatible with on their own. For other
buses and devices, something else needs to provide that information.

Regardless of the source of such information, all of the list of names
are assembled into the `compatible` property on the device information
node. Here's an example of the compatible entry for a NIC on an x86
system retrieved by using the `prtconf -v` command:

```

name='compatible' type=string items=13
value='pciex8086,1533.15d9.1533.3' + 'pciex8086,1533.15d9.1533' +
    'pciex8086,1533.3' + 'pciex8086,1533' + 'pciexclass,020000' +
    'pciexclass,0200' + 'pci8086,1533.15d9.1533.3' +
    'pci8086,1533.15d9.1533' + 'pci15d9,1533' + 'pci8086,1533.3' +
    'pci8086,1533' + 'pciclass,020000' + 'pciclass,0200'
```

This compatible array has several different strings, each of which is a
possible match against a device driver. Device drivers are installed in
the system with a list of aliases in their packaging metadata. The array
is ordered with the most specific name first. Some device drivers attach
to very specific names while other drivers attach to a generic class. An
example of the latter is the NVMe driver.

Unfortunately, there are issues with ambiguity in PCI aliases. The rest
of this document provides background on how PCI and PCI Express naming
works, the underlying problem that has been observed in the wild, some
constraints on the solution space, and then finally proposes some
technical changes for illumos.

## Background

The use of the `compatible` array ties back into the Open Firmware
effort of Sun Microsystems that was adopted as IEEE 1275. While Open
Firmware was withdrawn as a standard, it is still used on illumos and it
is used on other platforms as part of the Device Tree specification used
by ARM, POWER, and others.

PCI and PCIe devices have a standard configuration space. This is a
space that can be queried by software. A portion of this space is used
to identify a device. A device has the following different pieces of
identification:

1. A numeric vendor identifier
2. A numeric device identifier
3. An optional subsystem vendor and device identifier
4. A device revision identifier
5. A class identifier

Each of the above is a 16-bit identifier. The vendor identifier is
assigned by the PCI SIG, the organization responsible for the PCI and
PCI express standards. The device identifier is assigned by the vendor.
Each vendor has its own device identifier space that it may assign as it
sees fit. This means that a device ID of 0x23 will be something
different depending on whom the vendor is.

A device may have an optional subsystem vendor and device identifier.
These may not be present or refer to the same vendor that made the
device. The vendor ID uses the same ID set that the basic device vendor
identifier uses. This is often used when someone rebrands someone else's
part. For example, Dell may sell a PERC hardware RAID controller. This
has often been an LSI/Broadcom chip under the hood. Such a device will
have LSI PCI IDs for the vendor and device ID; however, there will be a
Dell vendor ID and a Dell-specific device ID that might identify it as a
particular model of PERC.

The revision ID represent an optionally tracked hardware revision of a
product. It's meaning and what has changed between revisions varies
based on the device itself.

The class identifier is used to break up different devices into
different classes. Depending on the class, there may be some expectation
that a device implements a particular standard. For example, there are
classes for different generations of USB controller such as xhci and
ehci or there is a class that indicates something is an NVMe device. All
devices that implement those classes are expected to work the same way.
However, that is not true of everything. For example, the class that
most network interface cards belong to does not define an actual
standard.

The class identifier is split into three parts, each one byte in size: a
main class, a sub-class, and a register-level programming interface. For
example, xhci compliant devices have a main class of 0x0C - serial bus
controller, a sub-class of 0x03 - universal serial bus host controller,
and a programming class of 0x30 - indicating an xhci compliant device.

### Constructing the `compatible` array

From these five identifiers, we construct the `compatible` array for PCI
devices in a manner laid out by the PCI supplement to IEEE 1275. The
idea is that the most specific name comes first and the most generic
name is last. The names are the following:

1. Using the vendor, device, subsystem vendor, subsystem device, and
revision

2. Using the vendor, device, subsystem vendor, subsystem device

3. Using the subsystem vendor and subsystem device

4. Using the vendor, device, and revision

5. Using the vendor and device identifiers

6. Using all parts of the class

7. Using only the main and sub-class

To make this more concrete, consider a device with the following
properties:

| ID | Value (in hex) |
|----|----------------|
| Vendor | 8086 |
| Device | 8c31 |
| Revision | 4 |
| Subsystem Vendor | 15d9 |
| Subsystem Device | 806 |
| Main class | c |
| Sub class | 3 |
| Programming Interface | 30 |

This would result in the following values for each ID. Note, each ID is
prefixed with `pci` to indicate that it is an ID based on PCI.

1. pci8086,8c31.15d9.806.4
2. pci8086,8c31.15d9.806
3. pci15d9,806
4. pci8086,8c31.4
5. pci8086,8c31
6. pciclass,0c0330
7. pciclass,0c03

For each of the above aliases, we will check to see if the most specific
one matches a driver. If it matches, we will bind that driver to it and
then move onto the next. Most drivers usually match the vendor and
device identifier (number 5), but what is actually matched varies
depending on the device and what can be guaranteed.

### PCI Express

For the moment, we've talked mostly about PCI; however, many modern PCI
devices are almost all PCI Express devices. There was a Sun draft for
this that follows similar rules to the PCI form with two differences:

1. Instead of the string `pci`, the string `pciex` was used
2. The 3rd entry was removed, because of historical issues with using an
unqualified subsystem vendor and device ID.

In the original recommendations, the idea was that the PCI express
identifiers would replace the PCI identifiers. While this was enacted on
SPARC platforms, it is not the case on x86 systems. x86 based systems
have both the `pciex` and the `pci` versions of the aliases present,
first preferring the PCI express versions and then providing all of the
older PCI versions.

## Problem: Vendor/Device and Subsystem Vendor/Device conflicts

A fundamental problem with the scheme as described above is that we have
two different IDs that look the same to device drivers:

* The PCI Vendor and Device ID
* The PCI Subsystem Vendor and Device ID

The theory of Open Firmware was that the subsystem space and the primary
space would be managed and kept in sync. This suggests a belief that a
given ID has the same meaning whether it is in the normal vendor and
device space or it is in the subsystem vendor and device space.

Unfortunately, this isn't the case. I stumbled across this with the case
of an individual with an Ivy Bridge based NUC. The VGA compatible ID had
a subsystem and subvendor ID that ended up being the same as one that is
used on Skylake Scalable Xeons to represent the memory controller. While
normally we would bind the VGA driver to this based on the class code,
because a more specific ID came up, this is a problem.

Now, there are numerous issues here. While we can say that it's Intel's
fault for reusing an ID this way, it's not realistically to expect a
firmware change to those parts at this point to update the PCI IDs. In
fact, looking around, it's become clear that this isn't the first time
that this has happened. There are multiple other cases where this comes
up:

1. The x86 PCI code actually has a function to case for known issues
with this:
[subsys_compat_exclude()](http://src.illumos.org/source/xref/illumos-gate/usr/src/uts/intel/io/pci/pci_boot.c#2168).
It's notable that there are already cases where this exists.

2. Joyent has seen this with the amr driver on Dell systems with PCI ID
reuse. The following is from the Joyent bug report:

```
The SSID 1028,518 (along with, most likely, several others) was
originally used with boards that contained PERC/4DC RAID controllers.
Today it's being used as the SSID on the C8220 board. So every device on
the mainboard of this node will match "pci1028,518". Unfortunately, the
amr driver uses this alias. To the extent that it should be doing so at
all, it needs to use "pci1000,1960.1028,518" – the full VID/PID + SSID.
In fact, if Dell's older board were using the SSIDs properly, it's
likely that this alias would have matched many devices on that board as
well.

The result of trying to attach amr to the C8220 EHCI controller is that
the system hangs hard during boot.
```

The fundamental problem is that subsystem IDs are not being qualified in
the context of the vendor ID. While there was a hope that this would be
reasonable, as expressed in the original IEEE 1275 stuff, that's no
longer the case. This is mentioned as part of why it wasn't carried
over. A secondary case for scoping is how the PCI ID database shapes
information. It always scopes the subsystem IDs to a particular vendor
and device ID.

## Constraints on the Solution

There are a number of possible options to deal with this more generally
that might be considered, but have been ruled out based on various
issues.

### Subsystem Identifiers

A tempting solution is to remove the unqualified subsystem vendor and
device identifier from the PCI alias list. Unfortunately, there is no
way for us to successfully determine whether a given identifier such as
pci8086,2044 is a primary vendor or device identifier or the one related
to the subsystem. This has a couple of ramifications:

1. Many device drivers are explicitly using subsystem IDs in the form
described above in their driver manifests. This is on purpose and
qualifying it into a form that has the full IDs (variant 2) may not be
possible. We do know that there are drivers that are using this in part,
such as the `cpqary3` driver.

2. Even if we were able to determine which IDs are meant to be primary
IDs and subsystem IDs, we don't have a good way of determining what the
full set of vendor and device IDs that should go with a given subsystem
are.

### Removing PCI-specific Aliases

One proposal that came up in this specific case was to remove bindings
from the driver aliases. This comes from the observation that with most
new devices there are no traditional 66 MHz PCI parallel buses still on
motherboards and therefore we can remove all of the `pci` based aliases
while keeping the `pciex` specific ones.

Unfortunately, things aren't quite this simple. For a number of devices
that are found built into a chipset as part of the motherboard or CPU
specific devices that expose themselves through PCI as a configuration
mechanism, there do not have a PCI express capability header which is
required for us to believe that they are PCI express devices. We've seen
this on chipset-based devices included:

* NICs (e1000g)
* USB controllers (xhci)
* Temperature sensors (pchtemp)

This means that there's no good way for a number of device drivers to
avoid this alias problem by eliminating all PCI aliases. While some
drivers may be able to say this with more certainty and therefore
should, that is not universal.

### Aliases are opaque strings

Another important constraint is that the strings that are used to define
aliases are treated by the system as opaque strings that are matched for
strict equality and nothing else. This means that there is no use of
wild cards, regular expressions, or anything else. While it would be
possible to try and change this fact and introduce this into the system
and broader tooling, I don't believe that we need to at this time.

## Proposal: Alias Disambiguation

Concretely we should add two new forms to the `pci` alias scheme
described earlier. I call these `3a` and `5a`, as they are variants of
the above schemes. To distinguish as to whether something is the primary
vendor and device ID or if it is the subsystem (or secondary) vendor and
device ID, I propose adding a trailing note. So an ID that is the
primary version would have a trailing `,p` and the subsystem would have
a trailing `,s`. For example, `pci8086,2044,s` or `pci1234,5678,p`.

This would allow drivers that know they only want to match the primary
vendor and device ID to specify that and so avoid this issue when
dealing with devices that have PCI bindings. I would propose that we
insert these ahead of the duplicated entries. Note, these cannot replace
these entries, as both values are load bearing in most common manifests.
However, this would allow new drivers which know with complete certainty
that they should only match the primary IDs to not worry about this
problem.

This means that the new version of the order as laid out in the
background section would be:

1. pci8086,8c31.15d9.806.4
2. pci8086,8c31.15d9.806
3. pci15d9,806,s
4. pci15d9,806
5. pci8086,8c31.4
6. pci8086,8c31,p
7. pci8086,8c31
8. pciclass,0c0330
9. pciclass,0c03

We are not adding anything to the `pciex` scheme at this time as it does
not have this disambiguation problem. This problem only exists for the
`pci` scheme. Similarly, when the kernel already opts to drop the
unqualified subsystem values, we will not add the new disambiguated
subsystem value; however, we will still add the disambiguated device
value.

One concern with this proposal may be that we're deviating from what
Open Firmware describes as the default. Ultimately, there are a number
of devices and schemes that use and define their own compatible array
properties that don't fit any known scheme defined by Open Firmware.
Further, there are cases today where the kernel already eliminates the
unqualified subsystem ID when conflicts occur. This already causes us to
have the compatible array not be a strictly compliant Open Firmware
value. Ultimately, I believe this is OK. When others are trying to
interpret the values of the compatible array, they should really only be
doing string matching and not trying to interpret the meaning. If they
are, the ambiguous nature would already make that difficult.

Finally, to minimize additional problems in this space I would propose
the following rules for PCI driver aliases going forward:

* When adding ambiguous PCI IDs, we should always use the suffixed form
to disambiguate them.

* Where possible, if we're certain that a device will not be exposed
over legacy PCI, we should not add PCI aliases. As pointed out in the
constraints section, this will not always be possible.

* New platforms should follow the SPARC lead and only use the `pciex`
form for PCI express devices and not include the `pci` form.

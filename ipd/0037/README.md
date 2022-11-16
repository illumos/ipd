---
author: Robert Mustacchi <rm@fingolfin.org>
state: prediscussion
---

# IPD 37 Vendor-specific Command, Log, and Feature Support in nvmeadm(8)

Today, the [`nvmeadm(8)`](https://illumos.org/man/8/nvmeadm) tool
provides the many ways to understand and get information about NVMe
devices in an illumos system. Of particular relevance to us here is its
ability to obtain and process:

* Basic Controller and Namespace Information via `nvmeadm identify`
* Information about standard log pages via `nvmeadm get-logpage`
* Information about standard features via `nvmeadm get-features`

Unfortunately, like in the SAS and (S)ATA worlds of the past, there are
many vendor-specific and device-specific commands, log pages, and
features that exist and we would like to be able to handle. Vendors are
not particularly shy about these commands existing based on public code
in the current [nvme-cli project from
nvmexpress.org](https://github.com/linux-nvme/nvme-cli). That is, there
is reason that implementing these in standard tools would be useful.

In particular, the rest of this IPD goes into detail around:

* Extending nvmeadm to support vendor-specific log pages
* Extending nvmeadm and the nvme driver to support vendor-specific features
* Extending nvmeadm to support well-known vendor-specific commands
* Extending nvmeadm to support arbitrary, unknown commands
* Improving our ability to process data from these

## Background and Existing Work

As part of the NVMe protocol, there are several different groups or
types of commands. Today we primarily think of these as:

* **The Admin Command Set** -- which is used to interact with the device
to get basic information, manage firmware, create I/O queues, get
features and logs, etc.
* **The NVM Command Set** -- which is where the more traditional I/O
semantic commands come into play. For example, these cover basic things
such as read, write, flush, dataset management (e.g. trim, unmap), etc.

The way that this works out is that the one byte command code is broken
into a few ranges. There is a range reserved for well known use by the
spec (i.e. 0x00-0x7f), a similar well know range for I/O command sets
(i.e. 0x80-0xbf), and a specific set for vendor-specific commands, (i.e.
0xc0-0xff).

This pattern is not specific to just commands, but it is repeated for
many different data types, often with the same approximate ranges with
the following data types:

* Log pages
* Features
* Error Codes

Today, the illumos nvme driver supports the ability to query
vendor-specific log pages via the `NVME_IOC_GET_LOGPAGE` ioctl and to
run arbitrary vendor-specific commands via the `NVME_IOC_PASSTHRU`
ioctl. At Oxide, we developed and used both of these as part of looking
at and understanding different aspects of devices which includes
everything from running PCIe signal integrity checks to more detailed
logs around endurance, device activity, and related.

The ioctls were built with the intention of being plumbed into nvmeadm
so that way everyone can take advantage of this behavior and to make it
easier to experiment with commands. This gives us the framework to build
these features into nvmeadm without needing to update the driver for
each new vendor-specific command, which is a useful and important
ergonomic thing.

## Basic CLI Syntax

To identify vendor and device-specific commands, log pages, and
features, we suggest that we prefix each of these with the vendor's
name and use a `/` character to delineate between the vendor and the
specific command, feature, or log. As an example vendors would include:

* intel
* kioxia
* micron
* samsung
* solidigm (probably an alias to intel)
* wdc

Put together, these might look like:

* `nvmeadm get-logpage wdc/eol`
* `nvmeadm get-logpage micron/ext-smart`
* `nvmeadm get-feature intel/maxlba`
* `nvmeadm wdc/resize`
* `nvmeadm intel/clear-assert`

There are a few reasons that we structure the names this way:

1. It makes it clear to the user that these are specific to a vendor.
2. It is unlikely that we will have top-level commands, log pages, or
features in the standards that are specific to an existing vendor.
3. It also adds an eventual world (if it ever make sense) to allow
someone to refer to all of the log pages or features that are
vendor-specific (e.g. `wdc/*`). While this isn't something that we're
proposing or is necessarily a good idea, it is useful to see how it fits
in.

While from an argument parsing perspective and the existing nvmeadm
flow, this may not be ideal, this does fit in with basically giving the
user a more straightforward place to interact with the different
entries.

The vendor-specific top-level command space in nvmeadm does not need to
be a 1:1 mapping to device commands. Instead, it may be used to do more
complex things that require multiple commands. As an example, to perform
device margining, there may be several different commands that we want
to send to the device, I/O to perform, or other activities to get the
several different margining points required. Where applicable, we want
to make sure that these commands ultimately solve problems and that they
aren't there just for the sake of completion.

As we mentioned that we also want to support a general command that
would allow one to pass through all the data payloads and information to
run a command. Effectively, this is intended to wrap up the
`NVME_IOC_PASSTHRU`. For lack of a better name, this might be a
top-level `nvmeadm passthru`, which takes a series of required arguments
such as the opcode, any input data to send to the device, a place to
write output data from the device, etc.

### Listing Applicable Commands and Features

An important discoverability point is knowing what commands, features,
and log pages are applicable. Right now, the only way to know which log
pages you can actually get at is by looking at the manual page. When we
extend support for these, we should make sure there's easy syntax
whether through the help output, new top-level commands, or something
else such that you can discover what you can run on these devices as
part of using this at the CLI.

## High-level Implementation Notes

To start with, we propose creating a new series of headers for each
vendor in `<sys/nvme/VENDOR.h>`, so for example, `<sys/nvme/wdc.h>` or
`<sys/nvme/solidigm.h>`. The main goal of these headers is to contain
the actual definitions for:

* The actual identifiers for the log pages, features, and commands
* The actual corresponding structure definitions where appropriate

An important part of putting this in here is that we know that folks are
going to want to be able to leverage these in FMA as part of an
nvme-aware disk monitor and while we aren't quite at the point where we
want to create a shared library for management, this will allow us to at
least avoid replicating all of the internal logic to determine what
should and shouldn't be done.

Next, in nvmeadm, we would likely have unique `.c` files to cover each
vendor or depending on the complexity, the different devices from a
vendor. Our expectation is that the vendor name will map to a backend
here. It is then up to the backend to determine which of the commands
apply to a given device. This would be done based upon the PCI ID
information generally speaking.

Throughout the course of implementing this, we probably would come up
with strategies to make the amount of logic each backend needs to be
reduced and shared with a common implementation, but any such interfaces
would be private to nvmeadm and something that we will let the
implementation inform.

## Output Processing

Our experience with `pcieadm` and in particular the `show-cfgspace` and
`save-cfgspace` options at Oxide have taught us a few things that would
be valuable to apply to nvmeadm:

### Reading and Writing To Files

In general, the ability to save the raw binary data from a device to a
file and transfer that around is quite useful. That can then later be
processed by tools. So for example, it would be much more useful if we
could reuse all of the existing `nvmeadm identify` logic to not only
print information from the current system, but that which is gathered
elsewhere.

This means that we really want to have all of the identify, log page,
and feature commands write out the raw data that they get. It also means
that we want to be able to point nvmeadm at the raw binary data from
those for later processing. Specifically this would be something we want
to add into:

* `nvmeadm identify` (and its two variants)
* `nvmeadm get-logpage`
* `nvmeadm get-features`

This would likely require specific features to be listed with
`get-features` rather than assuming it is all of them. As an example,
`pcieadm` uses the `-f` option to read from a file. `smbios(8)` which
also supports this same logic uses the `-w` command. `pcieadm` uses a
distinct command. We propose for the time being to make this part of the
default commands.

As an example, you could imagine the following:

```
# nvmeadm identify-controller -w /tmp/nvme0.out
# nvmeadm identify-controller -f /tmp/nvme0.out
/tmp/nvme0.out: Identify Controller
  Controller Capabilities and Features
    Model:                                  HP SSD EX950 1TB
    Serial:                                 HBSE40251300937
    Firmware Revision:                      42A4SBMA
    Multi-Interface Capabilities
      Multiple PCI Express ports:           unsupported
      Multiple Controller Support:          unsupported
      Controller is an SR-IOV Virtual Function: unsupported
      Asymmetric Namespace Access Reporting: unsupported
    Maximum Data Transfer Size:             256kB
    Unique Controller Identifier:           0x0001
    NVMe Version:                           1.3
    RTD3 Resume Latency:                    500000us
    RTD3 Entry Latency:                     2000000us
    Controller Type:                        not reported
    FRU GUID:                               unsupported
    Command Retry Delay Time 1:             unsupported
    Command Retry Delay Time 2:             unsupported
...
```

The goal here is that regardless of which of these commands you used,
you'd be able to use all the processing flags regardless of which mode
it came in on. There would be a little trickiness as some parts of these
commands want different access to information that is gathered in the
`nvme_process_arg_t`; however, that should be something that we can deal
with generally.

Unlike the PCI tools, we may end up wanting to create a small header
that encodes a bit of additional information about the binary payloads
we output, but whether that is necessary or not is something we'll let
the implementation drive.

### Selecting Fields to Output

The ability to explicitly select which fields and sub-fields you care
about is very powerful. One of the challenges with nvmeadm today is that
the field you care about may be hidden under the `-v` flag or it might
not be. There is no easy way to determine that other than by looking at
the source code and trying either one. There also isn't a good rule of
thumb for when something should or shouldn't be verbose.

In addition, it's worth noting that a lot of information in a log page
or in the identify data structures, just like in PCI, is structured in a
few levels of detail. In addition, the top-level values all have
explicit short names. Let's look at an example:

In the Identify Controller Data Structure, bytes 95:92 are called the
'Optional Asynchronous Events Supported (OAES)'. The human readable
name, while a bit long is that whole thing ignoring the part in parens.
The short name is 'OAES'. A user may be interested in the value of this
field or they may be interested in a particular bit. In this case, bits,
8, 9, 11-14 all have specific disjoint meanings. Bit 9 says that the
device supports the 'Firmware Activation Notices'. So someone might want
to walk up and use `nvmeadm identify` to get at this single specific
bit.

So here's a few examples of what we logically want to be able to do:

```
# nvmeadm identify-controller -f ctrl.oaes nvme0
nvme0: Identify Controller
  Controller Capabilities and Features
    Optional Asynchronous Events Supported
      Namespace Attribute Notices:          unsupported
      Firmware Activation Notices:          supported
      Asynchronous Namespace Access Change Notices: unsupported
      Predictable Latency Event Aggregation: unsupported
      LBA Status Information Notices:       unsupported
      Endurance Group Event Aggregate Log Page Change Notices: unsupported
# nvmeadm identify-controller -f ctrl.serial,nvmcmd.nn,psd.0.mp nvme0
nvme0: Identify Controller
  Controller Capabilities and Features
    Serial:                                 HBSE40251300937
  NVM Command Set Attributes
    Number of Namespaces:                   1
  Power State Descriptors
    Power State Descriptor 0
      Maximum Power:                        9W

```

I'd like to propose that we add the ability to require a specific set of
hierarchical output from the identify, log page, and feature information
and make this a much more uniform experience. Our intent would be to
prove this out with the new vendor-specific features and if it proves
useful and we have ways to make it easy, then we'd use that.

In particular, what we're saying is that for every field of a data
structure (which we often break out ourselves) there is a short name
based on the NVMe spec, vendor docs, and us filling in things (ala
pcieadm) that can be used to select the very specific entries we want
from these data structures. If any of them cannot be found, that'll
cause a warning and `nvmeadm` to terminate non-zero.

For anything we do this too, there are a few other things that we should
do:

* Make it easy to list all the applicable fields and short names
* No longer use the `-v` flag to control what does and doesn't cause
visibility

One way to make it easy to show short names is to include an option to
always include it. So if we take the above examples and applied a flag
to print them (pcieadm uses `-n`) you'd see something like:

```
# nvmeadm identify-controller -f ctrl.serial,nvmcmd.nn,psd.0.mp nvme0
nvme0: Identify Controller
  Controller Capabilities and Features (ctrl)
    Serial (ctrl.serial):                   HBSE40251300937
  NVM Command Set Attributes (nvmcmd)
    Number of Namespaces (nvmcmd.nn)        1
  Power State Descriptors (psd)
    Power State Descriptor 0 (psd.0)
      Maximum Power (psd.0.mp)              9W
```

When it comes to just list fields, here this could look like wha we're
doing with pcieadm. Here's an example of its filter `-L` output which
just walks the data structures and prints the field names, ignoring the
values:

```
rm@atrium ~ $ pfexec /usr/lib/pci/pcieadm show-cfgspace -L -d nvme0 msix
SHORT                         HUMAN
msix.ctrl                     Control Register
msix.ctrl.size                Table Size
msix.ctrl.mask                Function Mask
msix.ctrl.enable              MSI-X Enable
msix.table                    Table Offset
msix.table.bir                Table BIR
msix.table.offset             Table Offset
msix.pba                      PBA Offset
msix.pba.bir                  PBA BIR
msix.pba.offset               PBA Offset
```

### Including the Raw Value in Output

One of the thing's that's been valuable in `pcieadm show-cfgspace` or
with `smbios` is the ability to also output the raw value that was
received alongside the normal output. For example:

```
rm@atrium ~ $ pfexec /usr/lib/pci/pcieadm show-cfgspace -d nvme0 pcie.linkcap
PCI Express Capability (0x10)
  Link Capabilities: 0x45c843
    |--> Maximum Link Speed: 8.0 GT/s (0x3)
    |--> Maximum Link Width: 0x4
    |--> ASPM Support: L1 (0x800)
    |--> L0s Exit Latency: 512ns-1us (0x4000)
    |--> L1 Exit Latency: 4-8us (0x18000)
    |--> Clock Power Management: supported (0x40000)
    |--> Surprise Down Error Reporting: unsupported (0x0)
    |--> Data Link Layer Active Reporting: unsupported (0x0)
    |--> Link Bandwidth Notification Capability: unsupported (0x0)
    |--> ASPM Optionality Compliance: compliant (0x400000)
    |--> Port Number: 0x0
```

While we translate the strings or other values into ranges and that is
what is also used for parsable output, we also make it easy to see what
the raw bit value was that was set or not to contribute to that.
Figuring out a more useful way of making this fit into the existing
`nvmeadm` output processing would be useful.

### Parsable Output

Right now the various pages, data structures, and related are all output
in their own ways. Tying this all together with libofmt would provide us
with a very useful way to slice and dice this for better consumption in
scripting or otherwise. Even just three basic columns described below
would be a boon:

* The short name of a field
* The human name of a field
* Its value

## Summary of Changes

This summarizes the changes that we'd like to make. First phase:

* Introduce `sys/nvme/VENDOR.h` header files with vendor-specific
commands, feature, and log page information.
* Provide support for these in nvmeadm
* Provide a generic passthru command
* Add support for vendor-specific features to nvme(4D)
* Put together the newer output features for these and support for
reading from a file

After this has been done, a second phase would be to incrementally
extend the existing log page, controller identify, and related output
processing based on the experience in the first. The exact split will be
based on the what we determine from the actual work that's done.

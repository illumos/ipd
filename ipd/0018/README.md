---
author: Andy Fiddaman
sponsor:
state: draft
---

# IPD 18 overlay network integration/upstream

## Introduction

In 2014, illumos-joyent gained support for a new dladm device called an
`overlay`. In 2020, illumos-omnios imported this feature which formed part
of their r151034 release. This IPD is to discuss how this feature can be
upstreamed to illumos-gate.

Overlay networks are a form of network virtualisation which, in illumos terms,
can most simply be thought of as an Etherstub which can span multiple hosts.

From the man page:

```
Overlay devices are a GLDv3 device that allows users to create overlay
networks that can be used to form the basis of network virtualization and
software defined networking.  Overlay networks allow a single physical
network, often called an underlay network, to provide the means for
creating multiple logical, isolated, and discrete layer two and layer
three networks on top of it.

Overlay devices are administered through dladm(1M).  Overlay devices
themselves cannot be plumbed up with IP, vnd, or any other protocol.
Instead, like an etherstub, they allow for VNICs to be created on top of
them.  Like an etherstub, an overlay device acts as a local switch;
however, when it encounters a non-local destination address, it instead
looks up where it should send the packet, encapsulates it, and sends it
out another interface in the system.

A single overlay device encapsulates the logic to answer two different,
but related, questions:

   1.   How should a packet be transformed and put on the wire?
   2.   Where should a transformed packet be sent?

Each of these questions is answered by a plugin.  The first question is
answered by what's called an encapsulation plugin.  The second question
is answered by what's called a search plugin.  Packets are encapsulated
and decapsulated using the encapsulation plugin by the kernel.  The
search plugins are all user land plugins that are consumed by the varpd
service whose FMRI is svc:/network/varpd:default.  This separation allows
for the kernel to be responsible for the data path, while having the
search plugins in userland allows the system to provide a much more
expressive interface.
```

In the illumos-joyent implementation, there is a single encapsulation plugin,
VXLAN, providing the Virtual eXtensible Local Area Network protocol,
[RFC7348](https://tools.ietf.org/html/rfc7348)

Three search plugins are implemented:

 * direct -
   A point-to-point module that can be used to create an overlay that forwards
   all non-local traffic to a single destination.

 * files -
   A plugin that specifies where traffic should be sent based on a mapping
   file.

 * svp -
   A dynamic plugin that uses a proprietry protocol (portlan) to look up the
   destination address for a frame.

> The `svp` plugin is Joyent Triton specific, does not exist in the OmniOS
> port and **is not part of this initial proposed upstream work**.

Due to the nature of Joyent SmartOS, with its read-only root and centralised
configuration file, support for overlay persistence was not required and
therefore not implemented as part of the integration. The OmniOS port
included additional work to enable persistence and this will be upstreamed
as part of this work.

## Approach

It is proposed to upstream code from OmniOS in three phases:

1. Any standalone pre-requisite changes, whether or not there is a consumer
   at this stage.

2. A commit implementing the overlay driver and the accompanying
   userland components. This will be usable but lacking features such as
   persistence across reboots.

3. Several follow-up commits from OmniOS.

## Commits

The commits which are proposed for the three phases are as follows. Each
change will also be updated as per current gate standards including removal
of lint targets and cleanups to whitespace etc.

> NB: Commits without an OS-xxxx ID are from OmniOS rather than Joyent SmartOS

1. Pre-requisites

  > Each of these will be reviewed and integrated separately.

* OS-3894 want librename
* OS-3886 Implement id\_space as a library
* OS-3884 Want libbunyan
* OS-4112 stack overflow from promisc callbacks
* OS-3893 sendfile compat checks shouldn't be done in so\_sendmblk
* OS-3948 refhash could be used outside of mpt\_sas
* OS-3949 want string property ranges for mac
* OS-3080 Need direct callbacks from socket upcalls via ksocket
* OS-3944 snoop should support vxlan
* OS-4245 mac\_rx\_srs\_process stack depth needs to account for harder usage
* OS-4009 Want UDP src port hashing for VXLAN

2. Main commit

  > This will be reviewed and integrated as one.

* OS-3000 I for one, welcome my overlay network overlords

  Including:

   * OS-3943 want vxlan support
   * OS-3945 want varpd direct plugin
   * OS-3946 want varpd files plugin
   * OS-3987 property looks better with a 'y'
   * OS-3983 overlay\_target\_lookup\_request() doesn't properly populate vlan
     info
   * OS-3000 I for one, welcome my overlay network overlords (add missing files)
   * OS-3960 varpd should drop privs
   * OS-3973 overlay\_target\_ioct\_list overdoes its copyout
   * OS-3218 libvarpd's fork handler is a time bomb
   * OS-3993 overlays sometimes think they're vnics
   * OS-4010 Automate assigning rings to overlay based vnics
   * OS-4080 launching a second varpd confuses the world
   * OS-4077 varpd should live in /usr/lib
   * OS-4079 zero out the fma message on restore to help with mdb confusion
   * OS-4087 dladm show-overlay -f doesn't properly show degraded state
   * OS-4111 dladm show-overlay often has column overflow
   * OS-4159 error messages when dladm create-vnic fails are mostly useless
   * OS-3958 want documentation for overlay devices
   * OS-4182 need dladm create-overlay -t
   * OS-4174 long options for dladm \*-overlay
   * OS-4179 want search plugin in overlay property list
   * OS-4181 Clean up duplicate VXLAN\_MAGIC definition
   * OS-4179 want search plugin in overlay property list (fix debug)
   * OS-4370 varpd should support getting an include path from SMF
   * OS-4203 varpd stayed in carbonite after signal delivery
   * OS-4373 varpd plugins should not link against libvarpd
   * OS-4397 varpd dumps core due to race on shutdown
   * OS-4086 overlay driver can lose track of link status
   * OS-3994 varpd loses PRIV\_DL\_CONFIG
   * OS-5298 overlay driver degradation shouldn't impact data link status
   * OS-5299 varpd direct plugin doesn't properly restore its mutex
   * OS-6890 .WAIT doesn't work as an actual target in varpd
   * OS-6943 varpd not listed as an install\_h target
   * OS-6946 varpd structs fail ctfdiff check
   * OS-6980 libvarpd leaks varpd\_query\_ts
   * OS-6847 vxlan header allocation should think about mblk chains
   * OS-7243 libvarpd\_c\_destroy gets away with pointer murder
   * OS-7501 overlay(7D) can receive packets with DB\_CKSUMFLAGS() set
   * OS-7516 so\_krecv\_unblock() double-mutex-exits
   * OS-4498 custr\_cstr() should never return NULL (overlay)
   * OS-8027 reinstate mac-loopback hardware emulation on Tx (undo OS-6778)
   * OS-6127 "dladm show-overlay <overlay>" exits zero when varpd doesn't know
     about the overlay
   * OS-7276 various illumos fixes needed for newer GCC versions (overlay)
   * OS-6920 Split the custr functions into their own library (overlay/dladm)
   * OS-7141 Overlay device-creation weirdness contributes to varpd boot
     failures
   * OS-6908 Makefiles missing 'all' target
   * OS-4958 Typo in overlay.5
   * OS-6175 fix manual pages for newer mdoc lint
   * OS-4928 overlay\_files.4 broken with new mandoc
   * OS-5377 stack overflow from round trip through mac and overlay
   * OS-7088 cyclics corked on overlay socket with full queue (#335)
   * dladm: remove unused function prototype
   * varp no-longer needs -lnsl
   * dladm now links with libvarpd (fix rcm)
   * varpd: Remove duplicate clobber target
   * Fix crash in dladm create-overlay
   * Add VXLAN to etc/services
   * overlay: Add package manifest

3. Follow-ups

  > Each of these will be reviewed and integrated separately.

* Add missing overlay class to show-link description
* Add stderr as default varpd bunyan stream
* Show a better error message when a VNIC cannot be brought up on an overlay
  network due to the encapsulation plugin being unable to bind a socket
* Overlays should persist across reboots

## References

* https://man.omnios.org/man5/overlay.5.html
* https://github.com/joyent/illumos-joyent/blob/dev-overlay/README
* http://dtrace.org/blogs/rm/2014/07/25/illumos-overlay-networks-development-preview-01/
* http://dtrace.org/blogs/rm/2014/09/23/illumos-overlay-networks-development-preview-02/
* https://tools.ietf.org/html/rfc7348


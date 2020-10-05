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

 * direct
   A point-to-point module that can be used to create an overlay that forwards
   all non-local traffic to a single destination.

 * files
   A plugin that specifies where traffic should be sent based on a mapping
   file.

 * svp
   A dynamic plugin that uses a proprietry protocol (portlan) to look up the
   destination address for a frame.

The `svp` plugin is Joyent Triton specific, does not exist in the OmniOS
port and is not part of this initial proposed upstream work.

Due to the nature of Joyent SmartOS, with its read-only root and centralised
configuration file, support for overlay persistence was not required and
therefore not implemented as part of the integration. The OmniOS port
included additional work to enable persistence.

## Approach

## References

* https://man.omnios.org/man5/overlay.5.html
* https://github.com/joyent/illumos-joyent/blob/dev-overlay/README
* http://dtrace.org/blogs/rm/2014/07/25/illumos-overlay-networks-development-preview-01/
* http://dtrace.org/blogs/rm/2014/09/23/illumos-overlay-networks-development-preview-02/


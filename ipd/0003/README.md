---
authors: Andy Fiddaman <andy@omniosce.org>, Robert Mustacchi <robert.mustacchi@joyent.com>
state: draft
---

# IPD 3 Link management improvements

## Introduction

The illumos [dladm](https://illumos.org/man/1m/dladm) command manages datalinks
(hereafter referred to as just _links_) including physical devices, etherstubs
and VNICs.

In illumos today, links are zone-namespaced. That is, a link's full name is its
vanity name - that shown by commands such as `dladm` - and the zone in which it
currently resides.

In theory this allows link names to overlap as long as the links are in
different zones; in practice, this feature is not usable due to a number
of problems.

This IPD proposes a change to the implementation that makes link management
more flexible and would allow overlapping names to be used if desired, while
preserving support for the different ways in which links are currently used
in illumos distributions.

## Current Issues

### Name Collisions

Link names can overlap as long as links with the same name are in different
zones. However, at some point a zone will be halted or rebooted, at which
point its links are returned to the global zone (GZ). If overlapping link
names are used on a system, even if care is taken, at some point the GZ will
end up with two links that have the same name. Currently, this causes the
link management daemon - `dlmgmtd` - to abort and leave the system in a state
where links cannot be managed;
see [illumos issue 10001](https://www.illumos.org/issues/10001) for more
information.

A similar problem arises during link creation in that all links must first
be created in the GZ and then handed to a zone during boot. Careful management
is required to ensure that collisions do not occur.

### Link Persistence

Links can be created to be either persistent or temporary, temporary links
lasting only until they are deleted or the next system reboot. The persistent
link data store, `/etc/dladm/datalink.conf` stores links keyed solely on
the link name, and the last link to be created wins. This can result in
scenarios such as (with thanks to Peter Tribble for this example):

1. Create persistent VNIC vnic0 over net0
2. Boot zone using vnic0
3. Create persistent VNIC vnic0 over net1
4. Reboot system
5. Zone comes up using vnic0 over net1

## Proposal

The following link management system is proposed:

1. Links are separated into two namespaces, persistent and temporary;
1. A name can only be one of the namespaces at a time;
1. Both persistent and temporary link names are globally unique; even if a link
   is on loan to a zone, another link cannot be created with the same name;
1. A new class of link is created, a _Transient link_;
1. A transient link is a namespaced temporary link created directly within a
   zone;
1. Transient links cannot exist within the global zone;
1. As they are namespaced, transient names _can_ be duplicated providing that
   each link is in a separate zone;
1. Transient links are destroyed when their zone is halted; they are never
   moved into the GZ;
1. Transient links appear persistent from the zone's perspective<sup>1</sup>.

> <i>Note 1:</i> This allows zones to configure persistent IP properties
> against transient links.

In order to support this:

1. The `dladm create-*` subcommands are extended to support the creation of
   transient links in a zone via a new _zone_ link property, for example:
   ```
	dladm create-vnic -t -l <GZlink> -p mtu=9000,zone=test test0
   ```
   The zone must be in the _ready_ or _running_ state for this to succeed.
1. Other `dladm` link management subcommands are extended to support a
   _-z <zone>_ parameter, allowing operations to be performed directly on a
   link within a zone, for example:
   ```
	dladm rename-link -z test test0 net0
   ```
1. Other commands such as `flowadm` and `dlstat` are extended to support
   a _-z <zone>_ parameter, allowing the unambiguous selection of a link in
   the case that duplicate names are in use across zones;
1. The zone configuration schema is extended to support the following
   additional attributes in the `net` context <sup>2</sup>:
   * global-nic
   * mac-addr
   * vlan-id
1. The `dladm show-vnic` command is extended to show the zone in which a
   VNIC currently resides;
1. The `dladm show-vnic` command is extended to indicate the namespace in
   which a VNIC resides (or a FLAGS field?).

> <i>Note 2:</i> This allows links to be configured on demand as zones
> are booted.

### Available link management strategies

The scheme outlined above provides for at least the following strategies for
managing links in conjunction with zones.

#### Persistent Links

Administrators manage links manually, creating them persistently in the GZ
and allocating them to zones via `zonecfg`. All link names must be globally
unique.

> This is how links are generally managed in most illumos distributions today.

#### Links Created before a zone is in the _'ready'_ state

Zone brand scripts running in response to an early brand hook
dynamically create either persistent or transient links in the GZ so that
they are available when the zone boots. The information required to create
these links is taken from the zone configuration.

To avoid collisions, all link names must be globally unique.

> This is how links are optionally managed in OmniOS from r151030, and in
> Tribblix.

#### Transient Links created after a zone is in the _'ready'_ state

Zone brand scripts running in response to a late brand hook dynamically
create transient links directly into the zone. Since the links are
transient they will be destroyed automatically when the zone exits.

This strategy allows for the safe use of overlapping link names.

> This is how links are managed in SmartOS today.


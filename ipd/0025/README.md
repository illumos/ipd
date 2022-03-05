---
author: Andy Fiddaman
sponsor:
state: draft
---

# Authenticated pfexec

## Introduction

The illumos Role-Based Access Control (RBAC) system includes Rights Profiles
which can be assigned to a user or role. A user or role can access the
additional rights of profiles assigned to them by entering a profile shell
(which is a shell process which has the `PRIV_PFEXEC` privilege flag set) or by
using the `pfexec` command to set this flag for a single command. However,
there is currently no way of requiring additional authentication here, unlike
switching to a role or using a utility like `sudo`. A user working in a profile
shell may not realise that they are unecessarily executing commands with
additional privileges, and the lack of authentication prevents full RBAC
adoption in some environments.

## Proposal

The proposal is to introduce a new keyword to the
[user_attr(4)](https://illumos.org/man/user_attr) database, `auth_profiles`,
which lists profiles that require authentication before they can be used.

    auth_profiles
        Contains an ordered, comma-separated list of profile names chosen from
        prof_attr(4). The user must authenticate prior to using the rights
        afforded by these profiles. This attribute takes precedence over
        profiles assigned using the profiles keyword

        A list of auth_profiles can also be defined in the policy.conf(4) file.
        Profiles assigned here will be granted to all users.

## Mechanism

The proposed mechanism is to extend the current in-kernel `pfexec`
implementation. Today, when an exec() is encountered for a process which has
the `PRIV_PFEXEC` flag set, the kernel performs an upcall to the pfexec daemon
(`pfexecd`) which looks up the user and the command being executed in the
user\_attr database and returns specific attribute overrides if appropriate;
for example a different UID to use or additional privileges to add to the
inherit set.

For the authentication case, a new privilege flag will be introduced to record
whether a process has successfully completed authentication. This new flag
(`PRIV_PFEXEC_AUTH`) will be passed to `pfexecd` as part of the upcall. If the
flag is set, then `pfexecd` will look at both the authenticated and
unauthenticated profile set for the user, in that order, and return the
attribute overrides as necessary.

If, however, the flag is **not** set, then the authenticated set will be
inspected first and, if a match is found, a reply sent to the kernel
indicating that authentication is required. In this case, the kernel will
not execute the original command directly, but will instead invoke an
_interpreter_ - `pfexec --auth`. This process will authenticate the user
via pam(3pam). If authentication is successful, the `PRIV_PFEXEC_AUTH`
flag will be set and the authentication helper will re-exec the original
command.

       Userland                   |       Kernel
       --------                   |       ------

    +------------------------+    |
    | pfexec                 |                        +------------------+
    |                        |    |                   |                  |
    |  setpflag(PRIV_PFEXEC) |                        |                  |
    |                        |        +---------------v-------------+    |
    |  call exec()           +--------> exec()                      |    |
    +------------------------+        |                             |    |
                                      |                             |    |
    +------------------------+        | call pfexecd                |    |
    | pfexecd                <--------+ (include auth status)       |    |
    |                        |        |                             |    |
    |   getexecuser()        +--------> pfexecd returns auth        |    |
    +------------------------+        | required                    |    |
                                      |                             |    |
    +------------------------+        |                             |    |
    | pfexec --auth          <--------+ exec(pfexec --auth) as      |    |
    |                        |        | interpreter                 |    |
    |  authenticate (pam)    |        |                             |    |
    |  setpflag(PFEXEC_AUTH) |        |                             |    |
    |  exec(original cmd)    |        |                             |    |
    +-----------------+------+        +-----------------------------+    |
                      |                                                  |
                      |                                                  |
                      +--------------------------------------------------+

## exec\_attr - libsecdb`getexecuser()

The `getexecuser()` function in `libsecdb` has the following signature:

       execattr_t *getexecuser(const char *username, const char *type,
            const char *id, int search_flag);

The `search_flag` parameter will be extended to accept two new flags to control
which of the authenticated and unauthenticated profile sets is searched.

* `GET_PROF` - search only the **un**authenticated profile list.
* `GET_AUTHPROF` - search only the authenticated profile list.

If neither or both of these flags is specified, then both lists are searched.

> There is also a private `_enum_profs()` function used by a small number of
> components, which will need similar changes.

## auth\_attr - Authorisations

Checking a user's authorisations is primarily done through the `chkauthattr()`
function. With the introduction of authenticated rights profiles, this will
need extending so that it can determine whether the authenticated profiles
should be taken into account when checking whether a user has a particular
authorisation. The basis for considering the authenticated profiles will be
whether the uid of the calling process matches the uid of the requested user
and whether that process has the new `PRIV_PFEXEC_AUTH` process flag.

In many places the authorisation is checked from a server process which is not
running as the user being checked. To support this, rather than modifying the
existing `chkauthattr()` function, I propose to introduce a variant -
`chkauthattr_ucred()` - which takes an additional argument by which the
caller can provide a ucred which should be checked for the `PRIV_PFEXEC_AUTH`
flag.

Some authorisations are usable without a call to `pfexec`. For example, the
`Service Management` profile grants the following authorisations and has no
exec\_entries.:

```
% getent prof_attr Service\ Management
Service Management:::Manage services:auths=solaris.smf.manage,solaris.smf.modify
% getent exec_attr Service\ Management
%
```

For users/roles which are granted a profile like this via `auth_profiles`,
a mechanism is needed whereby they can be prompted for authentication. To
support this, new helper profiles will be introduced that cover the
necessary commands, but have no attributes defined in the exec\_attr entry.
This will cause `pfexecd` to request authentication but fall back to the
standard execution path once authenticated (or directly if granted via just
`profiles`).

A helper profile for `Service Management` could look like:

```
% getent prof_attr Service\ Management\ (auth)
Service Authentication:::Authenticated profile helper:
% getent exec_attr Service\ Management\ (auth)
Service Management (auth):solaris:cmd:::/usr/sbin/svcadm:
Service Management (auth):solaris:cmd:::/usr/sbin/svccfg:
```

## getent(1)

`getent` does not require any updates. It does not parse the content of
user\_attr entries.

## userattr(1)

`userattr` does not require any updates since it works with generic key/value
pairs.
> There is no man page for this utility; one should be written.

## profiles(1)

The `profiles` command will be extended to be able to show only entries
from either the unauthenticated or authenticated profile set, and to show
additional information if requested. It is currently proposed that the default
output will be unchanged and show both unauthenticated and authenticated
profiles.

```
% userattr profiles bob
Zone Management
% userattr auth_profiles bob
Software Installation,Service Management
```

Looking at both authenticated and unauthenticated profiles, with no
annotation, would produce this output (`Software Installation` brings
`ZFS File System Management` along for the ride). This also includes the
profiles granted to all users via policy.conf.

```
% profiles
Software Installation
ZFS File System Management
Zone Management
Service Management
Basic Solaris User
All
```

Possible options for restricting the output could look like this:

```
% profiles -X			# show only 'profiles'
Zone Management
Basic Solaris User
All
```
and
```
% profiles -x			# show only 'auth_profiles'
Software Installation
ZFS File System Management
Service Management
```

with a new `-v` option to add more detail, such as the authentication
requirement:

```
% profiles -v
Software Installation (Authentication required)
ZFS File System Management (Authentication required)
Zone Management (Authentication required)
Service Management
Basic Solaris User
All
```

A further useful enhancement to `profiles` would be the addition of a
`-c` option to look up profiles based on a specific command.

```
% profiles -c /usr/bin/pkg -lv bob
bob:
      Software Installation (Authentication required)
          /usr/bin/pkg               uid=0
      All
          *
```

## useradd(1)

`useradd`'s `-D` option will be extended to provide the option to specify
a list of default `auth_profiles` to be added to newly created users, as an
analogue of the existing `profiles` option.

Although the `-K` option can be used to specify this key, as in:

```
% pfexec useradd -D -K auth_profiles="Software Installation"
group=other,1  project=default,3  basedir=/home
skel=/etc/skel  shell=/bin/sh  inactive=0
expire=  auths=  profiles=  auth_profiles=Software Installation
roles=  limitpriv=  defaultpriv=  lock_after_retries=
```

A convenience option will be added to complement the existing `-A`, `-P` and
`-R` flags. For want of anything better, I currently propose to use `-X`.

```
% pfexec useradd -D -X "Software Installation"
```

## usermod(1)

As with `useradd`, the `-K` option can be used to modify the `auth_profiles`
for a user. The `-X` convenience option will be added here too complement
`-A`, `-P` and `-R`.

## passmgmt(1)

As above, a new `-X` option will be added here too.

## ppriv(1)

ppriv already has an undocumented command line option to set the `PRIV_PFEXEC`
flag in a process, `-P`. A new option to set the new `PRIV_PFEXEC_AUTH` flag
will be added. It may be time to rework this to take a more generic `-f`
option for controlling privilege flags - e.g. `-f +D` to enable privilege
debugging.

## setpflags(2)

The `setpflags` system call will be updated to handle changing the new
`PRIV_PFEXEC_AUTH` flag. Setting this flag will require the `PRIV_PROC_SETID`
privilege.

## proc(4) control PCSPRIV

As per `setpflags`, setting the `PRIV_PFEXEC_AUTH` flag via this interface
will also require the `PRIV_PROC_SETID` privilege.

## Auditing

`execve(2) with pfexec` is already audited by the kernel. A new `pfauth`
audit event will be added to record the success or failure of the
authentication phase.

## Caching

It may be convenient to cache a successful authentication for a short time
to avoid repeated prompts for authentication. This could be done via a pam
module or in `pfexecd` itself.

## Demo

```
bob@bloody:~% pfexec pkg refresh
Authentication required for 'Software Installation' profile
Password:
Refreshing catalog 2/2 openindiana.org

bob@bloody:~% profiles -vXlc /usr/bin/id bob
bob:
      xtest (Authentication required)
          /usr/bin/id                uid=0

bob@bloody:~% /usr/bin/id
uid=101(bob) gid=1(other)

bob@bloody:~% pfexec /usr/bin/id
Authentication required for 'Auth pfexec test' profile
Password:
uid=0(root) gid=1(other)

bob@bloody:~% pfexec pkg refresh
Authentication required for 'Software Installation' profile
Password:
Authentication failed
```


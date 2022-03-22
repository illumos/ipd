---
author: Andy Fiddaman
sponsor:
state: draft
---

# Authenticated pfexec

## Introduction

RBAC (role-based access control) is an alternative to the traditional
all-or-nothing superuser security model. With RBAC, privileged functions
can be assigned to specific user accounts, or to special accounts called
roles. Roles are an optional part of RBAC (despite the name!) but when they
are used, roles are assigned to users and those users can assume the role
in order to access the additional privileges assigned to it. This is typically
done via the
[su(8)](https://illumos.org/man/8/su) command, and the user will be required
to authenticate with either the role password or their own password, depending
on the role's `roleauth` attribute in the
[user\_attr(5)](https://illumos.org/man/5/user_attr) database.

Users (and roles) can be assigned `Authorisations` which are unique strings
that represent a right to perform some operation or class of operation. For
example, a user who is afforded the `solaris.smf.manage` authorisation is
able to manage SMF services. These authorisations are typically checked
programmatically by applications, using
[chkauthattr(3SECDB)](https://illumos.org/man/3SECDB/chkauthattr).

Users (and roles) can also be assigned `Profiles`. A Profile is a named
collection of authorisations and commands with attributes specifying
additional privileges with which the command should be run, or an alternative
user or group ID. These commands and their additional privileges are defined
in the [exec\_attr(5)](https://illumos.org/man/5/exec_attr) database.

Users/roles gain access to the functions afforded by their assigned profiles
using the [pfexec(1)](https://illumos.org/man/1/pfexec) command. pfexec has no
special privileges (it is not, for example, a setuid binary), it just sets the
`PRIV_PFEXEC` privilege flag on itself (which any process can do) and then
calls [exec(2)](https://illumos.org/man/2/exec) to run the target command. The
kernel sees the flag and asks `pfexecd` for any additional privileges that
should be afforded. There are also _profile shells_ which are shell variants
which have the `PRIV_PFEXEC` flag set on them, so that every command they
invoke inherits the flag and will elevate privileges automatically. It is
fairly typical for a role account to use one of these as its shell so that,
after assuming a role, an administrator does not need to prefix every command
with `pfexec`.

One thing that is missing in the current implementation, is the ability to
assign profiles to users (or roles) and require an additional authentication
step before elevating privileges, something which is a commonly used feature
of utilities like sudo(8), and the lack of which prevents full RBAC adoption
in some environments.

## Proposal

Introduce the additional concept of `Authenticated Profiles` which can be
assigned to a user or a role. This is a list of profiles, which can only
be used following additional authentication.

A new `auth_profiles` keyword will be added to the
[user\_attr(5)](https://illumos.org/man/user_attr) database.

    auth_profiles
        Contains an ordered, comma-separated list of profile names chosen from
        prof_attr(5). The user must authenticate prior to using the rights
        afforded by these profiles. This attribute takes precedence over
        profiles assigned using the profiles keyword

        A list of auth_profiles can also be defined in the policy.conf(5) file.
        Profiles assigned here will be granted to all users.

## Mechanism

The proposed mechanism is to extend the current in-kernel `pfexec`
implementation. Today, when an exec() is encountered for a process which has
the `PRIV_PFEXEC` flag set, the kernel performs an upcall to the pfexec daemon
(`pfexecd`) which looks up the user and the command being executed in the
[user\_attr(5)](https://illumos.org/man/user_attr) database and returns specific
attribute overrides if appropriate; for example a different UID to use or
additional privileges to add to the inherit set.

For the authentication case, a new privilege flag will be introduced to record
whether a process has successfully completed authentication. This new flag
(`PRIV_PFEXEC_AUTH`) will be passed to `pfexecd` as part of the upcall. If the
flag is set, then `pfexecd` will look at both the authenticated and
unauthenticated profile sets for the user, in that order, and return the
attribute overrides as necessary.

If, however, the flag is **not** set, then the authenticated set will be
inspected first and, if a match is found, a reply sent to the kernel
indicating that authentication is required. In this case, the kernel will
not execute the original command directly, but will instead invoke an
_interpreter_ - `pfauth`. This process will authenticate the user
via [pam(3PAM)](https://illumos.org/man/3PAM/pam). If authentication is
successful, the `PRIV_PFEXEC_AUTH` flag will be set and the authentication
helper will re-exec the original command.


       Userspace                  |       Kernel
       ---------                  |       ------

    +------------------------+    |
    | pfexec                 |                        +---------<--------+
    |                        |    |                   |                  |
    |  setpflag(PRIV_PFEXEC) |                        |                  |
    |                        |        +---------------v-------------+    |
    |  call exec()           +--------> exec()                      |    |
    +------------------------+        |   |                         |    ^
                                      |   |                         |    |
    +------------------------+        | call pfexecd                |    |
    | pfexecd                <--------+ (include auth status)       |    |
    |                        |        |                             |    |
    |   getexecuser()        +--------> pfexecd returns auth        |    |
    +------------------------+        | required(1)                 |   (2)
                                      |   |                         |    |
    +------------------------+        |   |                         |    |
    | pfauth                 <--------+ exec(pfauth) as             |    |
    |                        |        | interpreter                 |    |
    |  authenticate (pam)    |        |                             |    |
    |  setpflag(PFEXEC_AUTH) |        |                             |    |
    |  exec(original cmd)    |        |                             |    |
    +-----------------+------+        +-----------------------------+    ^
                      |                                                  |
                      |                                                  |
                      +----------->------------>------------>------------+

1. pfexecd will also specify any additional privileges that should be
   given to the `pfauth` helper in order that it can properly use PAM and
   set the `PRIV_PFEXEC_AUTH` flag following successful authentication.
   Since this is an increase in privileges, pfexecd will also tell the
   kernel to scrub the process environment, as already happens when pfexec
   changes owner or group.

2. On this second pass through, pfexecd will see the authentication status
   and include authenticated profiles when checking for additional
   authorisations and exec attributes to assign.

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
existing `chkauthattr()` function signature, I propose to introduce a variant -
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

A helper profile for `Service Management` would look like:

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

## proc(5) control PCSPRIV

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


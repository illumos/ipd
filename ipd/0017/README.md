---
authors: Robert Mustacchi <rm@fingolfin.org>
state: draft
---

# IPD 17 SMF Runtime Directory Creation Support

When writing a daemon, a common problem is that one needs to create a
directory for that daemon, such as `/var/run/<daemon-specific dir>` as
part of the daemon starting up. However, often the permissions on
`/var/run` or on other directories are such that a daemon needs to do
that with root privileges. This makes the ability to specify a user,
group, and privileges in an SMF manifest file, less valuable.

Other software in this space, like systemd, has added functionality so
that a service can have a number of [directories to be created
automatically](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=).
This has proven useful and folks have asked for similar functionality in
illumos.

This IPD proposes extending SMF to support such a mechanism and make
this a first class feature that's supported and usable when writing
SMF manifests on illumos.

## Goals

This facility should provide the following:

1. The ability to freely specify the path that should be created.
2. The ability to override the default user, group, and directory
permissions.
3. A way for a program to refer to this, such as through the
environment.
4. The ability to try and make sure that directory is empty on start.

It's worth taking these goals apart a little bit and contrasting them
with other implementations. While the systemd implementation constrains
the general location and provides semantics for specific classes of
directories, in our case, we'd rather allow this to be flexible. People
running illumos often have software that comes from many different
prefixes in the system, whether that be `/usr`, `/opt`, or something
that they use for themselves. As a result, it seems like allowing
flexibility here, which mimics existing use, is important.

With the second goal, because not all services start up with the user
and group specified in their start method, but instead will change their
user and group ids, allowing the directories to match that of the end
state of the process is useful. As this can be used to create arbitrary
directories, there may be cases where one needs to create a specific
directory that's owned by root or to make sure a sticky bit is present.

The third option is useful for software where such options are
overridable in the environment. This allows for less logic to have to be
placed into a start method which wraps this.

Finally, the fourth goal is for software which often has PID files or is
expecting the directory that it receives to be empty. Please see the
Design Considerations section further on for more on this and the trade
offs.

## SMF Details

Concretely, I propose we add a new section to a service manifest that
can be specified at both a service and an instance level. This entry
will be called `managed_paths` and will allow one to specify one or more
`directory` entries. While we only have specified directories at the
moment, in the future one could also manage files or other contents in
this way. Each `directory` entry will have the following fields:

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| path | yes | N/A | The directory path to create (subject to SMF method token expansion) |
| user | no | `method_credential.user` | user to own the directory |
| group | no | `method_credential.group` | group to own the directory |
| mode | no | 0770 | Permissions for the directory |
| env | no | "" | Environment variable to export `path` in |
| empty | no | false | Ensure the target directory is empty on start up |

Semantically, this operation will only occur when a service transitions
to being **online**. Generally, that means before a `start` method is
invoked by `svc.startd`. However, if we had support for other types of
services and restarters such as a periodic one (like exists in Solaris
for cron-like activity), then that restarter would also theoretically be
able to honor this and make sure that they existed.

Here's an example of what it might look like:

```
<managed_paths>
	<directory path="/var/run/foobar" empty=true />
	<directory path="/var/db/mydb-%i" env="DB_PATH" />
        <directory path="/var/tmp/unreadable" mode=0000 user="noaccess" group="noaccess" />
</managed_paths>
```

When the default instance of this service is started, it would make sure that
three directories are created: `/var/run/foobar`, `/var/db/mydb-default`, and
`/var/tmp/unreadable`. It would clear out the contents of
`/var/run/foobar`. Finally, `/var/tmp/unreadable` would be created with
the user and group `noaccess` and it would have its permissions set such
that nobody could access it.

When this process occurs, the system will take the following steps for
each entry in `managed_paths`:

1. It will make sure that the directory `path` is created and any
directories leading up to it. `path` is subject to the standard SMF
token expansion (`%r`, `%s`, `%i`, `%f`, properties, and escaping). This
allows for folks to embed the instance and service name into it, or a
property, much like is done for the start method.

2. For any intermediate directory that does not exist, the system will
create it such that it is owned by the user `root`, the group `root`,
and have the permissions `0755`. If a directory already exists, the
system will not change the permissions or ownership on it. For example,
if `/var/run/foobar` were the directory, then it would not change
anything on `/var` or `/var/run`.

3. It will make sure that the user and group on the directory is set to
the one specified. If the optional `user` and `group` properties are
missing, then it will use the one from the `method_credential` that
applies to the start method. Similarly, it will set the permissions on
the directory to `mode`. An important consideration here is what happens
if this directory already exists. In that case, the system will still
change the permissions and ownership.  See the Design Considerations
section for more on this choice of behavior.

4. If `env` value set to a non-empty string, then the resulting path
that was created will end up set in the environment variable specified.
The empty string `""` is a synonym for not adding this to the
environment. When the environment variable already exists, then the
system will create a new value by appending the generated value,
separated by a `:`. This allows directories to be added to the PATH, or
allow multiple directories to be added to the same service-specific
name.

5. If the `empty` value is set to true, then after creating the
directory, we will attempt to recursively remove all contents inside of
it, if the directory already existed. This exists for services that may
use a PID file or similar construct. This is a best effort, meaning that
anything that was present before the emptying process began will be
removed, but if something is added by some other entity while cleaning,
then it is not guaranteed to be removed. During this process, symlinks
will explicitly not be followed. Please see the Design Considerations
section for more discussion on the rationale for this.

### Ordering

The set of entries in `managed_paths` is inherently ordered based on the
order of the entries in the service manifest. The `managed_paths`
section can contain multiple entries, these are processed in order. This
allows dependent directories to be created with the expected
permissions. For example, this allows someone to specify first
`/var/run/myservice` and then follow it with `/var/run/myservice/data`.

If there is more than one `managed_paths` section in a service, then
they will be concatenated together. All **service** level
`managed_paths` will be processed before **instance** level
`managed_paths`.

When entries are added to the environment, the starting environment will
be that as described by the `environment` section of the Method Context
(see [`smf_method(5)`](https://illumos.org/man/5/smf_method). This means
that when checking if an environment variable exists for appending, then
anything described there such as `PATH` will already exist.

## Design Considerations

This section of the IPD goes through some of the rationale behind why we
chose some of the design decisions that we made, contrasts them with the
choices made by systemd, and discusses various trade offs and open
questions in the design.

### Full Paths vs. Logical Directories

One of the first considerations that we had was the use of full paths
and a more generic facility versus logical service-level needs. For
example, systemd has specific options that cover creating a
configuration directory, a run-time directory, logs, etc. As a result,
it hardcodes the prefix of resulting locations for those options.

A degree of uniformity in the system is important for users and
administrators. When all configuration, logs, etc. are in the same
location this makes the system more approachable and usable. However,
the question is should the service framework enforce this or not.

If we survey many illumos distributions, they do not use a single prefix
for delivering software. Different bundles of software, deliver into a
different prefix and have different preferences for how this is
configured. For example:

* `pkgsrc` delivers software into `/opt/local` including binaries and
configuration, but uses `/var` for run-time information such as the
`pkgin` database, and services.

* The `ooce` package set takes a different approach. While most data is
installed under `/opt/ooce`, configuration lives in `/etc/opt/ooce`, and
various software in `/var` is found with the `/opt/ooce` directory
appended to collect it all.

* The core OpenIndiana, OmniOS, and SFE repositories look more
use `/usr`, `/var`, and `/etc` in a similar way. Each owning parts of
that corresponding name space.

Based on all these differences, it seems that there is value in allowing
illumos distributions to continue to deliver service manifests in a way
that is specific to their environment and their druthers. While illumos
does have recommended locations for all of the different pieces (e.g.
[`filesystem(5)`](https://illumos.org/man/5/filesystem), there are
multiple ways to integrate packages and there's value in retaining this
flexibility. If we picked something, at least some of the above would
have to change and be frustrated by that. In general, I believe that SMF
should allow one to implement their desired policy, but not force it.

From a different perspective, another reason to have flexibility is that
there are a number of services that run to actually mount `/var` and
other directories. If we were to hardcode paths, we would probably have
to create something separate for services that run before early manifest
import.

### Behavior on Built-In Methods

Today, there are two special methods that are documented in SMF. These
are `:kill` and `:true`. These respectively send a contract a specified
signal and always succeed.

In general, it is assumed that `:kill` is never used for the start
method and is only used as part of a stop method. While this is assumed
to generally only be used for the stop method due to the requirement of
having a contract and it not making sense for a start method, that isn't
a strict requirement.

The `:true` method is used in a large number of services; however, most
often for a `stop` or `refresh` method. There are a handful of milestones
and other services that use `:true` for a start method.

Today, both of these are handled in special ways in the startd code. For
example, when they occur we do not gather the method context at all
because we do not fork and exec a method. It seems like we should always
support creating the directories. There could be several transient-style
services where creating directories of the correct permissions is
useful.

The only reason not to do this is risk of gathering the associated
method context when we didn't before. However, it seems like it is
worthwhile to do so so we can have a uniform experience in the system.

### Environment Variables

In our current design, we always source the SMF method context
environment variables before appending any created directories to the
corresponding environment variables. There are a few design questions
worth considering:

1. Should multiple path entries be allowed to edit the same environment
variable?
2. Should these append or clobber the environment?
3. Should these occur before the method context sets the environment or
should the method context replace any entries that already exist?

If we look at systemd, it does allow multiple entries to be created,
however it only allows for specific environment variables that it
controls to be used based on the type of path it has created. Here we
considered a few different things:

* It is useful to be able to have multiple paths join together similar
to what systemd has done.

* Various services have their own environment variables that they handle
which can be directories and take them from the environment. For
example, postgres supports the
[`PGDATA`](https://www.postgresql.org/docs/12/app-postgres.html)
environment variable which tells it where the data directory for the
database is. Being able to create that directory for a specific
instance, using the token expansion, and then setting the appropriate
environment variable further reduces the complexity start method.

* Because we want to allow for the appending of variables, it seems like
it makes more semantic sense to start from the existing method. This
would allow certain things like the `PATH` or other directory based
environment variables to be updated based on per-instance values.

These different ideas have led me to suggest that we should honor the
existing Method Context environment settings and that if we want the two
to co-exist this is the only way that makes semantic sense.  Because the
Method Context is always defined to set the environment to a known
state, it makes sense to think of that as starting and creating the base
environment and amending it to this point.

### Existing Directories: Ownership and Permissions

Currently, the system treats intermediate directories and the final
specified directory of a path in different ways when it comes to
permissions and ownership. Mainly that we don't change existing
intermediate directories and that we always change existing final
directories.

The first thing we should think about is should we actually update the
permissions and ownership of the final directory in a path. This invites
a clash between a service and an administrator and multiple conflicting
services. The first of these is a case where an administrator has set
the permissions to the opposite of what the service intends to. This
could happen intentionally or unintentionally. In the intentional case, if
we do this, then we will clobber their intent; however, part of the goal
of using the `managed_paths` functionality is to move regular
maintenance of this into the service itself.

Another reason to support changing the permissions and ownership of an
existing service is service upgrade. A service may have been introduced
that incorrectly ran as `root` or as `nobody` that was then switched to
running as a dedicated service user. It would be useful if an update to
the manifest file then took care of this. Otherwise it's likely that an
updated manifest would send a service into maintenance. For example if
`/var/run/myservice` was owned by root, but the service changed to run
as the user `myservice`, then the system would not function correctly.

Another consideration is what this means for service with overlapping
directory structures. For example, if service 1 wants to use the path
`/var/run/net` and another service wants to use `/var/run/net/foobar`.
While this kind of configuration isn't recommended, it is certainly
possible today and many start methods that are trying to create
corresponding directories are running as root already!

In the second service started and created its directory path, then we'd
initially have `/var/run/net` owned by the user and group `root` with
the permissions `0755`. However, when the first service started up, it'd
change that to the service's user and group and probably `0770`, this
cutting off access to the second service. This isn't great, but it's not
clear that because of this we should take active steps to prevent it
from happening as one could also create something where this makes sense.

One place where this gets messy though is the question of ownership of
the files and directories that exist in the directory. systemd says that
it will always recursively change the ownership of contents under the
directory to match the parent. Though it notes that it has an
optimization where in if everything in the target directory matches then
it will not do anything else. We should consider a similar feature. The
main argument for this, in my opinion, is the service upgrade feature
set. When we upgrade a service and change the user, it would be useful
if it then had full control over all the files and subdirectories that
it owned. While such a feature would further complicate the overlapping
service problem, it does seem like something worthwhile.

### Cleaning Directories

The current option to clean directories out is a variant of a feature
that systemd has. When a directory represents a runtime directory
(something located under `/run`) then when the service unit stops or a
user issues a command, then all of the directory contents will be
cleaned up from that last directory component. For example, if you
created `/run/foo/bar`, everything under `/run/foo/bar` would be cleaned
up, but `/run/foo` would not be touched.

While considering this, there were a few different things that we
thought about. There are a few observations that we were thinking about:

1. A common use case for this is daemons which have PID files.

2. These are often created on `tmpfs` backed files, but aren't always.

3. We need to worry about not just a crash of the system, but also if
`svc.startd` crashes, how do we know to make sure everything is in a
good state for the service.

4. Sometimes when a new BE is created, there will be runfiles or lock
files caught from the old environment and copied into the new one,
leaving behind things to clean up.

As a result, we thought about allowing services to opt into something
being cleaned up when the service starts. This does a few useful things:

1. It makes it so that all of the logic around the directories only
happens in the `start` method, simplifying the mental model around how
the feature works. This means that we have less state tracking code and
clean up.

2. Even if `svc.startd` or `svc.configd` crashes while we're in the
middle of an operation, because this is only happening on start up, we
don't need to worry about tracking the state of what should have been
cleaned up.

3. If the system crashed and the directory wasn't backed by a `tmpfs` or
other memory-based file system, it will still be cleaned up.

One of the big complexities around this is the rather obvious thing
we're creating to screw ourselves up. If two services overlap and both
specify cleaning behavior (regardless of on start or stop), then they
will end up removing each others files. We considered doing a few things
here like state tracking and only cleaning up when the last service that
specified a directory was done, but this felt like a major complication
and one of dubious value.

A fundamental reality is that any service that an administrator imports
basically has the power to remove arbitrary files in the file system in
its start method. While, this method certainly makes it easier, it also
makes it more visible. While it's true that we are punting this problem
onto the folks packaging software, I'm not sure that's any less true
than it already was.

One thing that we should consider is what amount of safe guards should
we add in here? Should we make sure that we're not descending into
`/dev`, `/devices/`, `/system`, or `/proc`?

### Other Security Considerations

When walking a directory tree, there is an inherent [TOCTTOU
vulnerability](https://en.wikipedia.org/wiki/Time-of-check_to_time-of-use).
For example, if someone maliciously replaces a directory with a symbolic
link or similar, that can be a trickier thing to handle.  One solution
is to basically do all the manipulation of the permissions and ownership
using operations on file descriptors (e.g. fchown(2), fchmod(2), etc.)
and always using openat(2) to always move forward one directory at a
time.

However, if something else has elevated permissions, being root on the
intermediate path, or an administrator has set a service to run on a
user-controlled path, then it's not clear if there's a lot that we can
do to prevent something malicious from happening. Even if we take care
of creating our directories, there's nothing that stops something else
from manipulating those.

We need to think carefully about whether or not we should honor symbolic
links found as we incrementally process these directories. While we
should never follow symbol links on clean up, it's an interesting
question on what we should do along the way.

## Open Questions

This section contains open questions that we want to answer:

1. We should likely add support for recursively chowning the contents of
a directory as discussed in the `Existing Directories: Ownership and
Permissions` section.  Should this be something that a service can opt
out of like the emptying of the directory? If we do this, should the
same optimization be done like systemd? If so, should we allow that to
be controlled?

2. What precautions should we take when cleaning up directories
specified by a user? Should we try to look at the directories and refuse
to create or operate on certain prefixes (e.g. `/dev`, `/proc`, etc.)?
Some of that we won't be able to do until after token expansion of the
path has been completed.

3. How should we handle symbolic links that we encounter while tying to
expand the directory path.

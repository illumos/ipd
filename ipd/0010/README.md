---
authors: John Levon <john.levon@joyent.com>
state: draft
---

# IPD 10 full argv in ps

Currently, `ps -ef` limits the displayed argv string to 80 characters maximum.
This is because it gets this value from `/proc/pid/psinfo`'s `pr_psargs[]`.

This value is populated at `exec()` time, and does not reflect any changes the
process may make to its argv subsequently. This is both a bug and a feature.

The only way to get a longer argv is via `pargs` or `ps auxww`, both of which
require permissions to read the target process. This longer value reflects the
current process arguments, which may have changed.

This IPD is proposing a few changes:

## /proc/pid/cmdline

We'll introduce a new `proc(4)` file, `/proc/pid/cmdline`. This has been in SmartOS
for a long time under the `lx` brand. It's a `\0`-separated string of the
current `argv` of the process, equivalent to that reported after the first line
of `pargs`:

```
# pargs 7228
7228:	/usr/lib/smtp/sendmail/sendmail -Ac -q15m
argv[0]: sendmail: Queue runner@00:15:00 for /var/spool/clientmqueue
argv[1]: <NULL>
argv[2]: /var/spool/clientmqueue
# cat /proc/7228/argv
sendmail: Queue runner@00:15:00 for /var/spool/clientmqueue
     ...  #
```

Permissions on this file are `0444`. Note that the usual security boundaries around `/proc`,
such as zones, missing `proc_info` privilege, etc. are sufficient to hide this
file in the same way as other `/proc/` files on a per-process basis.

This new file is explicitly Linux-compatible, on the basis that it is what
most software these days is likely to be expecting. In particular:
2
 - instead of looking at the `argv[]` array itself, it records the original
   argv string area, and exposes *that*. For example, we wouldn't see `argv[1]`
   and `argv[2]` as seen in pargs above in `/proc/pid/cmdline`. The process
   did not intend to expose those.
   
 - there is a `setproctitle()` hack: essentially, if the last byte in the argv
   string area is no longer `'\0'`, then we assume that the application has
   modified its argv (under `lx` brand, this would be via `setproctitle()`).
   In that case, we will happily read and display the string beyond the confines
   of the original argv area (up to a page in size).

## `ps -ef`

While total consensus is not going to happen here, probably the majority view was
that it was preferable to expand the output of `ps -ef` and `ps auxww` by default
as part of these changes, thus using the current process argv as discussed above:

```
# ps -ef
    root 347644  22491   0   Aug 06 ?           0:00 /home/gk/src/smartos-jlevon/projects/illumos/usr/src/cmd/svc/configd/svc.configd-native -p -d /var/run/scfdrAAAaSG.nv -r /tmp/build_live-1001.306619/a/usr/lib/brand/joyent-minimal/repository.db
...
 0000907  98875  96779   0   Aug 09 ?          17:45 postgres: moray moray 172.27.15.15(56902) idle                 
...
# ps -o pid,args -p 119010
   PID COMMAND
119010 /opt/marlin/build/node/bin/node --abort-on-uncaught-exception /opt/marlin/lib/a
# ps -f -o pid,args -p 119010
   PID COMMAND
119010 /opt/marlin/build/node/bin/node --abort-on-uncaught-exception /opt/marlin/lib/agent/lackey.js /var/run/.marlin.1422402e-cc98-44d9-9adb-f963cfcdfe15.sock
# ps -f -o pid,args,pid -p 119010
   PID COMMAND                                                                             PID
119010 /opt/marlin/build/node/bin/node --abort-on-uncaught-exception /opt/marlin/lib/ag 119010
# ps -o pid,args -p 98875
   PID COMMAND
 98875 /opt/postgresql/9.2.4/bin/postgres -D /manatee/pg/data
# ps -f -o pid,args -p 98875
   PID COMMAND
 98875 postgres: moray moray 172.27.15.15(56902) idle                 
```

There was concern over scripts incorrectly doing `ps -ef | grep ...` changing behaviour
due to additional arguments being visible, or a replaced argv no longer matching. The
same could potentially apply to `pgrep(1)` and especially `pkill(1)`.

While this is definitely a concern, ultimately most people felt this improvement is
worth the risk here. However, I'm proposing introducing a safety valve:

```
# ps -ef | grep lackey
    root 164522 162737   0   Aug 10 ?           0:02 /opt/marlin/build/node/bin/node --abort-on-uncaught-exception /opt/marlin/lib/agent/lackey.js /var/run/.marlin.34e2146e-ce75-455a-9c36-ccf37446f553.sock
    ...
# SHORT_PSARGS=1 ps -ef | grep lackey
#
# SHORT_PSARGS=1 pgrep lackey
#
```

Feel free to bikeshed this name. Like POSIXLY_CORRECT, the value is ignored, as long
as it's set.

## `ps(1b)`

The existing behaviour of `ps(1b)` is a little obscure. Without permissions,
`pr_psargs[]` is used. Presuming `ps(1b)` can read the target process, however,
then:

 - if the terminal width is < 132, the `w` options behave as described in the
   man page: a single `w` provides 132 characters of argv (wrapping past the
   terminal edge), and two or more show the whole argv.

 - otherwise, without any `w`, whatever fits in the terminal is shown (this is
   similar to how Linux `ps(1)` works).

 - with one or more `w`, the entire argv is shown.

This behaviour appears to simply be a bug in the way the arguments are handled.
We'll fix this as part of these changes.

With two or more `w` flags, `ps(1b)` will now report the whole argv, regardless
of whether we can read the target process or not.

## `pgrep(1)`

`pgrep(1)` and its nom de guerre `pkill(1)` currently only match against
`pr_psargs[]`. We'll also change those so more than one `-f` argument will use
`/proc/pid/cmdline`.

## Security issues

The effect of these changes is that characters 80 onwards of a process's argv
are globally visible (modulo the existing security boundaries as mentioned).
There was some concern over programs taking secrets on the command line that may
now be exposed.

However, such programs were always totally broken: they are exposed on other
operating systems, and nobody knows of one that's careful enough to respect and
refuse to accept secrets in the existing public 80-character space.

## Future enhancements

In the future, we may record the whole argv at `exec()` time in the kernel. We
could then add options to report that instead of the current argv. (This would
probably be most useful in `pargs(1)` though.)

`pargs(1)` currently works by inspecting the target process address space. It could
be changed to use `/proc/pid/cmdline` instead. However, it's full of scary code
about translating between locales, so nobody really wants to go there. One for
the intrepid?

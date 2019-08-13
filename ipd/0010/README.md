---
authors: John Levon <john.levon@joyent.com>
state: draft
---

# IPD 10 full argv in ps

Currently, `ps -ef` limits the displayed argv string to 80 characters maximum.
This is because it gets this value from `/proc/pid/psinfo`'s `pr_psargs[]`.

The only way to get a longer argv is via `pargs` or `ps auxww`, both of which
require extra permissions than a normal user has.

This value is populated at `exec()` time, and does not reflect any changes the
process may make to its argv subsequently. This is both a bug and a feature.

This IPD is proposing a few changes:

## /proc/pid/argv

We'll introduce a new `proc(4)` file, `/proc/pid/argv`. This has been in SmartOS
for a long time, supporting the `lx` brand. It's a `\0`-separated string of the
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

Permissions on this file are `0444`.

## `ps -eff`

After some discussion, there was concern that modifying the existing output of
`ps -ef` was at risk of breaking scripts that unfortunately choose to parse the
output of `ps(1)`. Therefore, unlike say Linux `ps(1)`, we will still report the
initial `pr_psargs[]` even when given the `-f` flag. Instead, we take a leaf out
of `ps(1b)`'s book, and accept more than one flag. In this case, we will report
the whole argv in its modified form. The man pages will make clear the
difference between the two cases.

```
# ps -ef
    root 347644  22491   0   Aug 06 ?           0:00 /home/gk/src/smartos-jlevon/projects/illumos/usr/src/cmd/svc/configd/svc.config
# ps -eff
    root 347644  22491   0   Aug 06 ?           0:00 /home/gk/src/smartos-jlevon/projects/illumos/usr/src/cmd/svc/configd/svc.configd-native -p -d /var/run/scfdrAAAaSG.nv -r /tmp/build_live-1001.306619/a/usr/lib/brand/joyent-minimal/repository.db
# ps -ef -o pid,args
347644 /home/gk/src/smartos-jlevon/projects/illumos/usr/src/cmd/svc/configd/svc.config
# ps -eff -o pid,args
347644 /home/gk/src/smartos-jlevon/projects/illumos/usr/src/cmd/svc/configd/svc.configd-native -p -d /var/run/scfdrAAAaSG.nv -r /tmp/build_live-1001.306619/a/usr/lib/brand/joyent-minimal/repository.db
# ps -eff -o pid,args,pid
347644 /home/gk/src/smartos-jlevon/projects/illumos/usr/src/cmd/svc/configd/svc.configd 347644
```

## `ps(1b)`

The existing behaviour of `ps(1b)` is a little obscure. Without permissions,
`pr_pargs[]` is used. Presuming `ps(1b)` can read the target process, however,
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
`/proc/pid/argv`.

## Future enhancements

In the future, we may record the whole argv at `exec()` time in the kernel. It
would then be feasible to report that, even without an additional `-f` flag.


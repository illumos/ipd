---
authors: Joshua M. Clulow <josh@sysmgr.org>
state: predraft
---

# IPD 4 Manual Page Section Renumbering

According to the [Wikipedia article on manual pages][wp-man], most operating
systems with manual pages use the following section numbering scheme:

| Section | Description |
| ------- | ----------- |
| 1       | General commands |
| 2       | System calls |
| 3       | Library functions, covering in particular the C standard library |
| 4       | Special files (usually devices, those found in /dev) and drivers |
| 5       | File formats and conventions |
| 6       | Games and screensavers |
| 7       | Miscellanea |
| 8       | System administration commands and daemons |
| 9       | Kernel routines |

See the _Other Operating Systems_ section below for a more comprehensive survey
of modern operating systems.

The article also notes that _System V_-derived platforms have historically used
a different scheme.  This scheme is, for historical reasons, the one presently
used by illumos today:

| Section | Description |
| ------- | ----------- |
| 1       | General commands |
| 1M      | System administration commands and daemons |
| 2       | System calls |
| 3       | C library functions |
| 4       | File formats and conventions |
| 5       | Miscellanea |
| 6       | Games and screensavers |
| 7       | Special files (usually devices, those found in /dev) and drivers |
| 9       | Kernel routines |

This scheme presents a number of challenges when dealing with software
primarily developed for other platforms.  Using the section numbers they expect
results in pages ending up in the wrong section when installed on an illumos
system -- of particular note is section 5 for file formats, like
_rsyncd.conf(5)_; and section 8, like _zpool(8)_.

Even if it were a reasonable proposition for every software package in the
world to parameterise their manual page build process, that would still make it
hard to refer to a particular page in documentation not delivered with the
installed software.  An article about configuring _rsync_ might reasonably
reference _rsyncd.conf(5)_, even though an idiomatically delivered page would
be _rsyncd.conf(4)_ on an illumos system today.  As ZFS sees increasing use and
development on other operating systems, more articles will be written that
refer to _zpool(8)_ and _zfs(8)_, rather than _zpool(1M)_ and _zfs(1M)_.

## Proposed Renumbering

| Current Section | Proposed New Section |
| --------------- | -------------------- |
|    1M           |     8                |
|    4            |     5                |
|    5            |     7                |
|    7\*          |     4\*              |

Administrative commands are presently documented in a subsection, 1M.  The
contents of this subsection would move to the top level of the new section 8.

The subsections of section 7 (e.g., 7D, 7FS, 7I, etc) would become subsections
of the new section 4 (i.e., 4D, 4FS, 4I, etc).  Section 4 & 5 do not appear to
have subsections today, though there is an apparently vestigial 4B which would
likely just discard as part of this transition.

## Manual Page Search Order

Several accommodations should be made to improve the user experience through
this transition.  The approach described below is similar to the one described
in a [blog post about the section renumbering in Solaris 11.4][alanc].

### Backwards Compatibility

The `man` command should be made aware of the mapping from old to new section
names, in order to aid users in the transition.

If a user requests a manual page from one of the renumbered sections (e.g.,
_ip(7P)_) but that page is not found on disk by `man`, a fallback search will
be attempted in the new section (i.e., _ip(4P)_).  In practice there are few
manual pages which actually overlap between the sections we seek to renumber,
so this seems likely to help most people most of the time.

### Automatic Subsection Search

Users from other platforms are likely less used to the presence of subsections
in the manual.  In many cases this isn't a problem: `man malloc` will find the
correct page, _malloc(3C)_.  When no specific section is requested, `man` will
look in each section and subsection in turn and display the first match.

In some cases it's more complicated.  A user looking for the `basename()`
library routine will probably start with `man basename`, hitting the
manual page for the `basename` _command_.  Realising their mistake, they
will perhaps reflexively check in section 3; alas:

```
$ man -s 3 basename
No manual entry for basename in section(s) 3
```

The manual page for the `basename()` routine actually appears (with other C
library routines) in 3C.  The `man` command could, upon not finding a relevant
page in the top-level section, attempt a search of any relevant subsections.
This would use the same search order as if the user had provided no `-s` option
to `man`, except constrained to subsections of the nominated top-level section.

## Other Operating Systems

A survey of several actively maintained operating systems in the UNIX family
suggests that manual page section numbering is indeed effectively uniform.  A
review of the specifics, using phrasing from each platform's documentation,
appears below with references.

### Linux

According to [man(1)][linux-man1] at the [Linux man-pages project][lmpp], the
following section numbers are in use:

| Section | Description |
| ------- | ----------- |
| 1       | Executable programs or shell commands |
| 2       | System calls (functions provided by the kernel) |
| 3       | Library calls (functions within program libraries) |
| 4       | Special files (usually found in `/dev`) |
| 5       | File formats and conventions; e.g., `/etc/passwd` |
| 6       | Games |
| 7       | Miscellaneous (including macro packages and conventions); e.g., _man(7)_, _groff(7)_ |
| 8       | System administration commands (usually only for root) |
| 9       | Kernel routines [Non standard] |

### FreeBSD

According to [man(1)][freebsd-man1] in the [FreeBSD manual pages][freebsd-man]
for FreeBSD 12, the following section numbers are in use:

| Section | Description |
| ------- | ----------- |
| 1       | General Commands Manual |
| 2       | System Calls Manual |
| 3       | Library Functions Manual |
| 4       | Kernel Interfaces Manual |
| 5       | File Formats Manual |
| 6       | Games Manual |
| 7       | Miscellaneous Information Manual |
| 8       | System Manager's Manual |
| 9       | Kernel Developer's Manual |

### OpenBSD

According to [man(1)][openbsd-man1] from OpenBSD, the following section numbers are in use:

| Section | Description |
| ------- | ----------- |
| 1       | General commands (tools and utilities) |
| 2       | System calls and error numbers |
| 3       | Library functions |
| 3p      | perl(1) programmer's reference guide |
| 4       | Device drivers |
| 5       | File formats |
| 6       | Games |
| 7       | Miscellaneous information |
| 8       | System maintenance and operation commands |
| 9       | Kernel internals |

Notably, the OpenBSD manual has at least one documented subsection: 3P for Perl libraries.

### NetBSD

The [NetBSD manual][netbsd-man] appears to contain at least the following sections:

| Section | Description |
| ------- | ----------- |
| 1       | General commands |
| 2       | System calls and error numbers |
| 3       | C library functions |
| 3f      | FORTRAN library functions |
| 3lua    | Lua modules |
| 4       | Special files and hardware support |
| 5       | File formats |
| 6       | Games and demos |
| 7       | Miscellaneous information pages |
| 8       | System maintenance commands |
| 9       | Kernel internals |
| 9lua    | Lua kernel bindings |

Notably, the NetBSD manual has several subsections.

### Solaris 11.4

According to [man(1)][sol114-man1] from [Oracle Solaris 11.4], the following sections are in use:

| Section | Description |
| ------- | ----------- |
| 1       | Commands available with the operating system |
| 2       | System calls |
| 2D      | DTrace Providers |
| 3       | Functions found in various libraries |
| 3\*     | Collections of related libraries |
| 4       | Various device and network interfaces |
| 4D      | Special files that refer to specific hardware peripherals and device drivers |
| 4FS     | Programmatic interface for several file systems supported by Oracle Solaris |
| 4I      | Ioctl requests which apply to a class of drivers or subsystems |
| 4M      | STREAMS modules |
| 4P      | Network protocols available in Oracle Solaris |
| 5       | Formats of various files |
| 6       | Games and screensavers |
| 7       | Miscellaneous documentation such as character-set tables |
| 8       | Commands primarily used for system maintenance |
| 8S      | SMF services |
| 9       | Reference information needed to write device drivers |
| 9E      | Entry-point routines a developer can include in a device driver |
| 9F      | Kernel functions available for use by device drivers |
| 9P      | Driver properties |
| 9S      | Data structures used by drivers to share information between the driver and the kernel |

Oracle Solaris shares a common heritage with the illumos code base, as
evidenced by the similarly prolific use of subsections throughout the manual.
Note that Oracle Solaris performed a [similar renumbering of their manual
sections][alanc] with the release of version 11.4.



<!-- References -->
[lmpp]: https://www.kernel.org/doc/man-pages/
[linux-man1]: http://man7.org/linux/man-pages/man1/man.1.html
[freebsd-man]: https://www.freebsd.org/cgi/man.cgi
[freebsd-man1]: https://www.freebsd.org/cgi/man.cgi?query=man&apropos=0&sektion=0&manpath=FreeBSD+12.0-RELEASE+and+Ports&arch=default&format=html
[openbsd-man1]: https://man.openbsd.org/man.1
[netbsd-man]: http://man.netbsd.org
[sol114-man1]: https://docs.oracle.com/cd/E88353_01/html/E37839/man-1.html
[alanc]: https://blogs.oracle.com/solaris/normalizing-man-page-section-numbers-in-solaris-114-v2
[wp-man]: https://en.wikipedia.org/wiki/Man_page

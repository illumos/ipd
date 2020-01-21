---
authors: Andy Fiddaman <andy@omnios.org>
state: draft
---

# IPD 12 /proc/\<pid\>/fdinfo/

## Introduction

[_sys/procfs.h_](https://github.com/illumos/illumos-gate/blob/master/usr/src/uts/common/sys/procfs.h#L507) defines a data structure called `prfdinfo_t`.

```
/*
 * Open files.  Only in core files (for now).  Note that we'd like to use
 * the stat or stat64 structure, but both of these structures are unfortunately
 * not consistent between 32 and 64 bit modes.  To keep our lives simpler, we
 * just define our own structure with types that are not sensitive to this
 * difference.  Also, it turns out that pfiles omits a lot of info from the
 * struct stat (e.g. times, device sizes, etc.) so we don't bother adding those
 * here.
 */
```

Despite the comment, this is currently used in four places within gate:

1. Kernel-generated core files

   One `prfdinfo_t` structure per file descriptor is written to the notes
   section of a core file. This is how
   [pfiles(1)](https://illumos.org/man/pfiles)
   is able to operate on core files as well as live processes.

1. libproc-generated core files

   [Pgcore(3proc)](https://illumos.org/man/Pgcore) also generates core files
   containing this information. This is used by the
   [gcore(1)](https://illumos.org/man/gcore) utility and mdb's `::gcore`
   command.

1. libproc's `Pfdinfo_iter()`

   libproc provides a
   [Pfdinfo_iter(3proc)](https://illumos.org/man/Pfdinfo_iter)
   function which iterates the open file descriptors for a process and invokes
   a callback function, providing a `prfdinfo_t` structure as the second
   argument.

   This function is used by `pfiles` and
   [Pgcore(3proc)](https://illumos.org/man/Pgcore).

1. netstat

   When netstat is invoked with the `-u` option, it scans `/proc` and builds an
   internal hash of open file descriptors which represent sockets. As part of
   this it constructs and passes `prfdinfo_t` structures internally. Note that
   netstat does **not** use
   [Pfdinfo_iter(3proc)](https://illumos.org/man/Pfdinfo_iter)
   since this would require grabbing all processes in read/write mode which is
   more invasive than necessary, but it does
   [Pgrab(3proc)](https://illumos.org/man/Pgrab) processes which have
   open sockets in order to determine the socket type and protocol family.

## /proc/\<pid\>/fdinfo/

A new per-process directory will be created under `/proc/<PID>/`

> **fdinfo**
>
> A directory containing information about each of the process's open files.
> Each entry is a decimal number corresponding to an open file descriptor in
> the process.
>
> Each file contains a prfdinfo_t structure followed by zero or more
> pr_misc_header_t structures.

The files will be mode 0400 and owned by the owner of the process.

## prfdinfo_t

The `prfdinfo_t` structure layout will be changed to the same as the one
used in Solaris -
<https://docs.oracle.com/cd/E88353_01/html/E37852/proc-5.html>.

The existing structure will be renamed to `prfdinfo_core_t` to reflect its
continued use in core files (see below).

```C
/* PRFNSZ is already defined in procfs.h */
#define PRFNSZ          16      /* Maximum size of execed filename */


typedef struct prfdinfo {
    int          pr_fd;          /* file descriptor number */
    mode_t       pr_mode;        /* (see st_mode in stat(2)) */
    uint64_t     pr_ino;         /* inode number */
    uint64_t     pr_size;        /* file size */
    int64_t      pr_offset;      /* current offset of file descriptor */
    uid_t        pr_uid;         /* owner's user id */
    gid_t        pr_gid;         /* owner's group id */
    major_t      pr_major;       /* major number of device containing file */
    minor_t      pr_minor;       /* minor number of device containing file */
    major_t      pr_rmajor;      /* major number (if special file) */
    minor_t      pr_rminor;      /* minor number (if special file) */
    int          pr_fileflags;   /* (see F_GETXFL in fcntl(2)) */
    int          pr_fdflags;     /* (see F_GETFD in fcntl(2)) */
    short        pr_locktype;    /* (see F_GETLK in fcntl(2)) */
    pid_t        pr_lockpid;     /* process holding file lock (see F_GETLK) */
    int          pr_locksysid;   /* sysid of locking process (see F_GETLK) */
    pid_t        pr_peerpid;     /* peer process (socket, door) */
    int          pr_filler[25];  /* reserved for future use */
    char         pr_peername[PRFNSZ]; /* peer process name */
#if __STDC_VERSION__ >= 199901L
    uint8_t      pr_misc[];      /* self describing structures */
#else
    uint8_t      pr_misc[1];
#endif
} prfdinfo_t;

/*
 * This was previously prfdinfo_t but is now only used in the notes sections
 * of core files.
 */
typedef struct prfdinfo_core {
    int          pr_fd;
    mode_t       pr_mode;
    uid_t        pr_uid;
    gid_t        pr_gid;
    major_t      pr_major;       /* think stat.st_dev */
    minor_t      pr_minor;
    major_t      pr_rmajor;      /* think stat.st_rdev */
    minor_t      pr_rminor;
    ino64_t      pr_ino;
    off64_t      pr_offset;
    off64_t      pr_size;
    int          pr_fileflags;   /* fcntl(F_GETXFL), etc */
    int          pr_fdflags;     /* fcntl(F_GETFD), etc. */
    char         pr_path[MAXPATHLEN];
} prfdinfo_core_t;
```

Core files will continue to include old format structures in their notes
sections, as type `prfdinfo_core_t`.

The `pr_misc` element points to the start of a list of additional
miscellaneous data items, each of which has a header specifying the
size and type, and some data which immediately follow the header.

```C
typedef struct pr_misc_header {
    uint_t          pr_misc_size;
    uint_t          pr_misc_type;
} pr_misc_header_t;
```

Each `pr_misc_header_t` starts on an 4-byte boundary with any preceding
padding space filled with zeros.

The `pr_misc_size` field is the sum of the sizes of the header and the
associated data.

The end of the list is indicated by a header with a zero size and an all-ones
type field, 0xffffffff. Since the size includes the size of the header, a zero
size cannot appear in a valid header.

The following miscellaneous data types are provided. Some are currently not
implemented for illumos but are noted in this list and gaps will be left in
the numbering to retain binary compatibility with the Solaris interface.

* PR\_PATHNAME
* PR\_SOCKETNAME
* PR\_PEERSOCKNAME
* PR\_SOCKOPTS\_BOOL\_OPTS
* PR\_SOCKOPT\_LINGER
* PR\_SOCKOPT\_SNDBUF
* PR\_SOCKOPT\_RCVBUF
* PR\_SOCKOPT\_IP\_NEXTHOP
* PR\_SOCKOPT\_IPV6\_NEXTHOP
* PR\_SOCKOPT\_TYPE
* (unimplemented PR\_SOCKOPT\_LISTENQLIMIT)
* PR\_SOCKOPT\_TCP\_CONGESTION
* (unimplemented PL\_PR\_SOCKOPT\_FLOW\_NAME)
* (unimplemented PL\_PR\_SOCKOPTS\_PRIV)
* PR\_SOCKFILTERS\_PRIV

and there will also be:

* PR\_MISC\_TYPES\_MAX

to indicate the maximum type value.

## Changes to libproc

1. The `Pfdinfo_iter(3proc)` function will be modified to pass the new
   format `prfdinfo_t` to the callback function.

1. A number of new API functions will be added to handle `prfdinfo_t`
   structures. These functions will not require that a process handle be
   held since one of the benefits of the new `/proc/<PID>/fdinfo/` files
   is that they can be read without having to grab the target process.

   1. proc\_get\_fdinfo()
      ```C
      prfdinfo_t *proc_get_fdinfo(pid_t pid, int fd);
      ```

      Retrieve a `prfdinfo_t` structure for an open file in a process.
      The returned structure must be freed after use using `proc_fdinfo_free()`.

   1. proc\_fdinfo\_free()
      ```C
      void proc_fdinfo_free(prfdinfo_t *info);
      ```

      Free a `prfdinfo_t` structure.

   1. proc\_fdinfo\_misc()
      ```C
      const void *proc_fdinfo_misc(const prfdinfo_t *, uint_t type, size_t *len);
      ```

      Scan a `prfdinfo_t` structure for the first miscellaneous item of
      type `type` and, if found, return a pointer to that data. If not null,
      the length of that data is stored in the address pointed to by len.
      On error, this function returns NULL and sets errno to indicate the
      reason.

1. New iterator APIs will be added as follows.

   1. Iterate a process' open files and receive a pointer to a `prfdinfo_t`
      structure for each:

      ```C
      typedef int proc_fdwalk_f(const prfdinfo_t *, void *);
      int proc_fdwalk(pid_t, proc_fdwalk_f *, void *);
      ```

   1. Iterate a `prfdinfo_t` structure and receive the data associated with
      each misc type:

      ```C
      typedef int proc_fdinfowalk_f(uint_t type, const void *data, size_t len, void *);
      int proc_fdinfowalk(const prfdinfo_t *, proc_fdinfowalk_f *, void *);
      ```

## Changes to netstat

With the above changes in place, netstat can be modified to use the new
file descriptor iterator, and to retrieve information from the `prfdinfo_t`
structures directly, without having to grab and inject calls into the target
process. The code that currently generates pseudo prfdinfo\_t structures can
be removed.

As part of this change, `netstat` will also be changed to use libproc's
[proc_walk(3proc)](https://illumos.org/man/proc_walk) function which will
further simplify the code, and have an additional benefit of allowing
`/native/usr/bin/netstat -u` to work within, for example, lx zones.

## Changes to pfiles

pfiles will be modified to expect `prfdinfo_t` structures passed to the
callback function, and to extract data directly from these structures where
possible rather than injecting system calls into the target process.

It will also be changed to convert `prfdinfo_core_t` structures found in core
files to `prfdinfo_t` before processing them.

## Changes to core file generation

There will be no changes to in-kernel core file generation.

The `Pgcore(3proc)` function will be changed to expect `prfdinfo_t`
structures to be passed to its callback, but to convert them to
`prfdinfo_core_t` before writing to the notes section of the core file.

## Implementation

It is proposed to integrate this change as two separate commits:

1. Provide /proc/\<PID\>/fdinfo/\<FD\>;
   Update `libproc`, add new API functions and modify existing Pfdinfo;
   Update `pfiles`

1. Update `netstat`

## Future work

It may be possible to have `pfiles(1)` gather the required information
without having to grab processes and inject a worker thread at all.

The core file format could be updated to accommodate the new style `prfdinfo_t`
structures instead of, or alongside, `prfdinfo_core_t`.

There is a patched version of `lsof` floating around that uses `pfiles`.
It would be nice to get this updated to use the new fdinfo files, and to
submit the patch upstream for illumos (and Solaris?) support.

## Examples (from prototype)

```bash
# pfiles `pgrep -n sshd` | grep -A6 5:
   5: S_IFSOCK mode:0666 dev:559,0 ino:63783 uid:0 gid:0 rdev:0,0
      O_RDWR|O_NONBLOCK FD_CLOEXEC
        SOCK_STREAM
        SO_REUSEADDR,SO_KEEPALIVE,SO_SNDBUF(49152),SO_RCVBUF(128872)
        sockname: AF_INET 172.27.10.9  port: 22
        peername: AF_INET 172.27.10.79  port: 38576
      offset:25042
```

```bash
# xxd < /proc/`pgrep -n sshd`/fdinfo/5
00000000: 0500 0000 b6c1 0000 27f9 0000 0000 0000  ........'.......
00000010: 0000 0000 0000 0000 1670 0000 0000 0000  .........p......
00000020: 0000 0000 0000 0000 2f02 0000 0000 0000  ......../.......
00000030: 0000 0000 0000 0000 8200 0000 0100 0000  ................
00000040: 0300 0000 ffff ffff ffff ffff ffff ffff  ................
00000050: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000060: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000070: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000080: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000090: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000c0: 0000 0000 1800 0000 0100 0000 0200 0016  ................
000000d0: ac1b 0a09 0000 0000 0000 0000 1800 0000  ................
000000e0: 0200 0000 0200 96b0 ac1b 0a4f 0000 0000  ...........O....
000000f0: 0000 0000 0c00 0000 0300 0000 0a00 0000  ................
00000100: 1000 0000 0400 0000 0000 0000 0000 0000  ................
00000110: 0c00 0000 0900 0000 0200 0000 0c00 0000  ................
00000120: 0500 0000 00c0 0000 0c00 0000 0600 0000  ................
00000130: 68f7 0100 0800 0000 0700 0000 1000 0000  h...............
00000140: 0a00 0000 7375 6e72 656e 6f00 0000 0000  ....sunreno.....
00000150: 0000 0000                                ....
```

```bash
# ls -l /proc/`pgrep -n sshd`/fdinfo
total 12
-r--------   1 af       other        237 Dec  3 13:52 0
-r--------   1 af       other        237 Dec  3 13:52 1
-r--------   1 af       other        239 Dec  3 13:52 11
-r--------   1 af       other        239 Dec  3 13:52 12
-r--------   1 af       other        237 Dec  3 13:52 2
-r--------   1 af       other        204 Dec  3 13:52 3
-r--------   1 af       other        204 Dec  3 13:52 4
-r--------   1 af       other        332 Dec  3 13:52 5
-r--------   1 af       other        204 Dec  3 13:52 6
-r--------   1 af       other        292 Dec  3 13:52 7
-r--------   1 af       other        300 Dec  3 13:52 8
-r--------   1 af       other        239 Dec  3 13:52 9
```

```bash
# ./fdinfo /proc/`pgrep -n sshd`/fdinfo/5
Read 340 bytes
                 fd: 5
               mode: 140666
                ino: 63783
               size: 0
             offset: 35102
                uid: 0
                gid: 0
              major: 559
              minor: 0
             rmajor: 0
             rminor: 0
          fileflags: 82
            fdflags: 1
           locktype: 3
            lockpid: 4294967295
          locksysid: ffffffff
            peerpid: -1
           peername:
MISC 24 / 1 - PR_SOCKETNAME
00000000: 02 00 00 16 ac 1b 0a 09 00 00 00 00 00 00 00 00  ................
MISC 24 / 2 - PR_PEERSOCKNAME
00000000: 02 00 96 b0 ac 1b 0a 4f 00 00 00 00 00 00 00 00  .......O........
MISC 12 / 3 - PR_SOCKOPTS_BOOL_OPTS
00000000: 0a 00 00 00                                      ....
MISC 16 / 4 - PR_SOCKOPT_LINGER
00000000: 00 00 00 00 00 00 00 00                          ........
MISC 12 / 9 - PR_SOCKOPT_TYPE
00000000: 02 00 00 00                                      ....
MISC 12 / 5 - PR_SOCKOPT_SNDBUF
00000000: 00 c0 00 00                                      ....
MISC 12 / 6 - PR_SOCKOPT_RCVBUF
00000000: 68 f7 01 00                                      h...
MISC 16 / 10 - PR_SOCKOPT_TCP_CONGESTION
00000000: 73 75 6e 72 65 6e 6f 00                          sunreno.
```

#### Performance improvement

This is the test script from
[illumos issue 5397](https://www.illumos.org/issues/5397)
- by Dave Eddy.

```js
#!/usr/bin/env node
var net = require('net');
var num = +process.argv[2] || 1000;
for (var i = 0; i < num; i++)
  net.connect(80, 'www....elided...');
console.log('opened %d sockets', num);
```

```bash
# ./sockets &
[1] 100703
opened 1000 sockets

# ptime pfiles 100703 >/dev/null

real        0.543506146
user        0.056559647
sys         0.335565083

# ptime ./oldpfiles 100703 >/dev/null

real        6.251319408
user        0.607150599
sys         3.718054147
```


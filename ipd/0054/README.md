---
author: Bill Sommerfeld
sponsor:
state: predraft
---

# Considerations around updating illumos-gate system sqlite to sqlite 3

## Background

Several components of illumos-gate, most notably SMF, rely on the
SQLite database to store configuration information.  The version of
SQLite used for this purpose is a patched version of 2.8.15, which was
released in 2004; it uses a database format that is not compatible
with current releases of SQLite 3.

The idmap facility and the "libsmb" library used by the SMB server
also use sqlite2.

The developers of SQLite have committed to maintain the database
[through at least the year 2050](https://sqlite.org/lts.html); they
have also made a [long-term commitment to the 3.x file
format](https://www.sqlite.org/formatchng.html).

## SQLite in SMF

Within SMF, svc.configd is the only program which directly reads or
writes the SMF configuration database.

svc.configd runs very early (its start is special-cased in svc.startd) and
as a result has to cope with a very constrained early environment,
including a potentially read-only filesystem.

### Upgrading the SMF database content

SQLite databases can in theory be upgraded to version 3 via a
dump/restore pass that can be scripted using the old and new versions
of the sqlite CLI.

As a test, I dumped my workstation's /etc/svc/repository.db into sql
dump format with sqlite 2, then loaded it into a recent sqlite3.

The process worked without any reported errors.  The resulting
database file was about half the size of the older format (3.34MB vs
6.64M).

I then as a test dumped it again from sqlite3, compared the two dumps,
and found a few discrepancies.

In particular, sqlite uses a somewhat fuzzy typing system, and
versions 2 and 3 have slightly different interpretations of this.

SQLite integers are signed 64 bit values.   SMF has been storing unsigned 64-bit values.

One value (18446744073709551615, perhaps better known as
0xffffffffffffffff) appeared a few times in the original dump.  In the
dump from the sqlite3 database, I found '1.84467440737096e+19' instead
-- it's larger than the largest signed 64-bit integer, so sqlite3
converts it to floating point.

Ironically, several of these values started off as a signed integer
(-1) in the SMF manifests that defined them; had they been handled by
the rest of SMF consistently as a signed value the conversion to
floating point could have been avoided.

### Upgrading sqlite in illumos-gate:

Need to look at local addons to libsqlite (idmap project added some
utf8 case conversion code!); convert this to the sqlite3 function
plugin interface?

Likewise, install the CLI into usr/src/cmd/sqlite3, for install into /lib/svc/bin

2) Build and package two versions of svc.configd - one built against
libsqlite-sys, and the other against libsqlite3-sys, operating on
different-named databases.

3) Build a conversion script that operates on an inactive mounted BE,
converting its /etc/svc/repository.db file into its sqlite3 counterpart.

4) Modify svc.startd to pick one or the other svc.configd based on
which repository database is present.

## Other consumers of sqlite 2 in illumos-gate

### Upgrading sqlite in idmap:

idmap stores one table in each of two databases.  One of them is a
cache which lives in /var/run which can be convered by recreating it
(and there is code in idmapd which already does this sort of
conversion).

The other database is found in /var/idmap/idmap.db; conversion could
be handled by having the daemon run a separate conversion program if
the new format database wasn't found.

### Upgrading sqlite in smbsrv/libsmb:

The libsmb library has code which accesses two persistent databases:

"/var/smb/smbhosts.db"
"/var/smb/smbgroup.db"

TODO: identify a a point early in the service dependency graph that
would allow the insertion of a conversion program/service.

## Strawman upgrade sequence:

1) Import a version of sqlite3.x.y into usr/src/lib/libsqlite3;
install it as /lib/libsqlite3-sys.so.3.x.y.  This library is not
expected to rapidly track upstream sqlite3

2) Convert idmap and smbsrv/libsmb to use sqlite3 first.

3) Create dual-version svc.configd (possibly as two binaries) and a
database conversion program.

...

# illumos Project Discussion

IPDs are a shrink-to-fit description of larger scale (in either code size or
impact) project wishing to make changes to illumos.  They should describe the
what and the why and give people the opportunity to comment on both.

An IPD is at its heart, just a README.md in a numbered directory in this
repository, existing IPDs are enumerated below for easy reference.  Further
information is available at the end of this document.

## IPDs

| state     | IPD |
| --------- | ------------------------------------------------------------- |
| predraft  | [IPD 1 Virtual Environment for Jenkins Build and Test](./ipd/0001/README.md) |
| published | [IPD 2 Running smatch for illumos builds](./ipd/0002/README.md) |
| published | [IPD 3 Link management improvements](./ipd/0003/README.adoc) |
| published | [IPD 4 Manual Page Section Renumbering](./ipd/0004/README.md) |
| published | [IPD 5 Rationalize SPARC platform support](./ipd/0005/README.md) |
| draft     | [IPD 6 allocb(): The `pri` argument, and use of KM_NORMALPRI](./ipd/0006/README.md) |
| published | [IPD 7 illumos GCC maintenance](./ipd/0007/README.md) |
| published | [IPD 8 EOF NCA/NL7C](./ipd/0008/README.md) |
| published | [IPD 9 PCI Alias Disambiguation](./ipd/0009/README.md) |
| published | [IPD 10 full argv in ps](./ipd/0010/README.md) |
| published | [IPD 11 NFS Server for Zones (NFS-Zone)](./ipd/0011/README.md) |
| published | [IPD 12 /proc/_PID_/fdinfo/](./ipd/0012/README.md) |
| published | [IPD 13 Safer DDI DMA Cookie Functions](./ipd/0013/README.md) |
| predraft  | [IPD 14 illumos and Y2038](./ipd/0014/README.md) |
| published | [IPD 15 bhyve integration/upstream](./ipd/0015/README.md) |
| published | [IPD 16 EOF SunOS 4 binary compatibility](./ipd/0016/README.md) |
| draft     | [IPD 17 SMF Runtime Directory Creation Support](./ipd/0017/README.md)
| published | [IPD 18 overlay network integration/upstream](./ipd/0018/README.md)
| published | [IPD 19 Sunset SPARC](./ipd/0019/README.md)
| draft     | [IPD 20 Kernel Test Facility](./ipd/0020/README.adoc)
| published | [IPD 21 PCI Platform Unification](./ipd/0021/README.md)
| draft     | [IPD 22 Unsharing shared Libraries](./ipd/0022/README.md)
| predraft  | [IPD 23 Xen and the Art of Operating System Maintenance: A Removal of a Platform](./ipd/0023/README.md)
| predraft  | [IPD 24 Support for 64-bit ARM](./ipd/0024/README.md)
| draft     | [IPD 25 Authenticated pfexec](./ipd/0025/README.md)
| draft     | [IPD 26 Sunset CardBus and PC Card](./ipd/0026/README.md)
| published | [IPD 27 Sunset TNF](./ipd/0027/README.md)
| draft     | [IPD 28 EOF Legacy Network Driver interfaces](./ipd/0028/README.md)
| published | [IPD 29 Sunset Sockets Direct Protocol](./ipd/0029/README.md)
| draft     | [IPD 30 Remove obsolete SCSA functions](./ipd/0030/README.md)
| published | [IPD 31 Kernel interface stability documentation](./ipd/0031/README.md)
| draft     | [IPD 32 Introduce scsi_hba_pkt_mapin](./ipd/0032/README.md)
| predraft  | [IPD 33 Obsolete legacy SCSI HBA API](./ipd/0033/README.md)
| draft     | [IPD 34 Rationalize Kernel Architecture Module Paths](./ipd/0034/README.md)
| draft     | [IPD 35 Sunset VTOC - SPARC](./ipd/0035/README.md)
| draft     | [IPD 36 Rationalize $(MACH64) Command Paths](./ipd/0036/README.md)
| published | [IPD 37 Vendor-specific Command, Log, and Feature Support in nvmeadm(8)](./ipd/0037/README.md)
| published | [IPD 38 Signal Handling, Extended FPU State, ucontexts, x86, and You](./ipd/0038/README.adoc)
| published | [IPD 39 Datalink Media Types](./ipd/0039/README.adoc)
| draft     | [IPD 40 Cross compilation for illumos](./ipd/0040/README.md)
| published | [IPD 41 Improving PCI devinfo Naming and Future Platforms](./ipd/0041/README.adoc)
| draft     | [IPD 42 Sunset native printing](./ipd/0042/README.md)
| published | [IPD 43 NVMe 2.0, libnvme, and the nvme(4D) ioctl interface](./ipd/0043/README.adoc)
| predraft | [IPD 44 Distribution as a first class concept](./ipd/0044/README.adoc)


## Contributing

Contributions are welcome.  A good rule of thumb as to whether you _should_
have an IPD is whether you are making a change with high impact to other
developers or users (introducing or removing a supported platform, doing
something with non-obvious compatibility constraints), or engaging in a
long-term project that will likely integrate in pieces, to provide the overall
picture.

For your first contribution, you might want to just submit a pull request to
this repository.  Going forward if this is a thing that you will do again,
we'll probably give you write access to this repository so you can just add
your new IPDs as they come up.

## Format

An IPD has a short header block indicating authorship (that's you),
sponsorship (we'll get to that), and state.

### States

#### predraft

You've started writing your IPD and you want to share it narrowly, or even
just to reserve your a number in this repository.  You're _predraft_, maybe
you only have a title and a short paragraph right now, that's fine.

#### draft

You've finished writing and explaining, and now you're going to send your IPD
to the [developer mailing list](mailto:developer@lists.illumos.org), this is a
draft, you're going to receive feedback so it's not complete, but it's close.

#### published

One or more people from the [illumos core
team](https://illumos.org/docs/about/leadership/) have agreed that what you've
described is a good thing, and that we should do it.  Your IPD is done and
published (though is not immutable! If you find more information would be
useful later, please add it!)

### Sponsorship

"Sponsor" is a weird word here, it's just the person or people on the illumos
core team who were ok with your IPD.  Don't worry about it.

---
authors: Joshua M. Clulow <josh@sysmgr.org>
state: predraft
---

# IPD 1 Virtual Environment for Jenkins Build and Test

To aid in improved efficiency and consistency in the process of [integrating
changes](https://wiki.illumos.org/display/illumos/How+To+Contribute) into
[illumos-gate](https://github.com/illumos/illumos-gate), it would help to have
the project provide central infrastructure that can run a full
[nightly](https://illumos.org/man/1ONBLD/nightly) build of any particular
change.  It would also aid in testing to be able to take bits built from that
change, boot them in a virtual machine, and run some of our automated test
suites.

This project will explore the provision of such infrastructure at
https://illumos.org and how to fold it in to our integration process.

## Operating System Issues

There are a number of paper cuts that stand in the way of a stream-lined
process, some of which represent operating system bugs -- or at least areas
where we could make enhancements.  A non-exhaustive list appears below:

* [Bug 9985](https://www.illumos.org/issues/9985) blkdev devices can have an invalid devid
* [Bug 10012](https://www.illumos.org/issues/10012) vioblk should not accept an all-zero serial number
* [Bug 7119](https://www.illumos.org/issues/7119) boot should be more resilient to physical path to bootfs changing
* [Bug 1857](https://www.illumos.org/issues/1857) "No SOF interrupts have been received..USB UHCI is unusable" under KVM

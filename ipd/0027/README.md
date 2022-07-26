---
author: Toomas Soome
sponsor: Garrett D'Amore
state: draft
---

# Sunset TNF

## Introduction

From TRACING(3TNF):
TNF is set of programs and API's that can be used to present a high-level view of the performance of an executable, a library, or part of the kernel.

In short, it is superseded by dtrace and has become digital waste.

## Proposal

Remove TNF. The implementation is consisting of userland programs, headers and libraries and kernel API/probes:

1. tnf kernel module
2. tnf feature integration in parts of kernel
3. tnf feature integration in kernel modules: av1394, hci1394 , hermon, ibmf, s1394, tavor
4. libtnf, libtnfctl and libtnfproble libraries, manuals
5. prex, tnfdump and tnfxtract commands
6. packaging.

I have prepared the change:

[link to gerrit review](https://code.illumos.org/c/illumos-gate/+/1707)

## Conversion of Pre-Existing Probes

Some probes, specifically in the scheduler, should probalby be converted to static DTrace probes.
Specifically the following probes will be replaced with DTRACE_SCHED1() probes as follows:

* schedctl_failsafe -- becomes schedctl__failsafe, taking kthread_t
* swapin_lwp -- becomes swapin__lwp, taking kthread_t
* swapout_lwp -- becomes swapout__lwp, taking kthread_t
* swapout_process -- becomes swapout__process, taking proc_t

There will be no effort to convert the remaining TNF probes.
Most of them are in either the obsolescent IEEE1394 stack or the tavor Infiniband HCA.
Many of them (most!) can easily be handled with just the DTrace FBT provider.

## Prior Discussion

[illumos-developer](https://illumos.topicbox.com/groups/developer/T35ec4a1cf45f3206-Me7b3ac7e1ca6b0c8ac78b971/tnf)

## Related Issues

[14079 remove TNF](https://www.illumos.org/issues/14079)

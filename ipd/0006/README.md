---
author: Dan McDonald
state: predraft
---

# IPD 6 `allocb`(9F): The `pri` argument, and use of KM_NORMALPRI

## Introduction

Today, the `allocb`(9F) kernel function documents a priority field (`pri`),
but literally states in its documentation that it is, "no longer used".
Indeed, a [source
inspection](http://src.illumos.org/source/xref/illumos-gate/usr/src/uts/common/io/stream.c#414)
indicates that `pri` is ignored.  In spite of this, the approximately 250
callers of `allocb`(9F) use all three different priority values, in vain.

Possibly independent of the priority parameter, the kernel memory flags used
for `allocb`(9F) are always KM_NOSLEEP, that is, non-blocking.  This makes
sense, given `allocb`(9F) can be called in interrupt context. A
OpenSolaris-era bugfix,
[6675738](https://github.com/illumos/illumos-gate/commit/23a80de1aec78d238d06caf311eaceb81dd5a440),
introduced KM_NORMALPRI, requesting to use a less-persistent allocation for
non-blocking allocations.  DTrace adopted this as [illumos issue
1452](https://github.com/illumos/illumos-gate/commit/6fb4854bed54ce82bd8610896b64ddebcd4af706#diff-64e6f1587817235d06f7d2db19a97967)
early in the life of illumos.

Three questions fall out of the prior two observations:

1.) Should `allocb`(9F) exploit KM_NORMALPRI?

2.) If the answer to #1 is "maybe", should the priority argument in
`allocb`(9F) have meaning again?

3.) If via certain answers to the prior two questions priority remains
unused, should it be removed outright?

## Measurements and observations needed

The `allocb`(9F) function should be measured and observed in a way similarly to
illumos 1452.  A loaded system should be able to trigger an agressive
reclaim, and DTrace can likely be employed to detect it.

## Implementation

An intial implementation would find the places in `allocb`(9F) that use
KM_NOSLEEP and, depending on design decisions surrounding the priority
argument, logical-or the KM_NORMALPRI flag as well.

## Scope of fix

While this IPD focusses on allocation flags solely on the `allocb`(9F)
function, other STREAMS mblk allocators like `esballoc`(9F) (and variants)
also could benefit from KM_NORMALPRI as well.

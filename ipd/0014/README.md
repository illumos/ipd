---
author: Dan McDonald (will need others...)
state: predraft
---

# IPD 11 illumos and Y2038

## Introduction

The Year 2038 problem (Y2038) is a shorthand for the class of problems
related to the use of a 32-bit `time_t` in 32-bit illumos programs,
libraries, and even some kernel modules designed and implemented when
`time_t` was actually 32-bit.  2038 is the year 2^31-1 seconds after the UNIX
epoch of GMT-midnight January 1, 1970.

While illumos has eliminated 32-bit kernels in x86/amd64 environments

## History and Fundamentals

XXX KEBE THINKS:  Two obvious choices: Linux-style time32_t/time64_t OR Just
64-bit It.
XXX KEBE ALSO THINKS: Just 64-Bit It seems easier BUT it mightn't be
(e.g. ls(1))
XXX KEBE SAYS: This is why we have this section.
XXX KEBE SAYS: Some thing may just need to be EOLed (e.g. UFS)

## Implementation



## Testing


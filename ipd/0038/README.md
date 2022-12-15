---
author: Robert Mustacchi <rm@fingolfin.org>
state: predraft
---

# IPD 38 Signal Handling, Extended FPU State, ucontexts, x86, and You

As of this writing, illumos does not properly preserve the extended x86
register state as part of signal handling. This issue is documented in
[15254 %ymm registers not restored after signal
handler](https://www.illumos.org/issues/15254). The main goals of this
IPD are:

* To explain the challenges that we're facing and give appropriate
  context.
* To explain improvements to observability and the steps to fix this
  particular problem.
* Discuss forthcoming features on x86 that make this more challenging
  and how that changes are approach.
* Provide guidance for what should be done on future ports and other
  systems.

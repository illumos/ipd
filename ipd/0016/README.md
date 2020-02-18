---
authors: Peter Tribble, Toomas Soome
state: draft
---

# IPD 16 EOF SunOS 4 binary compatibility

On SPARC (but not intel), illumos retains support for running binaries
from SunOS 4. This involves 2 components:

* aoutexec kernel support
* libbc library emulation

There appears to be little demand for this capability - few or no users have
any such binaries.

While the aoutexec component is relatively trivial, libbc contains a lot
of code that is difficult to test. There is also a significant quantity of
assembler. The maintenance burden associated with this old code is
considerable, especially in the context of the various projects to
modernize the codebase and the toolchain. We're carrying around a lot of
dead weight here.

This subsystem also requires ucblib, preventing its removal.
Removal of ucblib is not within the scope of this project.

This project proposes to remove both libbc and aoutexec.

## Related issues:

* [Bug 12292](https://www.illumos.org/issues/12292) retire libbc

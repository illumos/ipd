---
author: Jason King <jason.brian.king@gmail.com>
state: draft
---

# IPD 22 Unsharing Shared Libraries

## Introduction

For decades, shared libraries have been used for runtime code sharing by applications.
As part of the implementation on illumos (and many other UNIX-like systems), the machine code instructions in the library (aka the 'text') also are shared in RAM.
That is, the virtual memory (VM) system on the illumos kernel will map the same physical pages of RAM that contain the text segments of a shared library into all of the processes using that shared library.
While this is largely benefical, for libraries that handle sensitive information such as crypto keys, this can be a detriment.
Cache timing attacks may allow malicious processes running on the same host to exploit this sharing of text pages to exfiltrate sensitive data.
This proposal is to introduce a new ELF section flag as well as a new security flag that will allow shared libraries or applications that opt-in to eliminate this sharing of pages of shared libraries in the VM subsystem and thus reduce the exposure to timing attacks.

## Interfaces

Within an ELF object, the machine code is typically contained in the `.text` section with the `SHF_ALLOC` and `SHF_EXECINSTR` flags set for that section.
We propose adding a new ELF section flag (e.g. `SHF_NOSHARE`) that indicates the contents of the section should not be shared by the VM subsystem by multiple processes.
The ELF section header has at least 8 currently unused bits of its `sh_flags` field (`SHF_MASKOS`).
One of these bits could be allocated for this purpose, and being specific to an OS, should avoid any problems with conflicting values from other platforms.
Support for a new linker option (e.g. `-z noshare`) will be added to `ld(1)` to generate ELF objects with this flag set.
It's anticipated libraries such as `libcrypto` or `libssl` (from openssl/libressl/etc) will be among the ones to use this (though it is likely that distributions delivering these libraries will need to add this flag to their build scripts).
Additionally, a new security flag (e.g. `PROC_SEC_NOSHARE`) will be added that will prevent sharing of text pages for all mapped text segments of a process.
This will allow programs that deal with large amounts of sensitive data to disable it for all shared objects instead of worrying about doing so in a piecemeal fashion.
If both the ELF section flag is present and the security flag is enabled, the effect is the same as if just the security flag is present -- it's effectively an 'OR' between the two so that using the two options will err on the side of using it more, not less.

## Implementation

While an implementation has not been written yet, we can look at the code of the existing VM subsystem to help guide the implementation.
Currently, there is a feature (disabled by default) intended for NUMA systems that will duplicate the pages of a text section into newly allocated anonymous memory implemented by the `segvn_textrepl()` and `segvn_textunrepl()` functions.
The intention for that feature is (based on the comments) to allow the instructions to reside in RAM 'close' to the cores that will be executing it.
The text pages of a shared library are 'faulted' in, and in `segvn_fault()` instead of mapping the vnode's pages, instead a segment of anonymous memory is allocated and the contents of the vnode's pages are copied to this anonymous memory.

The above feature as it turns out appears (from an initial look) to be largely what is desired -- except that instead of duplicating the pages based on NUMA topology, it is controlled by flags in the object itself.
This seems like it could (at minimum) be used as a basis for a proof of concept.
Such an approach will increase the amount of swap space that is reserved, but it seems like a reasonable tradeoff for the initial implementation.
As more experience is gained, a determination can be made if it would be worthwhile to make the 'unsharing' smarter or if a different implementation may be more adventageous (while preserving the proposed interfaces for enabling the feature).
For example, it may be worth eventually eliminating the need to reserve swap space for the unshared pages.
Instead, the kernel could merely page-in the original pages from from original object on disk in the event the in-RAM pages had to be discarded due to memory pressure (assuming pages are mapped read-only).

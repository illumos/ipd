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
We propose adding a new dynamic tag (e.g. `DT_NOSHARE`) with a value chosen from the appropriate range (likely an unused value between `DT_SUNW_ENCODING` and `DT_HIOS`).
When this tag present in the `.dynamic` section of an ELF executable or shared library, the corresponding `Elf{32,64}_Dyn.d_un.d_val` value shall be either `0` or `1`.
All other values are currently undefined.
When `d_val` is `1`, the kernel will not share mappings of the ELF object between processes.
Support for a new linker option (e.g. `-z noshare`) will be added to `ld(1)` to generate ELF objects with this flag set.
It's anticipated libraries such as `libcrypto` or `libssl` (from openssl/libressl/etc) will be among the ones to use this (though it is likely that distributions delivering these libraries will need to add this flag to their build scripts).
Additionally, a new security flag (e.g. `PROC_SEC_NOSHARE`) will be added that will prevent sharing of text pages for all mapped text segments of a process -- regardless of the presense or absense of the `DT_NOSHARE` tag in any libraries that are mapped into the process.
The dynamic tag as well as the security flag act as a logical 'OR' to trigger the non-sharing behavior.
This is to allow programs that deal with large amounts of sensitive data to disable it for all shared objects instead of trying to so in a piecemeal fashion and risk missing a library.

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

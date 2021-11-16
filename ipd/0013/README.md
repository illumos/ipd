---
authors: Robert Mustacchi <rm@fingolfin.org>
state: published
---

# IPD 13 Safer DDI DMA Cookie Functions

One of the responsibilities of the Device Driver Interface (DDI) is to
provide a set of APIs to set up and handle DMA ([Direct Memory
Access](https://en.wikipedia.org/wiki/Direct_memory_access)). Memory is
allocated for DMA in the vast majority of hardware device drivers. NIC
drivers and other PCIe devices call into the DMA related functions
directly, while some drivers like storage HBA drivers have many of the
data path allocations done on their behalf by operating system
frameworks.

To perform DMA, all device drivers go through the following three steps
to allocate memory:

1. Allocating an opaque handle, the `ddi_dma_handle_t`, which takes into
account a number of the constraints that the hardware imposes. For
example, a given hardware device may require that the requested memory
have a specific alignment, that it can't cross a specific sized
boundary, or that it only supports a specific range of addresses. The
function responsible for this is
[ddi_dma_alloc_handle(9F)](https://illumos.org/man/9f/ddi_dma_alloc_handle).

2. Allocating a region of virtual memory for the DMA request. The next
step uses the constraints given to allocate virtual memory for the
request and returns a virtual address, length, and a handle for it. This
creates memory that the device driver can use to read and write the
region. The function responsible for this is
[ddi_dma_mem_alloc(9F)](https://illumos.org/man/9f/ddi_dma_mem_alloc).

3. Binding the virtual memory to a series of physical addresses (or
device virtual addresses if the IOMMU is in use). This step ensures that
there are addresses that the device can access the memory at. The most
common function for this is
[ddi_dma_addr_bind_handle(9F)](https://illumos.org/man/9f/ddi_dma_addr_bind_handle).

Once these three steps have been done, the corresponding virtual and
physical memory is valid for the device. The device can use this across
multiple requests. For example, many networking device drivers will
allocate a given chunk of DMA memory for each packet that they want to
receive. After a packet is received and processed by the networking
stack, it will reuse the memory and program it again.

## DMA Cookies

When memory is bound, it is described through a structure called the
`ddi_dma_cookie_t`. This structure has two members: a physical address
and a length. A bound DMA handle (one that called ddi_dma_ddr_bind()),
can be represented by a variable number of cookies, based on the
constraints that were specified when creating the handle and the
underlying memory available in the system.

Some requests may fit in a single cookie while others may require dozens
of cookies to describe.

Today, when memory is bound or DMA windows are used, the driver receives
two items:

1. The total number of cookies that the device supports.
2. The driver provides storage for the first cookie and receives that
information.

To get the next cookie for a request, the driver simply calls the
`ddi_dma_nextcookie(9F)` function and specifies the handle of the
request (received from step 1 above) and a new cookie that should be
filled in with a copy of the next cookie.

## Challenges with Existing APIs

The existing APIs here have a number of challenges that can lead to not
just performance problems, but critical memory safety issues.

### Memory Safety Issues

The DMA handle is an opaque pointer to an implementation structure. The
`ddi_dma_impl_t`. On today's platforms, this contains an array of all
the DMA cookies that are associated with a given bound request. The way
that the `ddi_dma_nextcookie(9F)` function operates is that it mutates
the pointer into that array.

Critically, it does so blindly. The underlying `ddi_dma_impl_t`
structure **does not** keep track of the number of cookies that should
exist. This means that if a device driver asks for more cookies than it
should, it will simply walk off the end of an array and continue
dereferencing memory and ultimately wind up getting garbage, or another
device's DMA resources due to the use of a kmem cache.

Even worse, the `ddi_dma_nextcookie()` function does not have a return
value, it's simply `void`. So even if we added stricter checking in the
function, there's actually no way for us to check this and have a driver
act on it. If a driver uses this API incorrectly, which can be easy to
do due to some of the future problems we'll describe, there's not much
that can reasonably be done.

These memory safety issues have been triggered by folks while doing
device driver development and based on it, there's nothing that suggests
that these couldn't happen here.

### Performance and Memory Waste Issues

The mutation described above has several other side effects. Because the
underlying implementation array is actually being mutated, this means
that if a driver wants to reuse a DMA allocation in a request, which is
quite common, particularly in NIC drivers, the device has two options:

1. It can unbind and rebind the memory.
2. It can store all of the cookies that it uses.

The first case is purely wasteful at best. Binding and unbinding memory
means doing some number of kmem allocations and doing virtual address to
physical address translations or, if using the IOMMU, can mean that the
kernel will need to update device-specific page tables to indicate that
they can use that memory. In cases like high-performance NIC drivers,
they've been designed to avoid allocations in the data path, making this
not tenable.

As an alternative, many device driver end up walking over all of the
cookies that are used and then storing them in a request-specific data
structure. There are examples of this in the `xhci` and `virtio`
drivers. Ultimately, this means that we're wasting 2x the memory as DMA
handle has a copy of all of the cookies and the driver itself has a copy
of all the cookies.  In addition, to simplify the memory allocation, the
driver may actually have allocated a number of cookies that represent
the maximum number that it accepts, which might not all be used, meaning
that there is additional overhead.

### Summary

To summarize, the problems with the existing API is as follows:

1. The `ddi_dma_nextcookie()` function has no way to indicate to the
caller that it has done something wrong.
2. The `ddi_dma_nextcookie()` function, if called too many times, is not
memory safe.
3. There is no way to get a cookie a second time.  This leads to wasted
memory or redoing work.

## Proposal

To fix this situation, we propose doing a few different things:

1. Deprecating `ddi_dma_nextcookie()` and replacing it with a few
different iteration functions.
2. Modify the DMA handles to track additional information to facilitate
the new APIs and to make sure we can't walk off the end of the array.
3. Modifying the existing DMA binding functions to make them more
ergonomic when combined with the existing APIs.
4. Hardening `ddi_dma_nextcookie()` to catch issues like this and
terminate the system before damage is done and to catch programming
errors that could be introduced by combining the old and new APIs.

### New Functions

In place of `ddi_dma_nextcookie()` we propose to introduce four new
functions with the following signatures:

```
uint_t ddi_dma_ncookies(ddi_dma_handle_t *);
const ddi_dma_cookie_t *ddi_dma_cookie_iter(ddi_dma_handle_t *, const ddi_dma_cookie_t *);
const ddi_dma_cookie_t *ddi_dma_cookie_get(ddi_dma_handle_t *, uint_t);
const ddi_dma_cookie_t *ddi_dma_cookie_one(ddi_dma_handle_t *);
```

A manual page that documents all of these functions and explains how the
old one fits in is available [here](./ddi_dma_cookie_iter.9f.pdf).

The first function returns the number of cookies associated with the
handle. The function `ddi_dma_cookie_iter()` is designed to iterate over
all of the cookies. A driver will know that it has reached the last
cookie when the function returns `NULL` and to get the first cookie, the
driver passes `NULL` in as the second argument. This iteration looks
similar to walking a `list_t` and other structures in the system. For
example, a caller would do something like the following to iterate over
everything:

```
const ddi_dma_cookie_t *cookie;

for (cookie = ddi_dma_cookie_iter(handle, NULL); cookie != NULL;
     cookie = ddi_dma_cookie_iter(handle, cookie)) {
        ...
}
```

Notice that these functions all return a const pointer rather than
asking the driver for storage. This was done purposefully. This reduces
storage and helps to avoid mutation in the implementation.

Our goal with this interface was to make iteration possible with a
single local variable. These functions are often called while already
iterating over a for loop with an index (`for (i = 0; i < ... ; i++)`)
and we wanted to avoid the requirement of another integer index which
can often lead to someone using the wrong loop index for the inner,
nested loop.

Unlike `ddi_dma_nextcookie()`, the `ddi_dma_cookie_iter()` loop may
performed any number of times. There are no concerns around mutation and
there is a clear delineation of when it is finished.

The next function, `ddi_dma_cookie_get()`, was added to provide a way to
get specific cookies. While looking over various driver's usage of the
current APIs, we saw that sometimes drivers wanted to specifically do
something with the first cookie (which may contain a header or something
else) while the rest of the cookies are used normally.

Finally, the last function was added out of the observation that many
structures in device drivers, such as configuration data and descriptor
rings, can only support a single cookie. The goal of the
`ddi_dma_cookie_one()` interface is to make it easy to get a single
entry, but also have the underlying system confirm that only a single
entry was asked for. Effectively, this function will VERIFY that only a
single cookie is associated with the request.

### `ddi_dma_impl_t` changes

The implementation of these functions has a few constraints:

1. The current entry point, `ddi_dma_nextcookie()`, still needs to work.
Furthermore, it still requires the underlying mutation of the array.

2. We want to minimize the amount of storage that we use so we can
implement these APIs as the `ddi_dma_impl_t` is allocated for every DMA
allocation. An increase in the size of this structure can have a large
impact on used memory.

To implement this, I propose we add a pair of `uint_t` members to the
`ddi_dma_impl_t` structure. One will be used to track the total number
of cookies. The second will be used to track what cookie we've mutated
to. This will allow us to know how to find the first cookie in the array
and make sure that we can't walk off the end of the array.

### Auxiliary Changes

Today, the DMA functions which bind address and `buf_t` structures and
the functions which fetch windows require that the caller pass pointers
for the number of cookies that exist as well as to obtain the first
cookie. For callers that are using the new APIs, there's no reason to
require that they have to get this data as part of the bind call. As
such, we propose that callers may pass NULL pointers for both arguments.
This would impact the following DDI functions:

* `ddi_dma_addr_bind_handle(9F)`
* `ddi_dma_buf_bind_handle(9F)`
* `ddi_dma_getwin(9F)`

If a driver does this it should not call `ddi_dma_nextcookie()`. If it
does so, it will lose the first cookie. One suggestion to try and
prevent this kind of programmer error is to have the above functions set
a flag if we have a NULL cookie pointer, and in such cases, consider it a
fatal error if they then call `ddi_dma_nextcookie()`.

### `ddi_dma_nextcookie()` hardening

If a device driver erroneously calls `ddi_dma_nextcookie()` too many
times and programs the device with the extra cookies, this will almost
certainly result in arbitrary memory corruption in the system. Because
of the cost of such a bug and the fact that this is a programmer error,
we believe that it is justified to explicitly `panic()` the system in
this case. Unfortunately, there is no address we can safely return to
the device.

To make sure that we don't have a memory corruption bug introduced by
erroneously calling `ddi_dma_nextcookie()` we believe
we should panic the system if we detect such a programming error.
Unfortunately, if a driver mistakenly calls this and programs a device
with that cookie, the end result is almost certainly arbitrary data
corruption.

## Summary of Changes

This summarizes the changes that we're proposing to make to the system:

* Deprecate `ddi_dma_nextcookie()`
* Introduce four new functions: `ddi_dma_cookie_iter()`,
 `ddi_dma_cookie_get()`, `ddi_dma_cookie_one()`, and
 `ddi_dma_ncookies()`.
* Allow `ddi_dma_addr_bind_handle()`, `ddi_dma_buf_bind_handle()`, and
`ddi_dma_getwin()`, to receive NULL arguments for the cookie-related
pointers.
* Add additional checking around the correctness of
`ddi_dma_nextcookie()`.

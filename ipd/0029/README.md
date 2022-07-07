---
author: Garrett D'Amore
sponsor:
state: draft
---

# Sunset Sockets Direct Protocol

## Introduction

Sockets Direct Protocol was created as a high performance
stream transport (SOCK_STREAM) on top of RDMA, and in particular
Infiniband.

In illumos, a closed source module exists for it (sdpib), which
makes use of various non-public APIs.

Sockets Direct Protocol is also now deprecated (for about ten years or so).

The author is unaware of any use of SDP in illumos.
It's not even clear that IB is getting (or has ever gotten)  any use in illumos.
The only IB cards we have driver support for are now also quite obsolescent.
(We are not proposing to remove such drivers in this case, although
it's reasonable that a future IPD might propose such.)

## Description

We propose to simply remove the closed source sdpib strmod module.

This potentially also will make it easier to clean up other
interfaces that module may be using, at some future date.

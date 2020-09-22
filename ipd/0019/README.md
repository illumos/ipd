# illumos-HAS-ME
Illumos HA framework: HAS-ME (High Available Shared-Memory Entanglement)...

My original posting (slightly modified) on the illumos.org developer forum was:

“…true clustering capability with what I have defined as HAS-ME (High-Available Shared-Memory Entanglement), whereby live real-time replication of zcage configured zones that are non-global, branded (LX with/without Docker), and VM encapsulated zones hosting KVM and/or Bhyve, are mirrored across the memory of two or more servers, whereby in-memory application state information is not lost upon node failure, similar to OpenBSD’s pfsync clustering mechanism for connection state and FreeBSD's HAST (but in memory instead of block-device).”

	
My proposed solution with HAS-ME (High-Available Shared-Memory Entanglement), on Illumos and associated distributions, is not limited to just live migration BUT more so to mirrored (redundant) live parallel execution with logically isolated execution environments in the form of zones, including LX zones for Linux, as well as Docker images, and zones for KVM and Bhyve, whilst also being fully synchronous for guaranteed data integrity, which could create a performance hit in contrast to a less-reliable asynchronous solution, but that is depending on how to share zone state information across multiple nodes that have a high-bandwidth/low-latency interconnect.


The following is a statement from the illumos.org developer forum:

“With applications such as Postgres having High Availability was easier to build into the database rather than the OS.”

The answer to this is that my clustering idea is a proposal that will provide true HA to applications not written with HA in mind. I can think of an example regarding this, e.g. using SSH to create an encrypted transport for unencrypted network applications. The application is unaware of this, but rather than develop encrypted transport into each network application, having a generic solution as a standard, e.g. tunnelling over SSH, that fits all networking applications without encrypted transport being better and more trusted! Real-time HAS-ME (High Available Shared-Memory Entanglement) on Illumos has the advantage to make any application process/es running in a non-local/branded/VM zone, without HA implementation as part of the application, to achieve HA functionality within a purpose-built Illumos HA zone framework that is suited to almost any application that can run in any type of zone.
	
Another point to refer to from the illumos.org developer forum is:

“Additionally to memory one also needs to sync the storage of the zone/VM or have shared storage.”

A FreeBSD HAST (High Available Storage) port to Illumos could do this, but it lacks functionality regarding multi-homed storage and is only supported for 2-nodes without I/O fencing mechanisms via reservations and cluster membership vote counts via a Quorum device/server, therefore leading to a potential split-brain scenario! It would be good if a port was made, along with support for multi-homed stretched clusters up to at least 4-nodes (2-local and 2-remote). However, RAID-1 over TCP/IP (how HAST has been originally conceived) could provide the basis for a stretched cluster for HA ZFS iSCSI JBOD solutions between sites without a high-bandwidth/low-latency interconnect to provide a multi-site multi-homed storage solution. With reference to this project please refer to:

- https://github.com/stacepellegrino/illumos/tree/master/HAST/hastd
- https://github.com/stacepellegrino/illumos/tree/master/HAST/hastctl

The respective HAST README is in the parent directory... https://github.com/stacepellegrino/illumos/tree/master/HAST

From the illumos.org developer forum is the following:

“If you have shared storage rebooting a VM was short enough to remove the need for this feature thus far … the cloud-native trend and load balancers have proven better solutions for all use cases I have come across.”

The response to this is that cloud-related horizontally scaling service infrastructure has resilience built-in and is fine for a vast majority of scenarios. However, I have come to devise the solution of HAS-ME (High-Available Shared-Memory Entanglement) because of the need for High Available desktops on thin-clients. Originally the idea was for Sun Ray Software running in a zone, with the X sessions truly mirrored across more than two Sun Ray servers. This is a definite use-case for HAS-ME (High-Available Shared-Memory Entanglement)! However, Oracle only sustains Sun Ray Software for support contracts BUT has superseded this with Secure Global Desktop (SGD), which can be hosted privately in-house. Therefore, Oracle's SGD definitely has a use-case for HAS-ME (High-Available Shared-Memory Entanglement)!


A conclusion from one active member (Till Wegmüller) on the illumos.org developer forum is:

“That said I do think that having it would be interesting even if only for live migration of VM's/Zones for maintenance. We have work for live migration on KVM actually.”


Another member’s follow-up (Joshua M. Clulow) published on the illumos.org developer forum is as follows:

“I have spent some time looking at live migration of UNIX processes in the past, and I have to say I think it's a bit of a dead end. The challenge is that the interface surface area provided to a UNIX process is effectively unbounded, and for migration to work, one would need to be able to serialise and deserialise the state of all observable system objects.”

The response to this was follows…

Regarding HAS-ME (High Available Shared-Memory Entanglement) there is the option (up for consideration) to serialise/deserialise object state into files on a shared file system as a rendezvous, although this would have a significant performance impact by enforcing an indirect reading/writing of a block-device (serialising to a file) mapped to physical memory (deserialising from a file) on a different server.

 
A member (Joshua M. Clulow) from the illumos.org developer forum continues to state some important issues to consider:

“This includes, but is not limited to, preserving process IDs, file handles, open network connections, any additional subsystems like event ports, epoll, inotify, DTrace, drivers for USB devices consumed by processes, etc. As new facilities are added to the kernel (and they may not all be added inside the core OS repository, as we provide a stable API and ABI for kernel modules) they would all need to be built in such a way that you could suspend their operation, serialise their state, and then unfurl a new copy of that state on the remote system while maintaining the relationships between all of the interdependent pieces.

In addition, many identifiers in UNIX systems are like process ID; effectively just an integer, able to be stored in memory without any particular tagging or metadata.  They can also be constructed without consulting the system, in contrast to richer systems of capabilities where that is often not true. This means that once you give a PID to a process, you cannot really change it.”

The response is as follows:

This is not exactly true in context with zone initialisation… (see further on in this document)… “…what has not been completed is the process initialisation of the users structure, whereby the first thing the new zsched process does is finish that initialisation along with reparenting itself to a PID of 1 (which is reserved for the global zone's init process).”


A further quote for consideration from (Joshua M. Clulow) on the illumos.org developer forum is:
 
“This further requires that when migrating a family of related processes, the PIDs must remain invariant through the migration; if there is any conflict with existing PIDs on the target system, all bets are off.  Zones today do not provide their own PID namespace, and not without good reason; management tools in the global zone benefit from non-overlapping PIDs inside non-global zones. Migrating even an entire zone would require some chicanery with at least PIDs, if not also other identifiers like session IDs, process group IDs, etc.”

This was then responded to as follows:

Non-global zones typically have their own file systems, process namespace, security boundaries, and network addresses, with the exception of certain privilege limitations and a reduced object namespace, therefore applications within a non-global zone can run unmodified. However, the Illumos HA framework HAS-ME (High Available Shared-Memory Entanglement), should also protect the runtime environment for applications in whatever zone to run unmodified and unaware of the application cluster.


Some further issues highlighted by a forum member are:

“This is all to say that migration of UNIX processes between systems without observable interruption is itself complicated, but would also complicate every layer of the implementation of the operating system and all future work.  Lockstep redundant execution with another node would be even more challenging to effect, as in addition to all of the above, you would need to ensure any timing effects or deliberate randomness (e.g. a CSPRNG) come to the same conclusions on both nodes.  Even if this could be done, I suspect the performance would leave the barn doors firmly attached.”

The following response is a potential solution for a well-considered issue:

Perhaps deliberate randomness, when accessed within a non-global zone, could be modified in such a way to use a meta-random pseudo-driver sampling each server’s underlying random drivers across two or more global zones accessing separate entropy pools. The meta-random pseudo-driver could then hash into the two or more different results together, therefore providing the final unified output. This is an initial thought and one that needs further consideration.


Additional thought from the forum is:

“In contrast to migrating UNIX processes, migrating a hypervisor guest is substantially less complicated.  The interface between the guest operating system and the host is substantially more constrained: an emulated CPU and memory, and a limited set of emulated devices. It requires additional maintenance and specific architectural choices there, too, but far less than migration at the UNIX process level.”

In response to the virtualisation points made:

There is consideration for HAS-ME to be done at a branded and non-global zone level, ultimately to include nested virtualisation, e.g. LX zones (with/without Docker) and VM zones (Bhyve/KVM).

As quoted later (see further on in this document) … “A design to consider for HAS-ME, is that non-global zones can provide isolation that has almost arbitrary granularity. A zone does not require a dedicated CPU, physical device, or segments of physical memory, in that it is to a degree platform independent, whereby those resources can either be multiplexed across a number of zones running within a single domain or system. Could the platform independent resources quite easily by multiplexed to a non-global zone across a remote system’s global zone?”

Some other quotes regarding virtualisation on the developer forum include:

“We're working on integrating the Bhyve hypervisor into illumos-gate right now, and I expect at some stage it will be capable of some model of live migration of guests between servers.”

…and…

“With respect to lockstep execution: because the hypervisor can control everything that the guest "sees", including any potential source of timing information or randomness, I believe you could extend bhyve to support a lockstep redundant execution between hosts in the manner you suggest.  Existing proprietary systems like VMware vLockstep at least purport to be able to do this today.”

With respect to the quotes on virtualisation, the core functionality of HAM-SE has, to some extent, already been accomplished under the guise of VMware vLockstep. Therefore, it could be done as an Illumos implementation, at the non-global/branded/VM encapsulated layer of zones, which I am now going to call descriptively as zLockstep (the “z” being zone).

Furthermore, as pointed out to me by a former Sun Microsystems engineer (Andrew Gabriel), there is an OpenSolaris technology related to the Illumos HA framework proposed in the form of implementation for HAS-ME (High Available Shared-Memory Entanglement), which is "Remote Direct Memory Access" (RDMA). This is just the solution that can be potentially referenced and used for the Illumos HAS-ME implementation. However, the known problem with this is the target node is not notified of the completion of the request (single-sided communications).

Here are some references to RDMA (for further reading in context with HAS-ME)...

- https://en.wikipedia.org/wiki/Remote_direct_memory_access
- https://en.wikipedia.org/wiki/RDMA_over_Converged_Ethernet


I would be interested to read anyone's thoughts/comments in relation to this!


Inspired by Joshua M. Clulow's comprehensive and well thought out post on the illumos.org developer forum, it is given the number of potential issues needing to be addressed, e.g. issues with PIDs just to start with.


In follow-up to the previous forum postings the decision has been made to give a heads up on OpenSolaris regarding processes and zones (the main areas of focus needed to have a successful development of the proposed solution).

Firstly, as stated, there are two significant topics regarding High Available Shared Memory (HASM) for Illumos and associated distributions, e.g. OmniOSce/SmartOS. The following part of this README is a highlight on more in-depth understanding of one of the most basic and fundamental abstractions provided by an OS (Operating System), an executable object known as a process.

Simply, a process and associated components necessary for execution include occupying pages of physical memory with specific memory segments defined as instructions (text), stack space, and data space. The OpenSolaris kernel framework allows for the creation, execution, control, monitoring, and termination of processes. OpenSolaris extends the process model by integrating support for multithreading, whereby multiple threads that can be independently scheduled and executed. The OpenSolaris kernel maintains a system-wide process table, detailing each process with a unique identifier maintained in the kernel, which is a positive integer called the Process ID (PID). 

Multi-threaded execution from the kernel, and user processes, is integrated into the core of the kernel. Tasks specifically performed by the OS are executed as kernel threads. For a process that is multithreaded, there are user threads. A kernel object that allows user threads to execute and enter the kernel independently of other threads in the same process are created with a lightweight process (LWP). The reason why user threads in processes must be linked to a kernel thread for execution is that the scheduling and execution are performed by a kernel thread. More detail on processes and associated threads are as follows:

- A process is an execution environmental state container for execution threads... proc_t ... uts/common/sys/proc.h
- A user thread is a user-created unit of execution within a process ... ulwp_t ... lib/libc/inc/thr_uberdata.h
- Lightweight process (LWP) An object that provides kernel state for a user thread...  klwp_t ... uts/common/sys/klwp.h
- The kernel thread is fundamental in scheduling and execution in the kernel... kthread_t ...  uts/common/sys/thread.h

As defined in /usr/src/uts/common/sys/proc.h, a process is represented to the kernel as a data structure, which reveals a significant number of proc_t structure members required in order to work as well as it does.
	

The following is a description of components for a process in OpenSolaris, which are shared by all the threads in a multithreaded process:

- Address space. The virtual and physical memory comprised of various memory segments, which can be defined as the text segment (the memory pages containing instructions streamed when the process executes and is runnable), the stack segment defines memory space for the process stack (each thread has its own stack), and the data segment containing data that has predetermined initialisation, and finally a heap segment, which defines the memory pages for data yet to be initialised.
- Credentials. The binding of user, group, and set of privileges a process has. The credentials define the effective and real user identification (UID), group identification (GID), the list of privileges for the process, and project and zone information.
- Process links. In addition to the process table, a process resides on several linked lists in the kernel. There are links for the family tree of a process, defined as a parent, child, sibling or orphan, and processes within the same process group, providing a mechanism for the kernel to take action on groups of processes, typically in signal delivery as it relates to job control and terminal control functions.
- CPU utilization. The tracking of time in associated fields regarding execution in both user and kernel mode, including the cumulative time spent by all the child processes.
- Signals. Fields set for signalling, e.g. pending signals, signals to ignore, queued signals.
- Threads. Tracking the number of a process’s LWPs, including LWP states, and a linked list of all the kernel threads in the process with various fields.
- Microstate accounting. Resource usage and microstate tracking for the process, including all the threads in the case of a multithreaded process.
- User area. A historic UNIX abstraction, the user area (uarea), maintains a variety of information, e.g. the executable name and argument list, and links to the process open file list.
- Procfs. Support for integration with the process file system.
- Resource management. Support for resource controls, projects, tasks, and resource pools.


The multithreaded process model made in OpenSolaris with the Process Model Unification project, integrated the threads library (libthread.so) into the standard C library (libc.so), creating a single process model for all processes in OpenSolaris. The complexity of maintaining and debugging threaded applications is now easier with the latest model due to the fact it is less complex.

All processes originate on a block-storage device, e.g. disk,  as an executable file and the process image defines what a process is like when it is loaded in memory in preparation for execution. A process is a compiled and linked text file written in a computer programming language. The compilation output is an executable file, which becomes a process through the invocation of the exec system call, which is typically proceeded by a call to fork, which creates a new proc_t for the process, and exec replaces the process image to the calling process with a new process image. After an executable object file is executed, the runtime linker, ld.so.1, is invoked to manage linking to other shared objects required for execution, typically a shared object library such as libc.so. This sequence of events is known as dynamic linking, whereby references in the program to shared object library functions are resolved at runtime by ld.so.1.

However, there is not one, but two linkers involved in the creation and execution of a process. There is ld, which is commonly referred to as the link editor; and ld .so.1, which is the runtime linker. ld is the link editor that executes as part of the compilation process. Specifically, it is called from the language-specific compiler and is the last phase of the compilation process. ld ultimately generates the executable file. ld can be executed as a standalone program for linking previously compiled object files to create an executable. The runtime linker ld.so.1, is invoked by the exec system call when a new process image is loaded. 

Executable object files are generated in compliance with the industry-standard Executable and Linking Format (ELF). ELF is part of the UNIX System V Application Binary Interface (ABI), which defines an operating system interface for compiled, executable programs.


Following on from the previous topic on process management in order to further related understanding, the next significant topic regarding High Availability Shared-Memory Entanglement (HAS-ME) for Illumos and associated distributions, e.g. OmniOSce/SmartOS, is a fundamental understanding of virtualisation with zones, including LX branded (Linux zones with/without Docker), KVM zones and Bhyve zones, with the goal of implementing live parallel execution of zones in local/remote memory across two or more servers.

The main ambition with HAS-ME is to provide Illumos with an extreme fault-tolerant approach and facility, a new paradigm for program execution, whereby applications run ** UNMODIFIED ** in order to be configured to a truly HA system.

NOTE: There should be no changes required at the application level in order to install and run the software within a HAS-ME orchestrated zone cluster.


A zone provides a virtual mapping from the application to the platform resources. Zones permit application components to be isolated from one another even though the zones share a single instance of the kernel.

Here is a brief summary of understanding zones better:

- The global zone sees all physical resources and provides common access to these resources to non-global zones.
- Non-global zones have their own file systems, process namespace, security boundaries, and network addresses.
- There is no way to break into one non-global zone from a neighbouring non-global zone.
- A zone is the combination of system resource controls and the boundary separation provided.
- The global zone has visibility of all resources on the system, whether these are associated with the global zone or a non-global zone.


In contrast to the development of HAS-SM (High Available Shared-Memory Entanglement), each non-global zone has a security boundary surrounding it, therefore preventing a process associated with one non-global zone from interacting with or observing processes in other non-global zones. Therefore, with HAS-ME in mind, there needs to be a communication mechanism, including process data and associated metadata, across two or more servers via a low-latency/high-bandwidth interconnect (ideally using a private network over 10-gigabit ethernet as a minimum). However, given the security boundaries of non-global zones, there should still be a facility to observe non-global zones via each global zone, whereby two or more global zones across servers will have specific indirect access to each other and associated non-global zones, yet via the associated global zone.


A zone can be in one of the following states:	

- Configured: Configuration was completed and committed.
- Incomplete: Transition state during install or uninstall operation.
- Installed: The packages have been successfully installed.
- Ready: The virtual platform has been established.
- Running: The zone booted successfully and is now running.
- Shutting down: The zone is in the process of shutting down – this is a temporary state, leading to "Down".
- Down: The zone has completed the shutdown process and is down – this is a temporary state, leading to "Installed".


Most types of zones, including "sparse zones" (in which most file system content is shared with the global zone), and "whole root zones", (in which each zone has its own copy of its operating system files), share the global zone's virtual address space. A zone can be assigned to a resource pool (processor set plus scheduling class) to guarantee certain usage or capped at a fixed compute capacity, or via fair-share scheduling can be given shares.

Zones in general provide an application execution environment in which processes are isolated. However, HAS-ME will utilise a trusted relationship with two or more server’s global zones to monitor and manage the associated non-global zones that have an entangled relationship with each other in terms of parallel execution, albeit operating with differing speeds and latency between local/remote memory accesses.

With zones, it is possible to maintain the one-application execution environment per-zone deployment model, while simultaneously and effectively sharing hardware resources, including a remote server’s memory via the local server’s global zone (please reference “Remote Direct Memory Access” in order to assess the potential integration of RDMA with the HA solution that is HAS-ME).	


A zone also provides an abstract layer that separates applications from the physical attributes of the machine on which they are deployed, therefore allowing for seamless cloning with live replication and live execution on running local/remote non-global zones. Such an abstract layer will allow for HAS-ME to encapsulate and port zone-specific observable object state information across servers to another non-global zone, although with the consideration for synchronised lockstep execution (a kind of pseudo-entanglement) of the processes contained in each of the non-global zones that are clustered.


Some further considerations to reiterate about zones are as follows:

- Zones can have established boundaries for resource consumption, such as CPU and/or memory and/or block-device storage usage. These boundaries can dynamically be expanded to adapt to the changing processing requirements of the application that runs in the zone.
- Zones can provide near-native performance because zones do not use a hypervisor.
- Applications run unmodified in a secure environment that is provided by the non-global zone. 
- All processes running in all zones are visible to the global zone.


As already mentioned, there is the possibility to dynamically adjust the assigned pool resources to a zone according to utilisation, load, and properties.

Zones and resource pools are tightly integrated so that a resource pool can be bound to a specific zone, whilst maintaining the environment as secure, manageable, flexible, and configurable to meet performance requirements and service levels for each application.

Even though zones provide a virtualised execution environment that can bind to a resource pool, it should be noted that when making scheduling decisions about threads running in a zone the dispatcher needs to honour such bindings.

To manage FSS threads running in zones there is a fsszone_t object. The kernel defines and instantiates the fsszone_t object when a zone is created and shares are allocated. There can be the ability to allocate a number of CPU shares to a zone. Even though FSS is based on shares, it should be noted that the dispatcher schedules threads based on their global priority.


A design to consider for HAS-ME is that non-global zones can provide isolation that has almost arbitrary granularity. A zone does not require a dedicated CPU, physical device, or segments of physical memory, in that it is to a degree platform-independent through abstraction, whereby those expected resources can either be multiplexed across a number of zones running within a single domain or system. With regards to this, as an afterthought, could the platform-independent resources quite easily by multiplexed to a non-global zone across a remote system’s global zone?


Each non-global zone has at least one virtual network interface with its own network identity (address, hostname, and domain). The network interface for each zone is channelled through one of the physical network interfaces on the system. The network traffic for a non-global zone is not visible to the other non-global zones on the system. Whilst a non-global zone is given access to at least one logical network interface, as already stated, applications running in distinct non-global zones cannot observe the network traffic of other non-global zones, even though their respective streams of packets travel through the same physical interface.


Appropriately privileged processes, such as HAS-ME running in multiple global zones, can access objects associated with other non-global zones. Cross-zone communication may occur over the network (which is actually looped back inside IP, as with any traffic routed between logical interfaces in the same system) but not through other mechanisms without the participation of the global zone. With the exception of certain privilege limitations and a reduced object namespace, applications within a non-global zone can run unmodified.


Privileged processes in non-global zones are prevented from performing operations that can have system-wide impact, whether that impact would have performance, security, or availability consequences.


HAS-ME would need to observe and interact with the zone runtime structures, including the zoneadmd daemon. Each zone is dynamically assigned a unique numeric zone identifier (or zoneid) when it is ready.

There is zone runtime support for managing the virtual platform and the application environment with two processes, one of which is zoneadmd, which manages most of the resources associated with the zone. Kernel resources associated with the zone are tracked by the system process zsched (like sched).

zoneadmd is the primary process responsible for zone management as a virtual platform. It is also responsible for setup and teardown of the application environment. For each active (ready, running, shutting down) zone on the system, there is one zoneadmd running. The zoneadmd command is responsible for consulting the zone configuration and then setting up the zone as directed. Calling the zone_create system call allocates a zone ID and starts the zsched.

Every active zone has zsched, an associated kernel process. Kernel threads operating the zone are owned by zsched. It exists to keep track of per-zone kernel threads for the zones subsystem.

The main virtualisation implementation of zones in the kernel can be found in the zone.c source file.

For data structures and locking strategy used for zones, there is a description of the zone states possible, monitored by the kernel, including what points a zone may transition from one state to another. The following source file comments describes the zone states of concern:

```
*
* Zone States:
*
* The states in which a zone may be in and the transitions are as
* follows:
*
* ZONE_IS_UNINITIALIZED: primordial state for a zone. The partially
* initialized zone is added to the list of active zones on the system but
* isn't accessible.
*
* ZONE_IS_READY: zsched (the kernel dummy process for a zone) is
* ready. The zone is made visible after the ZSD constructor callbacks are
* executed. A zone remains in this state until it transitions into
* the ZONE_IS_BOOTING state as a result of a call to zone_boot().
*
* ZONE_IS_BOOTING: in this shortlived-state, zsched attempts to start
* init. Should that fail, the zone proceeds to the ZONE_IS_SHUTTING_DOWN
* state.
*
* ZONE_IS_RUNNING: The zone is open for business: zsched has
* successfully started init. A zone remains in this state until
* zone_shutdown() is called.
```

See os/zone.c


States are defined in libzonecfg.h. Another process in the zone boot operation is the zoneadmd process, which runs in the global zone and performs a number of critical tasks. 

Some of the virtualization for a zone is implemented in the kernel, but zoneadmd manages most  of the infrastructure for each zone as outlined in the zoneadmd.c source file comments as follows:

```
/*
* zoneadmd manages zones; one zoneadmd process is launched for each
* non-global zone on the system. This daemon juggles four jobs:
*
* - Implement setup and teardown of the zone "virtual platform": mount and
* unmount filesystems; create and destroy network interfaces; communicate
* with devfsadmd to lay out devices for the zone; instantiate the zone
* console device; configure process runtime attributes such as resource
* controls, pool bindings, fine-grained privileges.
*
* - Launch the zone's init(1M) process.
*
* - Implement a door server; clients (like zoneadm) connect to the door
* server and request zone state changes. The kernel is also a client of
* this door server. A request to halt or reboot the zone which originates
* *inside* the zone results in a door upcall from the kernel into zoneadmd.
*
* One minor problem is that messages emitted by zoneadmd need to be passed
* back to the zoneadm process making the request. These messages need to
* be rendered in the client's locale; so, this is passed in as part of the
* request. The exception is the kernel upcall to zoneadmd, in which case
* messages are syslog'd.
*
* To make all of this work, the Makefile adds -a to xgettext to extract *all*
* strings, and an exclusion file (zoneadmd.xcl) is used to exclude those
* strings which do not need to be translated.
*
* - Act as a console server for zlogin -C processes; see comments in zcons.c
* for more information about the zone console architecture.
*
* DESIGN NOTES
*
* Restart:
* A chief design constraint of zoneadmd is that it should be restartable in
* the case that the administrator kills it off, or it suffers a fatal error,
* without the running zone being impacted; this is akin to being able to
* reboot the service processor of a server without affecting the OS instance.
*/
```

See zoneadmd.c


Booting a zone with zoneadm will attempt to contact zoneadmd via a door that is in part used to coordinate zone state changes. If zoneadmd is not running, then there will be an attempt to start it. Once ready, zoneadm interfaces with zoneadmd to boot the zone by supplying the appropriate zone_cmd_arg_t request via a door call. It is worth noting that the same door is used by zoneadmd to return messages back to the user executing zoneadm.

With reference to the door server that zoneadmd implements, is the sanity checking that takes place on the argument passed via the door call as well as the use of process privileges. Using door_ucred, the user credential can be checked to determine where the request originated from, e.g. in the global zone, also identifying the user making the request that they had sufficient privileges and whether the request was a call from the kernel. 

Transitions from one zone state to another are within the door server implemented by zoneadmd. There are two states from which a zone boot is permissible, installed and ready. From the installed state, zone ready is used to create and bring up a virtual platform for the zone that consists of the zone's kernel context (created using zone_create), including a specific file system for the zone (especially the root file system) and logical networking interfaces. The state transition also takes place as part of a zone that is supposed to be bound to a non-default resource pool.

When using zone_create a kernel context of the zone is created, and a zone_t structure is allocated and initialised. The status of the zone is set to ZONE_IS_UNINITIALIZED at this time. Setting up the security boundary which isolates processes running inside a zone takes place during the initialisation of a zone. zone_create adds the zone to a doubly-linked list and two hash tables, one hashed by zone name and the other by zone ID. These data structures are protected by the zonehash_lock mutex, which after the zone has been added is then released.

zsched is then created as a new kernel process, which is where kernel threads for this zone are parented. To create this kernel process after calling newproc, then zone_create will wait using zone_status_wait until the zsched kernel process has completed initialising the zone and has set its status to ZONE_IS_READY. What has not been completed is the process initialisation of the user structure, whereby the first thing the new zsched process does is finish that initialisation along with reparenting itself to a PID of 1 (which is reserved for the global zone's init process).

Acquiring the zone_status_lock mutex in order to set the zone status to ZONE_IS_READY, there will be a suspension of zsched whilst waiting for the zone's status to been changed to ZONE_IS_BOOTING. Once the zone is in the ready state, zoneadmd reclaims control from zone_create and the door server continues the boot process by calling zone_bootup.

At this point, zone_boot saves the requested boot arguments after securing the zonehash_lock mutex and then a further acquisition of the zone_status_lock mutex is made in order to set the zone status to ZONE_IS_BOOTING. After releasing both locks, it is zone_boot that becomes suspended, whilst waiting for the zone status is be set to ZONE_IS_RUNNING. Now the zone's status is set to ZONE_IS_BOOTING, zsched continues where it previously left off after suspension of itself with a call to zone_status_wait_cpr. It checks the zone status to show ZONE_IS_BOOTING, followed by a new kernel process called zone_icode, created in order to run init in the zone of concern, whereby the traditional icode function is used in order to start init in the global zone and similar UNIX/UNIX-like environments, therefore analogous to calling zone_icode, although specifically for a non-global zone. Some final zone-specific initialisation is done before the function call for exec_init to actually exec the init process. If the exec is successful, zone_icode will set the zone's status to ZONE_IS_RUNNING, where zone_boot will pick up from where it too had been suspended. At this point, the value of zone_boot_err indicates whether the zone boot was successful or not and is used to set the global errno value for zoneadmd. NOTE: With zone transitioning to the running state, a call is made to audit_put_record to generate an event for the OpenSolaris auditing system so that knowledge of which user executed the command to boot a zone can be identified. In addition, there is an internal zoneadmd event generated to indicate on the zone's console device that the zone is booting. For all state transitions, this internal stream of events is sent by the door server to the zone console subsystem, so that the console shows which state the zone is transitioning to.


Regarding zone privileges there is use of the cred_t structure in the kernel being an integral part of each zone. The cr_zone field points to the zone structure associated with the credential. Inherited by the credentials used by all descendent processes within the zone sets this field for any process entering a zone. The cr_zone field is analysed for checking the privilege using credential information, such as priv_policy, drv_priv, and hasprocperm. Without directly dereferencing the cred_t structure the kernel interface crgetzoneid can access the zone ID.


See the privileges man page for the full descriptions of the following:

SAFE PRIVILEGES ALLOWED WITHIN A ZONE

```
PRIV_FILE_CHOWN Allows process to change file ownership.
PRIV_FILE_CHOWN_SELF Allows process to give away files it owns.
PRIV_FILE_DAC_EXECUTE Allows process to override execute permissions.
PRIV_FILE_DAC_READ Allows process to override read permissions.
PRIV_FILE_DAC_SEARCH Allows process to override directory search permissions.
PRIV_FILE_DAC_WRITE Allows process to override write permissions.
PRIV_FILE_LINK_ANY Allows process to create hard links to files owned by someone else [basic].
PRIV_FILE_OWNER Allows nonowning process to modify file in various ways.
PRIV_FILE_SETDAC Allows nonowning process to modify permissions.
PRIV_FILE_SETID Allows process to set setuid/setgid bits.
PRIV_IPC_DAC_READ Allows process to override read permissions for System V IPC.
PRIV_IPC_DAC_WRITE Allows process to override write permissions for System V IPC.
PRIV_IPC_OWNER Allows process to control System V IPC objects.
PRIV_NET_ICMPACCESS Allows process to create an IPPROTO_ICMP or IPPROTO_ICMP6 socket.
PRIV_NET_PRIVADDR Allows process to bind to privileged port.
PRIV_PROC_AUDIT Allows process to generate audit records.
PRIV_PROC_CHROOT Allows process to change root directory.
PRIV_PROC_EXEC Allows process to exec [basic].
PRIV_PROC_FORK Allows process to fork [basic].
PRIV_PROC_OWNER Allows process to control/signal other processes with different effective uids.
PRIV_PROC_SESSION Allows process to send signals outside of session [basic].
PRIV_PROC_SETID Allows process to set its uids.
PRIV_PROC_TASKID Allows process to enter a new task.
PRIV_SYS_ACCT Allows process to configure accounting.
PRIV_SYS_ADMIN Allows the process to set the domain and node names and coreadm and nscd settings.
PRIV_SYS_MOUNT Allows process to mount and unmount file systems.
PRIV_SYS_NFS Allows process to perform operations needed for NFS.
PRIV_SYS_RESOURCE Allows process to configure privileged resource controls. Privileged per-zone resource controls cannot be modified from within a non-global zone even with this privilege.
```

UNSAFE PRIVILEGES RESTRICTED TO THE GLOBAL ZONE

```
PRIV_NET_RAWACCESS Allows a process to have direct access to the network layer.
PRIV_PROC_CLOCK_HIGHRES Allows process to create high-resolution timers.
PRIV_PROC_LOCK_MEMORY Allows process to lock pages in physical memory.
PRIV_PROC_PRIOCNTL Allows process to change scheduling priority or class.
PRIV_PROC_ZONE Allows process to control/signal other processes in different zones.
PRIV_SYS_AUDIT Allows process to manage auditing.
PRIV_SYS_CONFIG Allows a variety of operations related to the hardware platform.
PRIV_SYS_DEVICES Allows process to create device nodes.
PRIV_SYS_IPC_CONFIG Allows process to increase size of System V IPC message queue buffer.
PRIV_SYS_LINKDIR Allows process to create hard links to directories.
PRIV_SYS_NET_CONFIG Allows process to configure network interfaces.
PRIV_SYS_RES_CONFIG Allows process to configure system resources.
PRIV_SYS_SUSER_COMPAT Allows process to successfully call third-party kernel modules that use suser().
PRIV_SYS_TIME Allows process to set system time.
```


Restricted privileges within a zone are enabled with the zone_create system call and an argument to determine the zone's privilege limit. For all processes entering the zone, including the process that initiates booting the zone, the set of privileges used are as a mask. A zone does not eliminate the need for restrictions on the objects accessed with the limit on the privileges available to the zone. A process can perform a given operation in accordance with privileges, whereby if the operation is allowed; the objects to which that operation can be applied are not restricted.


This also extends to visibility; processes within a non-global zone should not even be able to see processes outside that zone. This is enforced by restricting the process ID space exposed through /proc accesses, whilst using a deterministic algorithm for assigning process IDs, and process-specific system calls.


procfs exports files including data about the zone with which each associated process. A zone ID is added to the pstatus and psinfo structures, which are made available by reading the corresponding files in procfs. The zone ID replaces a pad field in each structure, so it will not affect binary compatibility, allowing processes in the global zone to determine the zone associations of processes they are observing or controlling.


The following is a psinfo structure (NOTE: the inclusion of “zone id” at the end of structure):

```
typedef struct psinfo {
         int pr_nlwp; /* number of active lwps in the process */
         pid_t pr_pid; /* unique process id */
         pid_t pr_ppid; /* process id of parent */
         pid_t pr_pgid; /* pid of process group leader */
         pid_t pr_sid; /* session id */
         uid_t pr_uid; /* real user id */
         uid_t pr_euid; /* effective user id */
         gid_t pr_gid; /* real group id */
         gid_t pr_egid; /* effective group id */
         uintptr_t pr_addr; /* address of process */
         dev_t pr_ttydev; /* controlling tty device (or PRNODEV) */
         timestruc_t pr_start; /* process start time, from the epoch */
         char pr_fname[PRFNSZ]; /* name of execed file */
         char pr_psargs[PRARGSZ]; /* initial characters of arg list */
         int pr_argc; /* initial argument count */
         uintptr_t pr_argv; /* address of initial argument vector */
         uintptr_t pr_envp; /* address of initial environment vector */
         char pr_dmodel; /* data model of the process */
         taskid_t pr_taskid; /* task id */
         projid_t pr_projid; /* project id */
         poolid_t pr_poolid; /* pool id */
         zoneid_t pr_zoneid; /* zone id */
} psinfo_t;
```

Networking between the zones must partition the IP stack in much the same way it would have been partitioned between separate servers. Zones can all communicate with one another just as though they were still linked by a network, but they also all have separate bindings, therefore each zone can run their own daemons, listening on the same port numbers, without any conflict. IP addresses for which incoming connections are destined have the conflicts resolved in the IP stack. Therefore, each zone can have a separate set of binds (mainly used for listening), whereby each zone can run with an application listening on the same port number across zones without binds failing. This is achieved by binding to the loop-back address being partitioned within a zone as a result of each zone having its own loopback interface. An exception to this is the case when bindings are established through the pseudo loopback interface in which a stream in one non-global zone attempts to access the IP address of an interface in another non-global zone.


Providing a zoned device environment is feasible for the great majority of applications that interact directly only with pseudo-devices, whereby the goals for providing devices in a zone include security, virtualisation, administration and automated operation.

With respect to zones is the treatment of devices divided into the following categories:

1. Unsafe. Devices that cannot be safely used within a zone;
2. Fully virtual. Devices that reference no global state and may safely appear in any zone;
3. Sharable-virtual. Devices that reference global state, but may safely be shared across zones;
4. Exclusive. Devices that can be safely assigned to and used exclusively by a single zone.


There is no way to allow use of the following devices from a non-global zone without violating the security principles of zones. Examples of unsafe devices include those devices that expose the global system state as follows:

- /dev/kmem
- /dev/cpc
- /dev/trapstat
- /dev/lockstat


A system’s pseudo-devices are fully virtualised, which are device instances that reference no global system state and may safely appear in any non-global zone. This includes /dev/tty, which references the context it executes as the only controlling terminal of the process. Further examples of fully virtual devices include /dev/null and /dev/zero. Also, /dev/poll and /dev/logindmux, used to link two streams in support of applications.

Device instances that reference in part some sort of global state but may be modified to be zone-compatible are said to be sharable virtual devices, e.g. as follows:

- /dev/kstat
- /dev/ptmx


The driver which exports the /dev/random and /dev/urandom minor nodes has access to the global state via the kernel's entropy pool, from which it provides a cryptographic-quality random bytes stream.


Local inter-process communication (IPC) represents a particular problem for zones, since processes in different non-global zones should normally only be able to communicate through network APIs, as would be the case with processes running on separate machines. It might be possible for a process in the global zone to construct a way for processes in other zones to communicate, but this should not be possible without the participation of the global zone. 

Pipes, streams, and UNIX domain sockets are IPC mechanisms that use the file system as a rendezvous and will not have access to file system locations associated with other zones. Since the file system hierarchy is partitioned, there is no way to achieve the rendezvous without the involvement of the global zone (which has access to the entire hierarchy). The getpeerucred interface can determine the credentials (including zone ID) of processes in different zones, therefore enabling communication between them. The use of a file system as a rendezvous is also possible with doors, providing a way of safely supporting cross-zone communication since the server can retrieve the credentials of the caller by using door_ucred, which returns a private data structure that includes a zone ID. A server could check whether the caller is authorised to perform a given operation based on its zone ID as well as other credential information. Authenticated cross-zone communication with doors is another approach to consider regarding the implementation detail of HAS-ME, whereby there is the option (up for consideration) to serialise/deserialise object state into files on a shared file system as a rendezvous, although this would have a significant performance impact by enforcing an indirect reading/writing of a block-device (serialising to a file) mapped to physical pages in memory (deserialising from a file) on a different server.

Regarding performance, zones isolate applications in terms of configuration, namespace, security, and administration, but there is a need for each application to receive an appropriate allocation of the overall system resources.

The zones facility is tightly integrated with existing resource management controls ensuring a minimum level of service or imposing limits. A mechanism called resource pools supports resource partitioning, which allows an administrator to specify a collection of resources that will be exclusively used by some set of processes. A zone can be "bound" to a resource pool, which means that the zone runs only on the resources associated with the pool. 

Since all zones on a system are part of the same kernel instance, processes in different zones can actually share virtual memory pages. This is particularly true for text pages, e.g. the init process in each zone can share a single copy of the text for the executable, libraries, etc. resulting in substantial memory savings for commonly used executables and libraries such as libc. To further minimise overheads, other parts of the operating system infrastructure can also be shared among zones.


The kernel, and also user processes, use allocated virtual memory constructed of address space segments, translating the virtual memory addressing into physical pages via the Memory Management Unit (MMU). Most of the kernel's memory is non-pageable, therefore making it persistently immutable. The reason is that the kernel requires its memory to complete fundamental system tasks that could affect other memory-related data structures, whereby if the kernel had to take a page fault while performing a memory management task, including any other task affecting pages of memory, it could cause deadlock to occur. However, some deadlock-safe parts of the kernel can be allocated from pageable memory, which is used mostly for the lightweight process thread stacks.	

Kernel memory consists of a variety of mappings from physical memory pages to the virtual address space of the kernel, whereby memory is allocated by a layered series of kernel memory allocators. The creation and management of the majority of kernel mappings are handled by two segment drivers. The segkmem kernel segment driver maps non-pageable kernel memory and pageable kernel memory is mapped with the segkp segment driver.

Virtual memory data structures required for the platform's HAT (Hardware Address Translation) implementation is kept in a portion of the kernel data segment and a separate memory segment. The virtual memory data structures include page tables and page structures allocated in the kernel data-segment large page.

Memory access in the kernel acquires a section of the virtual address space of the kernel, then mapping physical pages to that address. By calling from the page allocator page_create_va() the physical pages are acquired one at a time, whereby there is a need to map them into the address space in order to use the pages of concern. For general-purpose mappings, a section of the address space for the kernel, known as the kernel heap, is set aside. The kernel heap is a separate kernel memory segment containing a large area of virtual address space that is available to consumers of the kernel that require virtual address space for their mappings.

A record of information is kept about which parts of the kernel map are free and which parts are allocated in order to satisfy new requests each time a consumer of the kernel uses a piece of the kernel heap. To record the information, a general-purpose allocator known as vmem is used to keep track of the start and length of the mappings that are allocated from the kernel map area. The allocator is used extensively for managing the kernel heap virtual address space, but since vmem is a universal resource allocator, it is further used for managing other resources such as task, resource, and zone IDs.


-Stacey Pellegrino (stacey.pellegrino@gmail.com)

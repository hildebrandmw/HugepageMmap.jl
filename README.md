# HugepageMmap

Support for memory mapping files on Linux-based systems with support for hugepages.

## Huge Pages

Modern computer systems use virtual memory to create the illusion that each program is running in its own address space.
With the help of the operating system (OS) and underlying hardware, address translation tables are created for each process.
These translation tables convert the memory address used by the process (the "virtual" address) into a real "physical" address of where the memory actually resides on the hardware.

Addresses are grouped into blocks, or "pages", to help this translation procedure.
By default, the size of a page is 4 kB.
Each time a process accesses a virtual memory address, the hardware/OS combination determines which page the addresses is on, and then looks up the physical address in a page table.
Since this has to be done for each address reference, CPUs have a structure called a Translation Lookaside-Buffer (TLB) that caches recently used virtual to physical page translations.
This greatly speeds up the translation process.

Now, there is a trade off to be made for pages sizes.
Larger pages mean that fewer TLB entries are required to cover a given address space.
Since the TLB entries (i.e. virtual to physical address mappings) are also stored in memory, larger page sizes can reduce time spent waiting to fill TLB misses.

However, larger page sizes also affect the granularity of memory allocations.
If, for example, 1 GB page sizes are used, this means that the minimum allocation size (ignoring library support for managing objects within a single page) is 1 GB.
This is extremely wasteful for allocating a lot of small objects.

The default page size that people have settled on is 4 KB, which strikes a balance between allocation size and TLB efficiency.
However, some applications, such as benchmarking memory performance by randomly accessing an array, require larger page sizes to avoid TLB overhead.

That's where hugepages come into play.
Linux based operating systems support two sizes of huge pages: `2 MB` and `1 GB`.

## Allocating Huge Pages

Allocating huge pages is pretty simple.
If you are using a server system with multiple NUMA domains, use the following command

```sh
sudo numactl --cpunodebind=1 --membind=1 hugeadm --obey-mempolicy --pool-pages-min=1G:64
sudo hugeadm --create-mounts
```
Lets break this down:

    - `hugeadm`: hugepage administration tool.
        - `--obey-mempolicy`: If running under `numactl` to control NUMA domains, this flag forces `hugeadm` to obey its current NUMA policy.
        Huge pages are allocated per NUMA node, so it's important to make sure this is correct for your workload.

        - `--pool-pages-min=1G:64`: Minimum number of pages to allocate.
        Here, we are allocating 64 `1 GB` huge pages.
        We can also allocate `2 MB` huge pages by using `2M` instead of `1G`.

    - `numactl`: Select which NUMA domain to allocate on
        - `--cpunodebind=1`: Allocate to NUMA node 1
        - `--membind=1`: Allocate to NUMA node 1

    - `sudo`: We're messing with OS level stuff. We need superuser privileges.

**NOTE**: It's best to allocate huge pages early after a system reboot.
Hugepages must be made of physically contiguous memory.
If a system has been running for a while, it may be impossible for the OS to find enough free contiguous memory and the allocation will fail.

## Usage

To allocate a vector backed by 1 GB huge pages, simply run:
```julia
using HugepageMmap
A = hugepage_mmap(Int64, 1000000, PageSize1G())
```

module HugepageMmap

using Mmap

export hugepage_mmap,
       PageSize4K,
       PageSize2M,
       PageSize1G

const MAP_HUGETLB    = Cint(0x40000)
const MAP_HUGE_SHIFT = Cint(26)
const MAP_HUGE_2MB   = Cint(21 << MAP_HUGE_SHIFT)
const MAP_HUGE_1GB   = Cint(30 << MAP_HUGE_SHIFT)

abstract type AbstractPageSize end
struct PageSize4K <: AbstractPageSize end
struct PageSize2M <: AbstractPageSize end
struct PageSize1G <: AbstractPageSize end

extraflags(::PageSize4K) = Cint(0)
extraflags(::PageSize2M) = MAP_HUGETLB | MAP_HUGE_2MB
extraflags(::PageSize1G) = MAP_HUGETLB | MAP_HUGE_1GB

# Align length for `munmap` to a multiple of page size.
pagesize(::PageSize4K) = 4096
pagesize(::PageSize2M) = 2097152
pagesize(::PageSize1G) = 1073741824

align(x, p::AbstractPageSize) = ceil(Int, x / pagesize(p)) * pagesize(p)
align(x, ::PageSize4K) = x

# This is heavily based on the Mmap stdlib
"""
    hugepage_mmap(::Type{T}, len, pagesize::AbstractPageSize)

Allocate a `Vector{T}` with length `len` backed by `pagesize`.
Choices for `pagesize` are `PageSize4k()`, `PageSize2m()`, or `PageSize1G()`.
Make sure the corresponding hugepages are already allocated on your system.
"""
function hugepage_mmap(::Type{T}, len::Integer, pagesize::AbstractPageSize) where {T}
    mmaplen = sizeof(T) * len

    # Build the PROT flags - we want to be able to read and write.
    prot = Mmap.PROT_READ | Mmap.PROT_WRITE
    flags = Mmap.MAP_PRIVATE | Mmap.MAP_ANONYMOUS
    flags |= extraflags(pagesize)

    fd = Base.INVALID_OS_HANDLE
    offset = Cint(0)

    # Fordward this call into the Julia C library.
    ptr = ccall(
        :jl_mmap,
        Ptr{Cvoid},
        (Ptr{Cvoid}, Csize_t, Cint, Cint, RawFD, Int64),
        C_NULL,     # No address we really want.
        mmaplen,
        prot,
        flags,
        fd,
        offset,
    )

    # Wrap this into an Array and attach a finalizer that will unmap the underlying pointer
    # when the Array if GC'd
    A = Base.unsafe_wrap(Array, convert(Ptr{T}, UInt(ptr)), len)
    finalizer(A) do x
        systemerror(
            "munmap",
            ccall(:munmap, Cint, (Ptr{Cvoid}, Csize_t), ptr, align(mmaplen, pagesize)) != 0
        )
    end
    return A
end

end # module

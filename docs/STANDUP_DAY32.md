# Developer standup: Day 32

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

File `mmap` now uses Haiku's kernel `vm_map_file` / `_vm_map_file`
instead of `_user_map_file` + a user-stack scratch. That scratch
`#GP`'d in `user_memcpy` (LTP `uname01`).

### Why `_user_map_file` was the wrong primitive

`_user_map_file` requires `IS_USER_ADDRESS` for the name and
`void**`. We bounced those through `gs:16-256`. That is either
the red zone / live frames or a pointer `user_memcpy` `#GP`s on.
`create_area()` from a driver creates a **kernel** area
(`VMAddressSpace::KernelID()`). The kernel primitive that maps
into the **current team** is `vm_map_file(team, name, &addr, …)`.

`vm_map_file` is not in the add-on export list (guest `ld` failed).
It is a `T` symbol in `kernel_x86_64`. We resolve it at load with
`get_image_symbol`. The public wrapper passes `kernel=true`, so
`get_fd` looks at the **kernel** io context and user fds miss.
The internal `_vm_map_file(..., kernel=false)` (hrev57937
`0xffffffff8012c180`) uses the team's fds.

### Proof (guest 2026-08-16, MM3)

| Test | Result |
|---|---|
| `hello_mmapf` | `MMAPFOK` `MMAPF_RC=0` (ELF magic of `/boot/home/hello_min`) |
| `sh -c 'echo HI \| cat'` | `HI` `PIPE_RC=0` |
| LTP `uname01` | **no KDL**. `TBROK: chown(..., -1, 0) EFAULT` (old wstat scratch) |

COM1: `VMfn=0xffffffff8012c8e0` `VMKfn=0xffffffff8012c180`.

### Do not

- Call `_user_map_file` from the driver with kernel or stack
  pointers.
- Call `create_area()` from the driver and expect a user mapping.
- Call `vm_map_file` with `kernel=true` for a Linux fd.

### Next

1. `chown(path, -1, gid)` — Linux "leave uid" — still `EFAULT`
   (wstat user scratch). Unblocks the LTP tmpdir.
2. ioctl / TTY still deferred.

# Continuation / parking notes (Day 58 + 2026-08-30 mmap)

**Parked:** 2026-08-23. Pickup continued 2026-08-30 for Ailang
self-compile on the Haiku guest.

---

## 2026-08-30 — nested CAD import was a stale Librarys copy

Ailang `LibraryImport.Cad.SketchProfile.ProfIR` works on Linux as-is.
On Haiku it failed with `Unknown function: CAD_Sketch.ProfCompile`.
Do **not** change CAD or compiler sources for this.

`Import_FindLibBase` uses `/proc/self/exe` + `/Librarys`. The compiler
binary is `/boot/home/ailang.x`, so it opens **`/boot/home/Librarys`**,
not the GitHub clone.

`/boot/home/Librarys` was a curl/copy tree (owner `sshd`, dates Aug 15–18):
`Cad/SketchProfile/` had Loop/Tess/Snap only. The facade
`Library.CAD_SketchProfile.ailang` had no `ProfIR` import.
`Library.ProfIR.ailang` was missing.

The git clone at `/boot/home/Ailang-Self-Hosting-` (HEAD `feab5755`)
had the full nested tree. Serial: Loop/Tess/Snap opened from
`/boot/home/Librarys/...`; ProfIR did not exist there (`n` after open).

**Fix (GIT56):** `git reset --hard origin/master` on the clone, then
`ln -s /boot/home/Ailang-Self-Hosting-/Librarys /boot/home/Librarys`.
Guest compiled `CAD/cad_app.ailang` → `/boot/home/cad_app.x` 2540752
bytes (`results/ltp/git56_run.png`). Script:
`scripts/guest_go_git56.sh`.

Haiku R1/beta6 bump is incoming. HaikuPorts refresh already failed
(`haiku>=r1~beta6_hrev59866_5-1` vs postgresql18_server). After the
new image: keep the git clone as the Librarys source of truth; do not
curl individual library files next to `ailang.x`.

---

**License:** Public Domain / CC0 1.0 Universal
**Repo:** https://github.com/AiLang-Author/Haiku-Linux-Bridge
**Live trap:** `src/syscall_hook.S` + `src/sys_compat_dev.cpp` +
`src/sys_compat_run.c`
**Living plan:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Banner:** `PR54s` (COM1 at driver load). `MWgo` = mmap worker up.

Fork it. The license is CC0. Pull requests are welcome. Do not wait
for the original author.

---

## 2026-08-30 — Linux mmap is a VMA, not a sized arena

Do **not** change Ailang compiler sources. Host self-compile RSS is
~1.4GB. The compiler's `mmap(64MB ANON)` per import is VA; only the
file bytes are touched.

A **size cap** on those maps (PR54p–r, 8–128MB forced to 4MB) is a
hardcoded failure: import buffers were smaller than `ReadBinaryFile`
expected, names garbled, compile ended `Unknown function` (missing
import / smashed file). Cap is gone.

Do **not** pre-create a 2–48GB `linux_arena` and bump-allocate mmap
out of it. Haiku `create_area` of that size charges RAM+swap even
with `B_NO_LOCK`. That is not how Linux mmap works.

**PR54s:** each Linux `mmap(ANON)` is `create_area_etc` of the
requested size on a **kernel worker thread** (`sys_compat_mmap`).
The SYSCALL hook must not call `_user_create_area` (nested user copy
→ KDL, PR54j). Worker uses `B_STACK_AREA` +
`CREATE_AREA_DONT_COMMIT_MEMORY` so pages commit on fault (same
overcommit model as Linux). `munmap` still `vm_delete_area(team)`.
`sys_compat_run` only maps a **32MB brk window** for glibc TLS /
small `brk`. Large allocs are mmap.

COM1: `PR54s`, `MWgo`, `MA` (area ok), `CE=` (create_area_etc error),
`ME` (mmap ANON failed), `MWto` (worker timeout).

Guest rebuild: unique filenames (Haiku curl caches GET).
`scripts/guest_go_pr54s.sh` then reboot then
`scripts/guest_go_pr54s_cc.sh`.

Do not pick **Debug** on Oh no (debugger chain GPF's bash/ls/curl).
Terminate / Oh no only. Reports land on `/boot/home/Desktop/`.

---

## What this is

An out-of-tree **Linux ABI** so unmodified 64-bit Linux ELFs run on
Haiku. The add-on hijacks `SYSCALL`/`LSTAR`, marks a team by CR3, and
translates Linux numbers into `_kern_*`. No binary patching. No Linux
kernel. No Linux userspace rewrite.

Pyramid: syscall layer first, then CLI/no-GUI. ioctl/TTY/fbdev map
onto **Haiku** drivers (already done for TTY + VESA fbdev). Do not
build a Linux display stack. Do not start linuxkpi / in-situ Linux
drivers. The adapter is the product.

Kernel must stay up. Kill Thread / “Oh no!” on a marked Linux ELF is
a layer bug (or an unmarked team). **KDL or silent reboot is a
stop-the-line event.**

---

## Where it is (honest)

The guest-proven path is **static 64-bit Linux ELFs** via
`sys_compat_run`. Dynamic `ld-linux.so.2` is not a target yet.

| Token | Meaning | Day |
|---|---|---|
| `UNAME_RC=0` | LTP `uname01` | 39 |
| `SHLIVE` | interactive busybox ash | 47–48 |
| `POLLOK` / `POLLBLKOK` / `POLLSTKOK` | ELF poll | 48–54 |
| `FORKOK` | `clone`/`fork` + `wait4` | 20 |
| `CLONEEXOK` | `CLONE_VM` + child `exit`(60) | 52 |
| `CLONETLSOK` | SETTLS + PARENT_SETTID + CLEARTID | 53 |
| `CLONETHROK` | `CLONE_THREAD` `wait4` `-ECHILD` | 55 |
| `CLONEPTOK` | pthread_create **flag word** + shared pipe | 56 |
| **`CLONE3FNOK`** | `clone3` + SETTLS + trampoline `call fn(arg)` + `fs:0` magic | **58** |
| `PTHREADOK` | glibc-static `pthread_create`+join | **not yet** |

Banner on the parked trap is **`PR53g`** (COM1 at driver load).

`uname` reports `Linux haiku 6.1.0 sys_compat x86_64`. That is the
layer talking.

---

## The open hole (do this next)

glibc-static `pthread_create` uses **`clone3` (435)**, not `clone`
(56). Join is `FUTEX_WAIT_BITSET` on `ctid`.

The clone3 trampoline is **guest-green**. Isolation probe
`tests/hello_clone3fn.s` prints **`CLONE3FNOK`** `CLONE3FN_RC=0`:
same flag word `0x3d0f00`, SETTLS, child `call *%rdx` with arg in
`%rdi`, `fs:0` magic, store 42, return. That is glibc `__clone3`’s
contract without `start_thread`.

glibc `start_thread` (`hello_pthread` at `0x40bd10` on the checked-in
binary’s layout — **addresses move; use `objdump`**) is the remaining
fail. Day 58 KDL backtrace (kernel was reset after):

```
__clone3 +0x2c        0x41dd3c   return from call *%rdx
start_thread +0x2e9   0x40bff9   __lll_lock_wait_private
__libc_fatal / abort  0x405339 / 0x4013e1
raise                 0x4691de
user #PF ip=0x27      IF clear → KDL (int_bottom_user)
```

`start_thread` does:

```
cmp  byte [rdi+0x613], 0     ; stopped_start (glibc struct pthread)
je   skip
lea  rbx, [rdi+0x618]        ; lock
lock cmpxchg [rbx], 1
jne  0x40bff9                ; __lll_lock_wait_private  ← we took this
```

Child is waiting for the **parent** to unstop it after `clone3`
returns. Simple `clone3fn` never sets that flag, which is why it
passed.

**Next experiment, in order:**

1. In `sys_compat_clone_vm`, dump `*(uint8*)(tls+0x613)` and
   `*(uint32*)(tls+0x618)` before `resume_thread`. If 0x613 is 1,
   glibc meant stopped-start. If 0x618 is already nonzero, the lock
   looks held and the child will wait.
2. After `clone3` returns to the parent, glibc should futex-wake
   `pd+0x618`. Confirm COM1 `u`/`U` from the parent. If the parent
   never wakes because it is still in `clone_vm` or dies first, that
   is the race.
3. `__lll_lock_wait_private` uses futex on a TCB word in the mmap
   arena. Futex WAIT must **not** `user_memcpy` that word (GPF /
   KDL). The parked code loads with user GS (`swapgs; movl (uaddr)`).
4. `abort` → `raise(SIGABRT)` → our `kill` stub returns 0 → glibc
   then runs with IF clear at a bad RIP (`0x27` this time, `0x3c` on
   the PR53f trampoline-gettid KDL). That is how a userspace abort
   becomes KDL. Do not ignore it: either deliver something, or keep
   abort from running until `start_thread` is past the lock.

Do **not** claim `PTHREADOK` until `hello_pthread` prints `PTHREADOK`
on the guest.

---

## Dead ends this round (do not repeat)

| Attempt | Result | Lesson |
|---|---|---|
| PR53e: `childStack -= 8` after 16-align | still KT | Linux clone3 child SP is 16-aligned. glibc then `call *%rdx` (SysV: SP%16==0 at the call). SP-8 **misaligns** `start_thread`. Reverted in PR53g. |
| PR53f: trampoline `gettid` after SETTLS | **KDL** `rip=0x3c` | Child syscall used `CALL_C` / **`gSavedRsp`** while the parent was still in `clone_vm` (`CALL_GS8`). Child overwrote the parent’s saved RSP. **No syscall from the trampoline that touches `gSavedRsp` or `gKstack`.** SETTLS is in-hook (`wrmsr` + `uls`) — that is safe. |
| `user_memcpy` of TLS / stack futex words | GPF / KDL | Load/store with user GS. `linux_user_ok` is a range check, not a present-page check. |

---

## Clone3 trampoline (what actually runs)

glibc `__clone3(args, size, fn, arg)` (this tree’s `hello_pthread`):

```
mov r8, rcx          ; arg survives syscall (rcx is RIP)
mov eax, 435
syscall              ; userRip = test rax (0x41dd2d here)
test rax, rax
je child
ret
child:
xor ebp, ebp
mov rdi, r8
call rdx             ; start_thread
mov rdi, rax
mov eax, 60
syscall              ; extra-thread exit
```

The trap:

- Hook `.Lclone3` passes `fn` from `%rdx` and `arg` from `%r8` into C
  (`sCloneFn` / `sCloneArg`).
- `sys_compat_clone3` copies `linux_clone_args` (64–256 bytes),
  requires `CLONE_VM` + stack + `stack_size`, child SP =
  `stack+stack_size` **16-aligned**.
- Same-team `_user_spawn_thread` + `resume_thread`. Same CR3, already
  marked.
- Trampoline (user page `linux_tramp`): optional
  `arch_prctl(ARCH_SET_FS, tls)`, then `movabs fn,%rdx` /
  `movabs arg,%r8`, `xor eax,eax`, switch to Linux child SP, `jmp`
  userRip.
- Extra-thread `exit`(60): if `thread_count>1`, write 0 to `ctid`
  via swapgs, `FUTEX_WAKE`, `wrmsr FS_BASE=0`, `_user_exit_thread` +
  `thread_exit`. **Do not** fall through into team `_user_exit_team`
  (that unmarks CR3 and kills the parent).

`clone_vm` / `clone3` C runs on **this thread’s** `gs:8` (`CALL_GS8`),
not `gKstack`.

---

## TCB dump from the last glibc pthread clone3

Printed from kernel `user_memcpy` **before** `resume_thread`:

```
TCB0=0x…c6c0  SELF=0x…c6c0     ; self-pointer, well-formed
CAN =0xdeadbeefcafeba00        ; fs:0x28 stack_guard
LOC =0x4c89c0                  ; fs:-96 locale slot, in ELF .data
ULS =0x2b0                     ; Haiku thread->user_local_storage
FL  =0x3d0f00                  ; VM|FS|FILES|SIGHAND|THREAD|SYSVSEM|SETTLS|PARENT_SETTID|CHILD_CLEARTID
fn  =0x40bd10                  ; start_thread
```

`__ctype_init` double-derefs the locale slot; that pointer is mapped.
The first glibc-thread crash is **not** “TCB unmapped”. It is the
stopped_start lock / abort path above.

`ARCH_SET_FS` writes `[Thread+gUlsOff]` then `wrmsr FS_BASE`. COM1
`A` means it ran. `gLinuxFS` is **global** (last SET_FS). `.Lret`
must **not** re-apply it on every sysret (that KTd earlier).

---

## Lab (how this tree is actually driven)

**Image:** Haiku hrev57937 (R1/beta5), QEMU KVM, 1280×800, serial
`haiku_serial.log` (COM1 `0x3F8`), monitor `qemu_monitor.sock`, QMP
`qemu_qmp.sock`. Host HTTP `127.0.0.1:8083` → guest `10.0.2.2:8083`
(`scripts/ltp_net_server.py`). Haiku curl **caches GET bodies** —
unique filenames for rebuilds (`sys_compat_dev_pr53g.cpp`, not the
live name twice). Guest POST hangs unless `curl --max-time 8`.

```bash
./scripts/run_qemu.sh                 # host; KVM if /dev/kvm is writable
python3 scripts/ltp_net_server.py &   # 8083
python3 scripts/guest_term.py click 400 260
python3 scripts/guest_term.py type "curl -s -o /boot/home/go.sh http://10.0.2.2:8083/scripts/guest_go.sh"
```

`scripts/qemu_keys.py` has **no `$`**. Do not type shell variables.
`qemu_keys.py dump` writes a PPM; `scripts/ppm2png.py` converts.

Crash dialogs: `hey -o debug_server quit of Window "Crashed program"`.
The Oh no button is the lower-right of the box (about 815,500 at
1280×800 last time).

KDL: QEMU monitor `system_reset`. There is no Linux `reboot(1)`
mapping. `-serial file:` is output-only (no typing at `kdebug>`).

QEMU and the HTTP helper die at a **10 h** max_runtime in some
host setups. Restart them. Do not truncate `haiku_serial.log` while
QEMU holds it.

Rebuild on the guest is `make -f Makefile.driver` then
`driverinstall`, then copy the binary into
`/boot/home/config/non-packaged/add-ons/kernel/drivers/…` and
`LEAVEABI` so the next `sys_compat_run` marks a fresh team. A reboot
or `system_reset` is the clean way to unload a driver that still has
a thread in `acquire_sem`.

---

## COM1 letters (subset you will see)

Hook `KSER` writes COM1 directly (`dprintf` is silent unless
`serial_debug_output` is on).

| Letter / tag | Meaning |
|---|---|
| `PR53g` | driver banner (parked tree) |
| `C3` | `sys_compat_clone3` |
| `TV` | clone_vm rip/sp/flags |
| `SP=` `ULS=` `TCB0=` | SP after 16-align; uls offset; TCB qwords |
| `TS` | spawn tid |
| `TR` | `resume_thread` status (child often races this line) |
| `A` | `arch_prctl(ARCH_SET_FS)` |
| `t` | gettid |
| `g` `k` | getpid / kill stub — **abort()** |
| `u` `U` | futex enter / leave |
| `b` | set_robust_list |
| `W` | write |
| `x` `X` `TC` `FW` `XTX` | extra-thread exit / futex wake / thread_exit |
| `C` `T` | clone(56) / clone_vm |

Interleaved letters **inside** a hex dump (`TR0x000000A000…`) are
the child running while the parent is still printing.

---

## Landmines (the contract)

- Mark (`syscall 0x1337`) is the last Haiku action before `jmp`.
  After mark, `rdx` must be 0 (`_start` saves it as `rtld_fini`).
- Do not `CALL_C` / `gKstack` for `clone_vm` / `clone3`.
- Do not touch `gSavedRsp` from a child syscall while the parent is
  still in `CALL_GS8`.
- Do not `user_memcpy` Linux TLS / stack futex words.
- Do not unmark CR3 on extra-thread `exit`(60).
- Do not `_user_fork` for `CLONE_VM`.
- Do not `_user_wait_for_objects` from C (KDL).
- Do not `STAC` (this Haiku has no `CR4.SMAP` — `#UD` / KDL).
- Do not `FBIOPUT` under app_server. Do not DRM. Do not linuxkpi.
- Do not `echo LINUXABI > /dev/misc/sys_compat` from a Haiku
  Terminal you still want.
- Haiku syscall numbers **shift** between revisions. Confirm on the
  guest (`payload/ltp/dump_sc.c`). This image: hrev57937.
- After `swapgs`: `gs:0` = `Thread*`, `gs:8` = `syscall_rsp`,
  `gs:16` = user RSP. `uls=0x2b0` on this image (scanned at
  `dev_open`).
- `kill` / `tgkill` stub returns 0 and does **not** deliver. That
  is why `abort` can run off the end into a KDL instead of a clean
  Kill Thread.

---

## Files for the next hole

| Path | Role |
|---|---|
| `src/syscall_hook.S` | LSTAR; `CALL_GS8`; `.Lclone3`; `.Larch_prctl` `A` |
| `src/sys_compat_dev.cpp` | clone3, clone_vm trampoline, TCB dump, extra-thread exit |
| `tests/hello_clone3fn.s` | isolation: **`CLONE3FNOK`** |
| `tests/hello_pthread.c` | glibc-static create+join; expect **`PTHREADOK`** |
| `tests/hello_clonept.s` | flag word; **`CLONEPTOK`** (must stay green) |
| `scripts/guest_run_pthread.sh` | guest runner |
| `scripts/guest_run_clone3fn.sh` | guest runner for the isolation probe |
| `scripts/qemu_keys.py` | type / dump |
| `scripts/guest_term.py` | click Terminal + type |
| `scripts/ltp_net_server.py` | HTTP 8083 |

Do **not** commit: `src/sys_compat_dev_pr*.cpp`, `syscall_hook_pr*.S`,
`scripts/guest_go_clone*.sh` (HTTP cache-bust copies), payload ELFs,
`tests/hello_pthread` (the binary), screenshots, serial backups.

Build the pthread ELF on Linux:

```bash
gcc -O2 -static -pthread -o tests/hello_pthread tests/hello_pthread.c
gcc -nostdlib -static -o tests/hello_clone3fn tests/hello_clone3fn.s
```

Copy into `payload/tests/` if the guest fetches from the HTTP tree.

---

## After PTHREADOK

Keep going in dependency order, not by excitement:

1. Whatever the next **unmodified** static binary issues (strace on
   the host first).
2. Ash fd 0 blocking is still a tty stub so `read()` gets keystrokes.
3. More ioctl only as programs issue them.
4. linuxkpi / building Linux drivers on Haiku is a later sidecar.
   The adapter is the base.

Product goal: run a compiler / real CLI on Haiku without rewriting
it. Finish line for the first pyramid was `uname01` `UNAME_RC=0`.
That landed. Threads are the current climb.

---

## How to file / how to grind

Open an issue with the binary, the exact `sys_compat_run` command,
stdout, exit code, whether the desktop survived, and COM1 around the
failure. One failure per issue.

Push a small commit after each working syscall, safety fix, or
standup. Do not wait for a giant PR. Public Domain / CC0.

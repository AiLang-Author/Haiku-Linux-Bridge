# What is actually broken: Haiku vs the PostgreSQL port

Date: 2026-08-31  
Tree: PostgreSQL 18.4 on Haiku r1beta6 (hrev59866+79), QEMU/KVM guest.  
Stock package: HaikuPorts `postgresql18` 18.4-2.  
This is a parking note. Revisit when there is bandwidth to patch **Haiku**, not more `#ifdef __HAIKU__` in Postgres.

Linux Postgres assumes POSIX/C99. Haiku *advertises* those APIs. Three of them do not keep the contract. Postgres then hangs or gives wrong answers. HaikuPorts shipped a binary that **compiles**. Official `make check` never completed on the stock package.

The stopgaps in `patches/` (0001–0003) make *our* tree usable. They are not the Linux contract. The Linux contract is: fix Haiku, drop the Postgres ifdefs.

---

## 1. Nonblocking sockets are a lie

**Symptom (stock libpq / psql):**  
Query runs. Result prints. `psql -c` never returns. Official `make check` prints `using temp instance on port …` and sits there. Raw `PQexec` is fine (milliseconds). `PQconsumeInput` after a successful query blocks forever.

**What POSIX/Linux do:**  
`socket(…, SOCK_STREAM | SOCK_NONBLOCK, 0)` or `fcntl(fd, F_SETFL, O_NONBLOCK)` makes `recv()` return `EAGAIN`/`EWOULDBLOCK` when there is no data.

**What Haiku does:**

| Call | `F_GETFL` shows `O_NONBLOCK` | `recv()` with no data |
| --- | --- | --- |
| `socket(SOCK_NONBLOCK)` | yes | **blocks** |
| `fcntl(O_NONBLOCK)` | yes | **blocks** (TCP and AF_UNIX) |
| `ioctl(FIONBIO)` | yes | `EAGAIN` immediately |
| `recv(…, MSG_DONTWAIT)` | n/a | `EAGAIN` immediately |
| `socketpair` + `fcntl(O_NONBLOCK)` | yes | `EAGAIN` (this path works) |

**Where in Haiku:**  
`src/system/kernel/fs/socket.cpp` — `create_socket_fd()` / `common_socket()`.

`SOCK_NONBLOCK` is stripped from the type, then only copied into the **file descriptor** `open_mode` (`O_NONBLOCK`). `F_GETFL` reads that bit. `recv()` does **not**. The network stack uses `SO_NONBLOCK` / receive timeout.

`fcntl(F_SETFL, O_NONBLOCK)` on a socket fd *does* translate, via `socket_set_flags()` → `B_SET_NONBLOCKING_IO` → `SO_NONBLOCK`. So does `ioctl(FIONBIO)`, which the VFS maps to `F_SETFL` (`src/system/kernel/fs/fd.cpp`).

Postgres 18 sees `#define SOCK_NONBLOCK` in `sys/socket.h` and **skips** `pg_set_noblock()`. On Linux that skip is correct. On Haiku it means the socket is never put in the mode `recv()` actually honors.

**Real fix (Haiku):** when `SOCK_NONBLOCK` is passed to `socket()`/`accept()`, set `SO_NONBLOCK` on the `net_socket` (same path as `F_SETFL`). Then `F_GETFL` and `recv()` agree.

**Stopgap:** `pg-haiku/patches/0001-nonblocking-sockets.patch` — `ioctl(FIONBIO)` in `pg_set_noblock`, force that call on Haiku even if `SOCK_NONBLOCK` exists, `MSG_DONTWAIT` on libpq `recv`/`send`.

Headers for the split brain:

- `headers/posix/fcntl.h` — `O_NONBLOCK 0x80`
- `headers/posix/sys/socket.h` — `SOCK_NONBLOCK 0x00040000`, `SO_NONBLOCK 0x40000009`, `MSG_DONTWAIT 0x80`
- `headers/posix/sys/ioctl.h` — `FIONBIO 0xbe000000`

---

## 2. `localeconv_l()` never returns

**Symptom:**  
`SELECT to_char(123456789012345::bigint, '9G999G999G999G999G999')` hangs (no row). `'123'::money` hangs. `to_char` with a literal comma pattern returns immediately. `SHOW lc_numeric` is `POSIX`.

**What POSIX/Linux do:**  
`newlocale(LC_ALL_MASK, "C", 0)` then `localeconv_l(loc)` returns an `lconv` without blocking.

**What Haiku does (measured):**

| Call | Result |
| --- | --- |
| `localeconv()` | instant; POSIX `frac_digits=127`, empty thousands_sep |
| `newlocale(LC_ALL_MASK, "C", 0)` | instant, non-NULL |
| `uselocale(loc)` then `localeconv()` | instant |
| `localeconv_l(loc)` | **hangs** |

Postgres 18 `configure` sets `HAVE_LOCALECONV_L`. `pg_localeconv_r()` then uses `localeconv_l`. First money/`G` format calls `PGLC_localeconv()` and the backend never comes back.

**Where in Haiku:**  
`src/system/libroot/posix/locale/localeconv.cpp` (`localeconv_l`) and `locale_t.cpp` (`newlocale`). For `"C"`/`"POSIX"`, `newlocale` leaves `backend == NULL`. `localeconv_l` should then return `gPosixLocaleConv`. Empirically it does not return. Guest was r1beta6 hrev59866+79; this source tree may not be that exact rev — treat the hang as measured, the files as the place to look.

**Real fix (Haiku):** `localeconv_l` on a `locale_t` from `newlocale("C")` must return, same as `localeconv()`.

**Stopgap:** `pg-haiku/patches/0002-skip-localeconv_l.patch` — `#undef HAVE_LOCALECONV_L` on Haiku so Postgres uses `uselocale` + `localeconv`.

After 0002: official `int8`, `money`, `numeric` regress tests pass.

---

## 3. `strtod("-0")` drops the sign

**Symptom:**  
Official `foreign_key` test: `float8` PK/FK on `'-0'`. Expected display `-0`; got `0`. Cascade `UPDATE … WHERE a = '-0'` is meaningless if −0 was never stored. `float8send('-0'::float8)` is all zeros, same as `+0`.

**What C99/Linux do:**  
`strtod("-0", NULL)` is IEEE **−0** (`signbit` set).

**What Haiku does (measured):**

```
strtod("-0")  →  0   signbit=0  mem=0000000000000000
-0.0 (unary)  →  0   signbit=1  mem=0000000000000080   (little-endian)
+0.0          →  0   signbit=0
```

Unary minus on zero works. **Only the string conversion is wrong.** Input `"-0"` has a digit, so glibc’s `dig_no == 0` path (`return negative ? -0.0 : 0.0`) is not used; the mantissa-zero path loses the sign.

**Where in Haiku:**  
`src/system/libroot/posix/glibc/stdlib/strtod.c` (also `strtof` via the same file).

**Real fix (Haiku):** `strtod`/`strtof` of a signed zero string must return a signed zero.

**Stopgap:** `pg-haiku/patches/0003-negative-zero.patch` — if the scanned token starts with `-` and the value is `0.0`, do `val = -val` in `float4in_internal` / `float8in_internal`. After that, `foreign_key` passes.

---

## Postgres / HaikuPorts (not Haiku libc)

These are port/package problems, not extra kernel bugs:

- HaikuPorts `TEST()` is `make check`. Stock 18.4-2 **cannot** finish that suite because of (1). Publishing it was a compile, not a verified port.
- Recipe still has BeOS-era SysV shm emulation, `fdatasync` rewritten to `fsync` with a `Fix(?)` comment, root checks stubbed. Untested leftovers.
- `HAVE_POLL` is unset in `pg_config.h` even though `poll()` works (`HAVE_PPOLL` is set). libpq uses `select()`. Not the hang; still not the Linux build.
- Stock `/boot/system` `postgres` / `libpq` do **not** contain 0001–0003. Our tree does. Do not overwrite the guest package until we intend to.

---

## What we already proved on the *patched* tree

Leave the guest packaged install alone until we choose to install.

| Battery | Result |
| --- | --- |
| `psql -c 'SELECT 1'` (tree libpq) | rc=0 |
| Official `pg_regress` `make check` (one full run, temp `synchronous_commit=off`) | **229/231** — fails were `foreign_key` (−0) and `stats` (config, not Haiku) |
| `int8` / `money` / `numeric` after 0002 | pass |
| `foreign_key` after 0003 | pass |
| Official **isolation** suite (119 specs, SSI/locks) | **119/119** |
| pgbench scale 10, 8 clients, 4 jobs, 20s, select-only | ~5440 tps, 1.47 ms |
| pgbench TPC-B-like | ~753 tps, 10.6 ms |

Not run: `make check-world`, `src/test/recovery` TAP (48 tests; Perl/prove exist on the guest).

`stats` asserting `synchronous_commit = 'on'` fails if TEMP_CONFIG sets it off. That is the harness, not Haiku.

---

## What to do when there is bandwidth

**Haiku (the real contract):**

1. `SOCK_NONBLOCK` / `socket()` must set `SO_NONBLOCK` on the stack, not only `O_NONBLOCK` on the fd. Then 0001 can go away.
2. `localeconv_l` must return for `newlocale("C")`. Then 0002 can go away.
3. `strtod("-0")` / `strtof("-0")` must be IEEE −0. Then 0003 can go away.

**Then Postgres:** apply nothing Haiku-specific; run `make check` and `make check-world` like Linux.

**Until then:** `patches/SERIES` — 0001, 0002, 0003 — on 18.4. Cherry-pick or `git am`. Rebuild **libpq and the backend**. Haiku `LIBRARY_PATH` replaces the default search; keep system lib dirs if you set it. `LD_LIBRARY_PATH` is ignored.

Guest notes from this grind: tree at `/boot/home/postgresql-18.4`, prefix `tmp_install/boot/home/pg-prefix`. Packaged server was kept on **5432**. Isolation/pgbench used **55440**.

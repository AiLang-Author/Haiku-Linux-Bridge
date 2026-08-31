# pg-haiku

Fixes for PostgreSQL on Haiku that HaikuPorts does not have yet.

This is a patch series against **PostgreSQL 18.4**. Apply in order from
`patches/SERIES`. Cherry-pick or `git am` onto a postgres tree, or append
the `.patch` files onto the HaikuPorts `postgresql18-18.4.patchset`.

License for *our* deltas: CC0 (same as Haiku-Linux-Bridge). PostgreSQL
itself stays under the PostgreSQL license.

## Current series

| Patch | What it fixes |
| --- | --- |
| [`patches/0001-nonblocking-sockets.patch`](patches/0001-nonblocking-sockets.patch) | `psql -c` never returns after a successful query. `make check` stalls after `using temp instance`. |
| [`patches/0002-skip-localeconv_l.patch`](patches/0002-skip-localeconv_l.patch) | `to_char(..., '9G999')` and `'123'::money` hang. Haiku `localeconv_l()` never returns. |
| [`patches/0003-negative-zero.patch`](patches/0003-negative-zero.patch) | `'-0'::float8` becomes `+0`. Haiku `strtod("-0")` drops the sign bit. Breaks float PK/FK. |

### 0001 in one paragraph

Haiku defines `SOCK_NONBLOCK` and `fcntl(O_NONBLOCK)` shows up in
`F_GETFL`, but `recv()`/`send()` on TCP and AF_UNIX sockets still **block**.
libpq therefore hangs in `PQconsumeInput`. The patch uses `ioctl(FIONBIO)`
(the flag the network stack actually honors) and `MSG_DONTWAIT` on
`recv`/`send`.

Proven on Haiku r1beta6: `timeout 5 psql -c 'SELECT 1'` returns 0;
official `pg_regress test_setup` passes; first type tests match expected
output. Packaged `libpq` is still the old one until this is in a rebuilt
`postgresql18` package.

## Apply on a vanilla 18.4 tree

```sh
cd postgresql-18.4
git am /path/to/pg-haiku/patches/0001-nonblocking-sockets.patch
# or:
patch -p1 < /path/to/pg-haiku/patches/0001-nonblocking-sockets.patch
```

Rebuild **libpq** at least (`src/interfaces/libpq` and `src/port/noblock.c`).
`psql` is dynamically linked to `libpq.so.5`.

On Haiku, `LD_LIBRARY_PATH` is ignored. If you are running a tree build
against a packaged `psql`/`libpq`, point at the rebuilt library:

```sh
export LIBRARY_PATH="/path/to/postgresql-18.4/src/interfaces/libpq:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib"
```

Setting `LIBRARY_PATH` *replaces* Haiku's default search, so keep the
system dirs.

## Apply on HaikuPorts

Append `patches/0001-nonblocking-sockets.patch` to

`dev-db/postgresql/patches/postgresql18-18.4.patchset`

then rebuild the `postgresql18` package. After that, stock
`/boot/system/bin/psql` does not need `LIBRARY_PATH`.

## Remaining (not patched here yet)

See [`remaining.md`](remaining.md). New breakage found on Haiku goes in
`patches/0002-…` and a line in `patches/SERIES`.

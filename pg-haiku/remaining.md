# Remaining Haiku PostgreSQL issues

Not in the patch series yet. Add a numbered patch when something is
actually fixed.

## Packaged libpq is still broken

HaikuPorts `postgresql18` 18.4-2 on r1beta6 still ships the unpatched
`libpq`. Stock `/boot/system/bin/psql` hangs after printing a successful
query until 0001 is in a rebuilt package. Tree-built libpq with
`LIBRARY_PATH` is the workaround.

## GSS / SSL handshake

With **0001** applied, rebuilt `psql` connects on a local unix socket
without `PGGSSENCMODE`/`PGSSLMODE`. This tree was built with
`ENABLE_GSS` undefined. Stock packaged `psql` still hangs because it
loads the old `libpq` (0001 not in the package yet).

## `to_char()` / money — fixed in 0002

Haiku `localeconv_l()` hangs; `localeconv()` and `uselocale()` work.
0002 undefines `HAVE_LOCALECONV_L` on Haiku so postgres uses the POSIX
path. After that, official `int8`, `money`, and `numeric` regress tests
pass.

## `stats` regress and `synchronous_commit`

A full `make check` with `synchronous_commit=off` in TEMP_CONFIG fails
`stats` because that test asserts `synchronous_commit` is `on`. That is
the test harness, not Haiku. Re-run without overriding it.

## Serial one-test-per-cluster is a false FAIL

`char_tbl` / `int4_tbl` and friends are created by `test_setup`. Running
`pg_regress char` on a fresh temp instance fails with "relation does not
exist". That is the schedule, not the engine. Use `make check` /
`parallel_schedule` on **one** temp instance.

## Haiku `LIBRARY_PATH`

`LD_LIBRARY_PATH` is ignored. Setting `LIBRARY_PATH` replaces the default
search path (libroot, libnetwork, …). Always append the system lib dirs.

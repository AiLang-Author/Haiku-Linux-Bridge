# Remaining Haiku PostgreSQL issues

Not in the patch series yet. Add a numbered patch when something is
actually fixed.

## Packaged libpq is still broken

HaikuPorts `postgresql18` 18.4-2 on r1beta6 still ships the unpatched
`libpq`. Stock `/boot/system/bin/psql` hangs after printing a successful
query until 0001 is in a rebuilt package. Tree-built libpq with
`LIBRARY_PATH` is the workaround.

## GSS / SSL handshake

`psql` can sit forever on connect unless:

```
PGGSSENCMODE=disable PGSSLMODE=disable
```

Separate from the nonblocking-recv bug. `PQexec` against a local socket
with those off is fine.

## `to_char()` grouping formats

Official `make check` gets past `test_setup` and the first type tests
(`boolean`, `char`, `int2`, `int4`, `varchar`, …) with matching output.
`int8`, `money`, and `numeric` have been seen to stall or truncate at
`to_char(..., '9G999…')` / locale grouping. Not understood yet.

## Serial one-test-per-cluster is a false FAIL

`char_tbl` / `int4_tbl` and friends are created by `test_setup`. Running
`pg_regress char` on a fresh temp instance fails with "relation does not
exist". That is the schedule, not the engine. Use `make check` /
`parallel_schedule` on **one** temp instance.

## Haiku `LIBRARY_PATH`

`LD_LIBRARY_PATH` is ignored. Setting `LIBRARY_PATH` replaces the default
search path (libroot, libnetwork, …). Always append the system lib dirs.

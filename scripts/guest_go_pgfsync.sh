#!/bin/sh
# Probe: is HaikuPorts postgres DDL stalling on BFS fsync?
# pg_test_fsync is shipped in postgresql18_server.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
export PAGER=cat PSQL_PAGER=cat
export PGGSSENCMODE=disable PGSSLMODE=disable
export PGCONNECT_TIMEOUT=8 PGHOST=/tmp PGPORT=5432
PGDATA=/boot/home/pgdata
OUT=/tmp/pg_fsync.txt
: > "$OUT"
exec >>"$OUT" 2>&1

post() {
	echo "$2" | tee /tmp/"$1"
	curl -s --max-time 8 -X POST --data-binary @/tmp/"$1" "$HOST/results/$1" || true
}
postfull() {
	curl -s --max-time 30 -X POST --data-binary @"$OUT" "$HOST/results/pg_fsync.txt" || true
}

post go_pgfsync_go.txt GO_PGSYNC_GO
echo "=== uname / bins ==="
uname -a
command -v pg_test_fsync
command -v pg_ctl
command -v psql
ls -l /bin/pg_test_fsync /boot/system/bin/pg_test_fsync 2>/dev/null
df -h
postfull

echo "=== pg_ctl status / restart ==="
pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" status || true
pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" restart -m fast || \
	pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" start
sleep 2
pg_isready -h /tmp -p 5432
post go_pgfsync_up.txt PG_UP
postfull

echo "=== gucs ==="
psql -d postgres -c "show fsync"
psql -d postgres -c "show wal_sync_method"
psql -d postgres -c "show synchronous_commit"
psql -d postgres -c "show full_page_writes"
psql -d postgres -c "show data_directory"
psql -d postgres -c "show wal_level"
psql -d postgres -c "select pg_backend_pid(), current_user, current_database()"
psql -d postgres -c "select count(*) as backends from pg_stat_activity"
postfull

echo "=== pg_test_fsync in PGDATA (BFS) secs=1 ==="
date
pg_test_fsync -f "$PGDATA/pg_test_fsync.tmp" -s 1
echo FSYNC_RC=$?
date
rm -f "$PGDATA/pg_test_fsync.tmp"
post go_pgfsync_bench.txt FSYNC_BENCH_DONE
postfull

echo "=== timed CREATE TABLE in postgres db ==="
date
psql -d postgres -c "SET statement_timeout = '10s'; DROP TABLE IF EXISTS t_probe; CREATE TABLE t_probe (id integer PRIMARY KEY);"
echo CREATE_TABLE_RC=$?
date
postfull

echo "=== timed CREATE DATABASE ==="
date
psql -d postgres -c "SET statement_timeout = '15s'; DROP DATABASE IF EXISTS pgprobe; CREATE DATABASE pgprobe;"
echo CREATE_DB_RC=$?
date
postfull

echo "=== logfile tail ==="
tail -80 "$PGDATA/logfile" 2>/dev/null || true
echo PGSYNC_DONE
post go_pgfsync_done.txt PGSYNC_DONE
postfull

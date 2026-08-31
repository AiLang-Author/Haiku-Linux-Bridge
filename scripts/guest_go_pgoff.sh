#!/bin/sh
# Diagnostic: disable fsync on Haiku BFS and retry DDL.
# Do not redirect the whole script — keep Terminal visible.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
export PAGER=cat PSQL_PAGER=cat
export PGGSSENCMODE=disable PGSSLMODE=disable
export PGCONNECT_TIMEOUT=8 PGHOST=/tmp PGPORT=5432
PGDATA=/boot/home/pgdata
OUT=/tmp/pg_off.txt
: > "$OUT"
post() {
	echo "$2" | tee /tmp/"$1"
	echo "$2" >> "$OUT"
	curl -s --max-time 8 -X POST --data-binary @/tmp/"$1" "$HOST/results/$1" || true
}
postfull() {
	curl -s --max-time 20 -X POST --data-binary @"$OUT" "$HOST/results/pg_off.txt" || true
}

post go_pgoff_go.txt GO_PGOFF_GO
pg_isready -h /tmp -p 5432 || echo NOT_READY
postfull

echo "=== append fsync=off to postgresql.conf ==="
if grep -q '^fsync = off' "$PGDATA/postgresql.conf" 2>/dev/null; then
	echo ALREADY_OFF
else
	printf '%s\n' \
		'# Haiku BFS: HaikuPorts maps fdatasync->fsync; fsync appears to stall DDL' \
		'fsync = off' \
		'synchronous_commit = off' \
		'full_page_writes = off' \
		>> "$PGDATA/postgresql.conf"
	echo APPENDED
fi
grep -n 'fsync\|synchronous_commit\|full_page_writes' "$PGDATA/postgresql.conf" | tail -20
postfull

echo "=== restart immediate ==="
pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" restart -m immediate
echo RESTART_RC=$?
sleep 2
pg_isready -h /tmp -p 5432
post go_pgoff_up.txt PG_UP
postfull

echo "=== gucs ==="
psql -d postgres -c "show fsync"
psql -d postgres -c "show wal_sync_method"
psql -d postgres -c "show synchronous_commit"
postfull

echo "=== CREATE TABLE ==="
date
psql -d postgres -c "DROP TABLE IF EXISTS t_probe; CREATE TABLE t_probe (id integer PRIMARY KEY); INSERT INTO t_probe VALUES (1); SELECT * FROM t_probe;"
echo CREATE_TABLE_RC=$?
date
post go_pgoff_table.txt TABLE_DONE
postfull

echo "=== CREATE DATABASE ==="
date
psql -d postgres -c "DROP DATABASE IF EXISTS pgprobe;"
psql -d postgres -c "CREATE DATABASE pgprobe;"
echo CREATE_DB_RC=$?
date
post go_pgoff_done.txt PGOFF_DONE
postfull
echo PGOFF_DONE

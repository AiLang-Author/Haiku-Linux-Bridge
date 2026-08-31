#!/bin/sh
# Clean one-session CAD schema apply. No pg_terminate_backend.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
export PAGER=cat PSQL_PAGER=cat
export PGGSSENCMODE=disable PGSSLMODE=disable
export PGCONNECT_TIMEOUT=8 PGHOST=/tmp PGPORT=5432
OUT=/tmp/pg_clean.txt
: > "$OUT"
exec >>"$OUT" 2>&1

echo GO_PGCLEAN_GO | tee /tmp/go_pgclean_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pgclean_go.txt "$HOST/results/go_pgclean_go.txt" || true

pg_isready -h /tmp -p 5432
curl -s --max-time 30 -o /boot/home/cad_schema.sql "$HOST/payload/cad_schema.sql"
ls -l /boot/home/cad_schema.sql

echo "=== activity ==="
psql -d postgres -c "SELECT pid, usename, datname, state, wait_event FROM pg_stat_activity WHERE datname IS NOT NULL;"

echo "=== apply schema ==="
psql -U bob -d cad_db -f /boot/home/cad_schema.sql
echo SCHEMA_RC=$?

echo "=== tables ==="
psql -U bob -d cad_db -c '\dt'
psql -U bob -d cad_db -c 'SELECT current_user, current_database();'

echo PGCLEAN_DONE
echo PGCLEAN_DONE | tee /tmp/go_pgclean_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pgclean_done.txt "$HOST/results/go_pgclean_done.txt" || true
curl -s --max-time 20 -X POST --data-binary @"$OUT" "$HOST/results/pg_clean.txt" || true

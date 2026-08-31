#!/bin/sh
# Apply CAD schema with one psql. Terminate other cad_db backends only
# (do not kill this session). GSS/SSL off for this HaikuPorts libpq.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
export PAGER=cat PSQL_PAGER=cat
export PGGSSENCMODE=disable PGSSLMODE=disable
export PGCONNECT_TIMEOUT=8 PGHOST=/tmp PGPORT=5432
OUT=/tmp/pg_schema.txt
: > "$OUT"
exec >>"$OUT" 2>&1

post() {
	echo "$2" | tee /tmp/"$1"
	curl -s --max-time 8 -X POST --data-binary @/tmp/"$1" "$HOST/results/$1" || true
}

post go_pgschema_go.txt GO_PGSCHEMA_GO
pg_isready -h /tmp -p 5432

curl -s --max-time 30 -o /boot/home/cad_schema.sql "$HOST/payload/cad_schema.sql"
ls -l /boot/home/cad_schema.sql

echo "=== other cad_db backends (not this pid) ==="
psql -d postgres -c "SELECT pid, usename, application_name, state, wait_event FROM pg_stat_activity WHERE datname='cad_db';"
psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='cad_db' AND pid <> pg_backend_pid();"
sleep 1
pg_isready -h /tmp -p 5432
curl -s --max-time 15 -X POST --data-binary @"$OUT" "$HOST/results/pg_schema.txt" || true

echo "=== apply schema ==="
psql -U bob -d cad_db -f /boot/home/cad_schema.sql
echo SCHEMA_RC=$?
curl -s --max-time 15 -X POST --data-binary @"$OUT" "$HOST/results/pg_schema.txt" || true

echo "=== tables ==="
psql -U bob -d cad_db -c '\dt'
psql -U bob -d cad_db -c 'SELECT current_user, current_database();'
echo PGSCHEMA_DONE
post go_pgschema_done.txt PGSCHEMA_DONE
curl -s --max-time 20 -X POST --data-binary @"$OUT" "$HOST/results/pg_schema.txt" || true

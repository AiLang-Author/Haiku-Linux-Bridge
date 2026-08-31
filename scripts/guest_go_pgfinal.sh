#!/bin/sh
# One-shot: drop leftover clients, apply CAD schema, list tables.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
export PAGER=cat PSQL_PAGER=cat
export PGGSSENCMODE=disable PGSSLMODE=disable
export PGCONNECT_TIMEOUT=8 PGHOST=/tmp PGPORT=5432
OUT=/tmp/pg_final.txt
: > "$OUT"
exec >>"$OUT" 2>&1

post() {
	echo "$2" | tee /tmp/"$1"
	curl -s --max-time 8 -X POST --data-binary @/tmp/"$1" "$HOST/results/$1" || true
}
postfull() {
	curl -s --max-time 20 -X POST --data-binary @"$OUT" "$HOST/results/pg_final.txt" || true
}

post go_pgfinal_go.txt GO_PGFINAL_GO
pg_isready -h /tmp -p 5432
curl -s --max-time 20 -o /tmp/term.sql "$HOST/payload/pg_terminate.sql"
curl -s --max-time 20 -o /tmp/pg_list.sql "$HOST/payload/pg_list.sql"
curl -s --max-time 30 -o /boot/home/cad_schema.sql "$HOST/payload/cad_schema.sql"
ls -l /boot/home/cad_schema.sql /tmp/term.sql /tmp/pg_list.sql
postfull

echo "=== terminate other backends ==="
psql -d postgres -f /tmp/term.sql || true
sleep 1
pg_isready -h /tmp -p 5432
postfull

echo "=== apply schema ==="
psql -U bob -d cad_db -f /boot/home/cad_schema.sql
echo SCHEMA_RC=$?
postfull

echo "=== list ==="
psql -U bob -d cad_db -f /tmp/pg_list.sql
echo PGFINAL_DONE
post go_pgfinal_done.txt PGFINAL_DONE
postfull

#!/bin/sh
# Restart Postgres, recreate empty cad_db, apply schema. One session.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
export PAGER=cat PSQL_PAGER=cat
export PGGSSENCMODE=disable PGSSLMODE=disable
export PGCONNECT_TIMEOUT=8 PGHOST=/tmp PGPORT=5432

echo GO_PGRESET_GO
curl -s --max-time 8 -X POST --data-binary @- "$HOST/results/go_pgreset_go.txt" <<EOF
GO_PGRESET_GO
EOF

pg_ctl -D /boot/home/pgdata restart -w
echo RESTART_RC=$?

curl -s --max-time 20 -o /tmp/pg_recreate_cad.sql "$HOST/payload/pg_recreate_cad.sql"
curl -s --max-time 20 -o /tmp/pg_list.sql "$HOST/payload/pg_list.sql"
curl -s --max-time 30 -o /boot/home/cad_schema.sql "$HOST/payload/cad_schema.sql"

echo "=== recreate cad_db ==="
psql -d postgres -f /tmp/pg_recreate_cad.sql
echo RECREATE_RC=$?

echo "=== apply schema ==="
psql -U bob -d cad_db -f /boot/home/cad_schema.sql
echo SCHEMA_RC=$?

echo "=== list ==="
psql -U bob -d cad_db -f /tmp/pg_list.sql
echo PGRESET_DONE
echo PGRESET_DONE | curl -s --max-time 8 -X POST --data-binary @- "$HOST/results/go_pgreset_done.txt" || true

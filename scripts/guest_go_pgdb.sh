#!/bin/sh
# Finish cad_db after postgresql18_server is already running.
# Avoid psql pager. Prefer unix socket /tmp then TCP.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
export PAGER=cat
export PSQL_PAGER=cat
export PGSSLMODE=disable
export PGHOST=/tmp
export PGPORT=5432
SCHEMA=/boot/home/cad_schema.sql
OUT=/tmp/pg_db.txt
: > "$OUT"
exec >>"$OUT" 2>&1

post() {
	name="$1"
	shift
	echo "$*" | tee /tmp/"$name"
	curl -s --max-time 8 -X POST --data-binary @/tmp/"$name" "$HOST/results/$name" || true
}
postfull() {
	curl -s --max-time 20 -X POST --data-binary @"$OUT" "$HOST/results/pg_db.txt" || true
}

post go_pgdb_go.txt GO_PGDB_GO
pg_isready -h /tmp -p 5432 || pg_isready -h 127.0.0.1 -p 5432
postfull

PSQL="psql -X -P pager=off -v ON_ERROR_STOP=0"
echo "=== version via unix /tmp ==="
$PSQL -d postgres -c "SELECT version();" || true
echo UNIX_RC=$?
echo "=== version via tcp ==="
PGHOST=127.0.0.1 $PSQL -d postgres -c "SELECT version();" || true
echo TCP_RC=$?
postfull

echo "=== role bob + cad_db ==="
createuser -h /tmp -s bob || createuser -h 127.0.0.1 -s bob || true
createdb -h /tmp -O bob cad_db || createdb -h 127.0.0.1 -O bob cad_db || true
$PSQL -d postgres -c "\\du"
$PSQL -d postgres -c "\\l"
$PSQL -U bob -d cad_db -c "SELECT current_user, current_database();"
post go_pgdb_db.txt DB_BOB_CAD
postfull

echo "=== schema ==="
if [ ! -f "$SCHEMA" ]; then
	curl -s --max-time 30 -o "$SCHEMA" "$HOST/payload/cad_schema.sql" || true
fi
if [ -f "$SCHEMA" ]; then
	$PSQL -U bob -d cad_db -f "$SCHEMA"
	echo SCHEMA_RC=$?
	$PSQL -U bob -d cad_db -c "\\dt"
else
	echo NO_SCHEMA_FILE
fi
postfull

pg_isready -h /tmp -p 5432
pg_isready -h 127.0.0.1 -p 5432
echo PGDB_DONE
post go_pgdb_done.txt PGDB_DONE
postfull

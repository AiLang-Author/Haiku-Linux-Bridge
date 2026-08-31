#!/bin/sh
# Install Haiku PostgreSQL 18 and stand up cad_db for AILang CAD.
# postgresql18 = psql. postgresql18_server = initdb/postgres/createdb (the file format).
# CAD_Repo.ConnectLocal: 127.0.0.1:5432 cad_db user bob, empty password.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
PGDATA=/boot/home/pgdata
export PAGER=cat
export PSQL_PAGER=cat
export PGGSSENCMODE=disable
export PGSSLMODE=disable
export PGCONNECT_TIMEOUT=8
SCHEMA=/boot/home/cad_schema.sql
OUT=/tmp/pg_inst.txt
FULL=/tmp/pg_inst_full.txt
post() {
	name="$1"
	shift
	echo "$*" | tee /tmp/"$name"
	curl -s --max-time 8 -X POST --data-binary @/tmp/"$name" "$HOST/results/$name" || true
}
postfull() {
	curl -s --max-time 20 -X POST --data-binary @"$FULL" "$HOST/results/pg_inst_full.txt" || true
}

# keep a host-visible log even if Terminal is idle
: > "$FULL"
exec >"$FULL" 2>&1

post go_pginst_go.txt GO_PGINST_GO

echo "=== uname / repos / df ==="
uname -a
pkgman list-repo
df -h
command -v curl
curl -s --max-time 8 "$HOST/health" || echo NO_HOST_8083
post go_pginst_probe.txt "PROBE_OK $(uname -a)"
postfull

echo "=== pkgman install -y postgresql18 postgresql18_server ==="
pkgman install -y postgresql18 postgresql18_server \
	|| pkgman --yes install postgresql18 postgresql18_server \
	|| yes | pkgman install postgresql18 postgresql18_server
echo INSTALL_RC=$?
hash -r 2>/dev/null || true
post go_pginst_pkg.txt "INSTALL_RC bins=$(command -v postgres) $(command -v psql) $(command -v initdb)"
postfull

echo "=== bins ==="
command -v psql; command -v initdb; command -v pg_ctl; command -v postgres; command -v createdb
ls -l /boot/system/bin/psql /boot/system/bin/initdb /boot/system/bin/pg_ctl /boot/system/bin/postgres /boot/system/bin/createdb 2>/dev/null
df -h

echo "=== initdb ==="
if [ ! -f "$PGDATA/PG_VERSION" ]; then
	mkdir -p "$PGDATA"
	initdb -D "$PGDATA" --encoding=UTF8 --no-locale
	echo INITDB_RC=$?
else
	echo INITDB_SKIP=1
fi
post go_pginst_initdb.txt "INITDB PG_VERSION=$(cat $PGDATA/PG_VERSION 2>/dev/null)"
postfull

echo "=== pg_hba / listen ==="
if [ -f "$PGDATA/pg_hba.conf" ]; then
	printf '%s\n' \
		'# CAD: trust local (ConnectLocal user bob empty password)' \
		'local   all   all                 trust' \
		'host    all   all   127.0.0.1/32  trust' \
		'host    all   all   ::1/128       trust' \
		> "$PGDATA/pg_hba.conf"
fi
if [ -f "$PGDATA/postgresql.conf" ]; then
	echo "listen_addresses = '127.0.0.1'" >> "$PGDATA/postgresql.conf"
	echo "unix_socket_directories = '/tmp'" >> "$PGDATA/postgresql.conf"
	echo "port = 5432" >> "$PGDATA/postgresql.conf"
fi

echo "=== start ==="
pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" status || true
pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" start
echo START_RC=$?
sleep 2
pg_isready -h 127.0.0.1 -p 5432 || true
echo "=== logfile ==="
tail -40 "$PGDATA/logfile" 2>/dev/null || true
post go_pginst_start.txt "START $(pg_isready -h 127.0.0.1 -p 5432 2>&1)"
postfull

echo "=== role bob + cad_db ==="
psql -h 127.0.0.1 -d postgres -c 'SELECT version();' || psql -d postgres -c 'SELECT version();'
createuser -h 127.0.0.1 -s bob || true
createdb -h 127.0.0.1 -O bob cad_db || true
psql -h 127.0.0.1 -d postgres -c '\l'
psql -h 127.0.0.1 -U bob -d cad_db -c 'SELECT current_user, current_database();'
post go_pginst_db.txt "DB cad_db/bob"

echo "=== schema ==="
if [ ! -f "$SCHEMA" ]; then
	curl -s --max-time 30 -o "$SCHEMA" "$HOST/payload/cad_schema.sql" || true
fi
if [ -f "$SCHEMA" ]; then
	psql -h 127.0.0.1 -U bob -d cad_db -f "$SCHEMA"
	echo SCHEMA_RC=$?
	psql -h 127.0.0.1 -U bob -d cad_db -c '\dt'
else
	echo NO_SCHEMA_FILE
fi

echo "=== ready ==="
pg_isready -h 127.0.0.1 -p 5432
echo PGINST_DONE
postfull

{
	echo INSTALL_RC
	command -v postgres
	command -v psql
	pg_isready -h 127.0.0.1 -p 5432
	df -h
	psql -h 127.0.0.1 -U bob -d cad_db -c 'SELECT current_user, current_database();' 2>&1
} > "$OUT" 2>&1
curl -s --max-time 20 -X POST --data-binary @"$OUT" "$HOST/results/pg_inst.txt" || true
post go_pginst_done.txt GO_PGINST_DONE

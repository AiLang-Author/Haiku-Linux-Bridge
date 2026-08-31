#!/bin/sh
# Probe: is PostgreSQL on this Haiku guest? Search only — no install.
# Native Haiku pkgman/psql, not Linux sys_compat.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/pg_probe.txt
{
	echo "=== uname / rev ==="
	uname -a
	cat /system/haiku_version 2>/dev/null || true
	sysinfo -cpu 2>/dev/null | head -5
	echo "=== repos ==="
	pkgman list-repo
	echo "=== bins already here ==="
	command -v psql; command -v initdb; command -v pg_ctl; command -v postgres; command -v createdb
	ls -l /boot/system/bin/psql /boot/system/bin/initdb /boot/system/bin/pg_ctl /boot/system/bin/postgres 2>/dev/null || true
	ls -l /boot/system/bin/postgresql* /boot/home/config/non-packaged/bin/psql 2>/dev/null || true
	echo "=== pkgman list postgres ==="
	pkgman list 2>/dev/null | grep -i postgres || echo NO_INSTALLED_POSTGRES
	echo "=== pkgman search postgresql ==="
	pkgman search postgresql
	echo SEARCH_RC=$?
	echo "=== pkgman search postgres ==="
	pkgman search postgres
	echo "=== pkgman search cmd:psql ==="
	pkgman search cmd:psql
	echo "=== df ==="
	df -h
} > "$OUT" 2>&1
cat "$OUT"
curl -s --max-time 20 -X POST --data-binary @"$OUT" "$HOST/results/pg_probe.txt" || true
echo GO_PG_DONE
curl -s --max-time 8 -X POST --data-binary @- "$HOST/results/go_pg_done.txt" <<EOF
GO_PG_DONE
EOF

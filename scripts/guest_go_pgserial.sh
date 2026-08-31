#!/bin/sh
# Sequential postgres regress: one test at a time, 90s timeout each.
# Temp cluster: fsync=off so we get a pass/fail list instead of hanging on test_setup.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/postgresql-18.4
REGRESSDIR=$SRC/src/test/regress
LOG=/boot/home/pgcheck_serial.log
STAT=/boot/home/pgcheck_serial_stat.txt
: > "$LOG"
: > "$STAT"
exec >>"$LOG" 2>&1

poststat() {
	echo "$1" | tee -a "$STAT"
	curl -s --max-time 8 -X POST --data-binary @"$STAT" "$HOST/results/pgcheck_serial_stat.txt" || true
	curl -s --max-time 20 -X POST --data-binary @"$LOG" "$HOST/results/pgcheck_serial.log" || true
}

printf '%s\n' \
	'fsync = off' \
	'synchronous_commit = off' \
	'full_page_writes = off' \
	> /boot/home/pg_temp.conf

PREFIX="$SRC/tmp_install/boot/home/pg-prefix"
export PATH="$PREFIX/bin:$REGRESSDIR:$PATH"
# Haiku ignores LD_LIBRARY_PATH; setting LIBRARY_PATH replaces the default
# search, so keep the system dirs or gcc/psql cannot find libroot/libnetwork.
export LIBRARY_PATH="$PREFIX/lib:$SRC/src/interfaces/libpq:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib"
export LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export INITDB_TEMPLATE="$SRC/tmp_install/initdb-template"
export PGGSSENCMODE=disable PGSSLMODE=disable PAGER=cat HOME=/tmp

PGREGRESS="$REGRESSDIR/pg_regress"
cd "$REGRESSDIR" || exit 1

# schedule order, one name per line
awk '/^test:/{for(i=2;i<=NF;i++) print $i}' "$REGRESSDIR/parallel_schedule" > /tmp/pg_tests.txt
n=$(wc -l < /tmp/pg_tests.txt)
poststat "SERIAL_BEGIN n=$n"

i=0
pass=0
fail=0
timeouts=0
while read -r t; do
	[ -n "$t" ] || continue
	i=$((i+1))
	echo ""
	echo "===== START $i/$n $t $(date -u +%H:%M:%S) ====="
	rm -rf ./tmp_check
	timeout -k 10 90 \
		"$PGREGRESS" \
			--temp-instance=./tmp_check \
			--inputdir=. \
			--bindir="$PREFIX/bin" \
			--dlpath=. \
			--max-connections=1 \
			--temp-config=/boot/home/pg_temp.conf \
			"$t"
	rc=$?
	# Stop only this run's temp cluster. Do not kill tmp_install binaries
	# globally — that also matches the debug 55432 postmaster.
	if [ -d ./tmp_check/data ]; then
		pg_ctl -D ./tmp_check/data -m immediate stop >/dev/null 2>&1 || true
	fi
	if [ "$rc" -eq 0 ]; then
		pass=$((pass+1))
		poststat "OK $t"
	elif [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
		timeouts=$((timeouts+1))
		poststat "TIMEOUT $t rc=$rc"
	else
		fail=$((fail+1))
		poststat "FAIL $t rc=$rc"
		if [ -f regression.diffs ]; then
			echo "----- diffs $t -----"
			tail -40 regression.diffs
		fi
	fi
done < /tmp/pg_tests.txt

poststat "SERIAL_DONE pass=$pass fail=$fail timeout=$timeouts"
echo SERIAL_DONE

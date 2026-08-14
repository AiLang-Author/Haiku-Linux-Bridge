#!/bin/sh
# First-wave LTP smoke: syscalls we claim, plus harness reality.
# Skip hang-prone (futex/poll/select/epoll/socket/clone/exec/signal).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
LTP=/boot/home/ltp/bin
OUT=/tmp/ltp_smoke.out
RUNNER=/boot/home/sys_compat_run

mkdir -p "$LTP"
WAVE="hello_min uname01 exit01 getpid01 gettid01 write01 read01 close01 open01 openat01 lseek01 fstat02 stat01 brk01 mmap01 munmap01 arch_prctl01"
for name in $WAVE; do
	if [ ! -x "$LTP/$name" ]; then
		curl -s -o "$LTP/$name" "$HOST/payload/ltp/bin/$name" || true
		chmod 755 "$LTP/$name" 2>/dev/null || true
	fi
done
# hello_min lives with the other tests too
if [ ! -x "$LTP/hello_min" ]; then
	curl -s -o "$LTP/hello_min" "$HOST/payload/tests/hello_min"
	chmod 755 "$LTP/hello_min"
fi

{
	echo "=== LTP first-wave $(date) ==="
	echo "runner=$RUNNER"
	cat /dev/misc/sys_compat 2>&1
	echo "========================================"
} > "$OUT"

pass=0
fail=0
timeouts=0
missing=0

run_one() {
	name="$1"
	bin="$LTP/$name"
	echo "----- $name -----" >> "$OUT"
	if [ ! -f "$bin" ]; then
		echo "MISSING $name" >> "$OUT"
		missing=$((missing + 1))
		return
	fi
	chmod 755 "$bin" 2>/dev/null || true
	rm -f /tmp/one.out
	"$RUNNER" "$bin" > /tmp/one.out 2>&1 &
	pid=$!
	n=0
	rc=0
	while [ $n -lt 12 ]; do
		if ! kill -0 "$pid" 2>/dev/null; then
			wait "$pid"
			rc=$?
			break
		fi
		sleep 1
		n=$((n + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null || true
		sleep 1
		kill -9 "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
		rc=124
		echo "TIMEOUT $name" >> "$OUT"
		timeouts=$((timeouts + 1))
	else
		case "$rc" in
			0) pass=$((pass + 1)) ;;
			*) fail=$((fail + 1)) ;;
		esac
	fi
	echo "EXIT:$name=$rc" >> "$OUT"
	sed -n '1,80p' /tmp/one.out >> "$OUT" 2>/dev/null
	echo "=== status after $name ===" >> "$OUT"
	cat /dev/misc/sys_compat >> "$OUT" 2>&1
	curl -s -X POST --data-binary @"$OUT" "$HOST/results/ltp_smoke.txt" >/dev/null 2>&1 || true
}

for name in $WAVE; do
	run_one "$name"
done

{
	echo "========================================"
	echo "SUMMARY pass=$pass fail=$fail timeout=$timeouts missing=$missing"
	echo "=== status final ==="
	cat /dev/misc/sys_compat 2>&1
} >> "$OUT"

echo "=== ltp_smoke.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/ltp_smoke.txt" || true
echo RUN_LTP_DONE

#!/bin/sh
# Next layer: more static busybox + LTP first-wave. sh pipe is still open.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/wave.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
LTP=/boot/home/ltp/bin
hey -o debug_server quit of Window 0 2>/dev/null || true
if [ ! -x "$BB" ]; then
	curl -s -o "$BB" "$HOST/payload/tests/busybox"
	chmod 755 "$BB"
fi
if [ ! -x /boot/home/hello_pipeline ]; then
	curl -s -o /boot/home/hello_pipeline "$HOST/tests/hello_pipeline"
	chmod 755 /boot/home/hello_pipeline
fi
mkdir -p "$LTP"
WAVE="hello_min uname01 exit01 getpid01 gettid01 write01 read01 close01 open01 openat01 lseek01 fstat02 stat01 access01 chdir01 getcwd01 mkdir02 unlink05 dup01 dup201 fcntl01 brk01 mmap01 munmap01 arch_prctl01 pipe01"
for name in $WAVE; do
	if [ ! -x "$LTP/$name" ]; then
		curl -s -o "$LTP/$name" "$HOST/payload/ltp/bin/$name" || true
		chmod 755 "$LTP/$name" 2>/dev/null || true
	fi
done
if [ ! -x "$LTP/hello_min" ]; then
	curl -s -o "$LTP/hello_min" "$HOST/payload/tests/hello_min"
	chmod 755 "$LTP/hello_min"
fi

{
	echo "=== wave $(date) ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_pipeline ==="
	$RUN /boot/home/hello_pipeline
	echo PIPELINE_RC=$?
	echo "=== busybox more ==="
	$RUN $BB id; echo ID_RC=$?
	$RUN $BB pwd; echo PWD_RC=$?
	$RUN $BB true; echo TRUE_RC=$?
	$RUN $BB printf 'MOREOK\n'; echo PRINTF_RC=$?
	$RUN $BB dirname /boot/home/busybox; echo DIRNAME_RC=$?
	$RUN $BB basename /boot/home/busybox; echo BASENAME_RC=$?
	echo abc | $RUN $BB cksum; echo CKSUM_RC=$?
	echo abc | $RUN $BB od -An -tx1; echo OD_RC=$?
	echo "=== LTP wave ==="
} > "$OUT" 2>&1

pass=0
fail=0
timeouts=0
run_one() {
	name="$1"
	bin="$LTP/$name"
	echo "----- $name -----" >> "$OUT"
	if [ ! -f "$bin" ]; then
		echo "MISSING $name" >> "$OUT"
		return
	fi
	rm -f /tmp/one.out
	"$RUN" "$bin" > /tmp/one.out 2>&1 &
	pid=$!
	n=0
	rc=0
	while [ $n -lt 10 ]; do
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
	sed -n '1,40p' /tmp/one.out >> "$OUT" 2>/dev/null
	curl -s -X POST --data-binary @"$OUT" "$HOST/results/wave_out.txt" >/dev/null 2>&1 || true
}

for name in $WAVE; do
	run_one "$name"
done

{
	echo "========================================"
	echo "SUMMARY pass=$pass fail=$fail timeout=$timeouts"
	cat /dev/misc/sys_compat 2>&1
} >> "$OUT"

echo "=== wave.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/wave_out.txt" || true
echo RUN_WAVE_DONE

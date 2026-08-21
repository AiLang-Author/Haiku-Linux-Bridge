#!/bin/sh
# Prove busybox sh pipe, including Haiku redirect of the whole run.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
hey -o debug_server quit of Window "Crashed program" 2>/dev/null || true
hey -o debug_server quit of Window 0 2>/dev/null || true
OUT=/tmp/sh48.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
if [ ! -x "$BB" ]; then
	curl -s -o "$BB" "$HOST/payload/tests/busybox"
	chmod 755 "$BB"
fi
if [ ! -x "$RUN" ]; then
	curl -s -o "$RUN.c" "$HOST/src/sys_compat_run.c"
	gcc -O2 "$RUN.c" -o "$RUN"
	chmod 755 "$RUN"
fi
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== sh -c echo ==="
	$RUN $BB sh -c 'echo SHOK'
	echo SH_ECHO_RC=$?
	echo "=== sh -c pipe ==="
	$RUN $BB sh -c 'echo HI | cat'
	echo SH_PIPE_RC=$?
	echo "=== sh -c pipe redirect ==="
	$RUN $BB sh -c 'echo HI | cat' > /tmp/pipe_redir.txt 2>&1
	echo SH_PIPE_REDIR_RC=$?
	echo "=== pipe_redir.txt ==="
	cat /tmp/pipe_redir.txt
	echo "=== sh -c true ==="
	$RUN $BB sh -c 'true; echo SHDONE'
	echo SH_TRUE_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== sh48.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/sh48_out.txt" || true
echo RUN_SH48_DONE

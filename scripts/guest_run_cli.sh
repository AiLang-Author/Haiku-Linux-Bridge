#!/bin/sh
# Prove everyday Linux CLI applets (no fork). grep/sed/wc/head/sort/cut.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/cli.out
RUNNER=/boot/home/sys_compat_run
BB=/boot/home/busybox
if [ ! -x "$BB" ]; then
	curl -s -o "$BB" "$HOST/payload/tests/busybox"
	chmod 755 "$BB"
fi
printf 'hello world\nfoo bar\nhello linux\nzzz\n' > /tmp/cli.txt
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== grep hello ==="
	$RUNNER $BB grep hello /tmp/cli.txt
	echo GREP_RC=$?
	echo "=== wc -l ==="
	$RUNNER $BB wc -l /tmp/cli.txt
	echo WC_RC=$?
	echo "=== sed ==="
	$RUNNER $BB sed s/hello/hi/ /tmp/cli.txt
	echo SED_RC=$?
	echo "=== head ==="
	$RUNNER $BB head -n 2 /tmp/cli.txt
	echo HEAD_RC=$?
	echo "=== sort ==="
	$RUNNER $BB sort /tmp/cli.txt
	echo SORT_RC=$?
	echo "=== cut ==="
	$RUNNER $BB cut -d' ' -f1 /tmp/cli.txt
	echo CUT_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== cli.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/cli_out.txt" || true
echo RUN_CLI_DONE

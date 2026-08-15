#!/bin/sh
# Run hello_min then fork probe.
# Haiku-side fork first (HAIKU_FORK_OK), then mark + Linux clone.
# Child IRETQ lands on the loader trampoline, not 0x401000.
# Expect PRE, or a KDL — not a silent reset.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/fork.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_fork ==="
	/boot/home/sys_compat_run /boot/home/hello_fork
	echo FORK_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== fork.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/fork_out.txt" || true
echo RUN_FORK_DONE

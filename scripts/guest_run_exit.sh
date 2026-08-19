#!/bin/sh
# Guest: glibc vs raw exit status probes.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
OUT=/tmp/exit.out
for f in hello_exit hello_ret1 hello_exit1 hello__exit1; do
	curl -s -o /boot/home/$f "$HOST/payload/tests/$f"
	chmod 755 /boot/home/$f
done
{
	echo "=== hello_exit ==="
	$RUN /boot/home/hello_exit
	echo EXIT42_RC=$?
	echo "=== hello_ret1 ==="
	$RUN /boot/home/hello_ret1
	echo RET1_RC=$?
	echo "=== hello_exit1 ==="
	$RUN /boot/home/hello_exit1
	echo EXIT1_RC=$?
	echo "=== hello__exit1 ==="
	$RUN /boot/home/hello__exit1
	echo _EXIT1_RC=$?
	echo "=== echo ==="
	$RUN $BB echo HELLO_ARGV
	echo ECHO_RC=$?
	echo "=== false ==="
	$RUN $BB false
	echo FALSE_RC=$?
	echo "=== true ==="
	$RUN $BB true
	echo TRUE_RC=$?
} > "$OUT" 2>&1
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/exit_out.txt" || true
echo RUN_EXIT_DONE

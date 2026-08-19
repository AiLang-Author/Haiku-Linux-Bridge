#!/bin/sh
# Guest: Linux TTY ioctl onto Haiku tty (fd0) vs redirect (fd1).
# Run as: sh /boot/home/run_tty.sh
# Do not pipe this script into sh — that makes fd0 a pipe, not the Terminal.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
RUN=/boot/home/sys_compat_run
curl -s -o /boot/home/hello_tty "$HOST/payload/tests/hello_tty"
chmod 755 /boot/home/hello_tty
{
	echo "=== tty ==="
	$RUN /boot/home/hello_tty
	echo TTY_RC=$?
	echo "=== date still ==="
	$RUN /boot/home/busybox date -u
	echo DATE_RC=$?
} > /tmp/tty.out 2>&1
cat /tmp/tty.out
curl -s --max-time 8 -X POST --data-binary @/tmp/tty.out "$HOST/results/tty_out.txt" || true
echo RUN_TTY_DONE

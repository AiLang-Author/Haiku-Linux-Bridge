#!/bin/sh
# PR5: wstat/mmap/pipe/uname01. POST results before cat.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
# LTP tst_kconfig looks for /proc/config.gz then /boot/config-$(uname -r).
# uname release is 6.1.0. A plain file avoids popen(zcat) on config.gz.
export KCONFIG_PATH=/boot/home/linux_kconfig
if [ ! -f /boot/home/linux_kconfig ]; then
	curl -s -o /boot/home/linux_kconfig "$HOST/payload/linux_kconfig"
	cp -f /boot/home/linux_kconfig /boot/config-6.1.0 2>/dev/null || true
fi
# Keep a dismisser running: Oh no! is B_QUIT_REQUESTED on
# debug_server window "Crashed program". A one-shot hey at
# start misses the dialog that appears mid-test.
if [ ! -x /boot/home/dismiss_crash.sh ]; then
	curl -s -o /boot/home/dismiss_crash.sh "$HOST/scripts/guest_dismiss_crash.sh"
	chmod 755 /boot/home/dismiss_crash.sh
fi
sh /boot/home/dismiss_crash.sh || true
(
	i=0
	while [ "$i" -lt 180 ]; do
		sh /boot/home/dismiss_crash.sh
		sleep 1
		i=$((i + 1))
	done
) >/dev/null 2>&1 &
DISMISS_PID=$!
trap 'kill $DISMISS_PID 2>/dev/null || true' EXIT INT TERM
OUT=/tmp/next.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
if [ ! -x /boot/home/hello_mmapf ]; then
	curl -s -o /boot/home/hello_mmapf "$HOST/tests/hello_mmapf"
	chmod 755 /boot/home/hello_mmapf
fi
if [ ! -x /boot/home/hello_wstat ]; then
	curl -s -o /boot/home/hello_wstat "$HOST/tests/hello_wstat"
	chmod 755 /boot/home/hello_wstat
fi
if [ ! -x /boot/home/ltp/bin/uname01 ]; then
	mkdir -p /boot/home/ltp/bin
	curl -s -o /boot/home/ltp/bin/uname01 "$HOST/payload/ltp/bin/uname01"
	chmod 755 /boot/home/ltp/bin/uname01
fi
{
	echo "=== wstat ==="
	$RUN /boot/home/hello_wstat
	echo WSTAT_RC=$?
	echo "=== mmapf ==="
	$RUN /boot/home/hello_mmapf
	echo MMAPF_RC=$?
	echo "=== pipe ==="
	$RUN $BB sh -c 'echo HI | cat'
	echo PIPE_RC=$?
	echo "=== uname01 ==="
	$RUN /boot/home/ltp/bin/uname01
	echo UNAME_RC=$?
} > "$OUT" 2>&1
# Cat first. Guest curl POST over QEMU user-net often hangs the
# only Terminal (no SIGINT). --max-time keeps the window usable.
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/next_out.txt" || true
echo RUN_NEXT_DONE

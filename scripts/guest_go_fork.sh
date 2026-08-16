#!/bin/sh
# Install try_fork diagnostic driver. No UserBootscript.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
# Haiku dprintf/KDL on COM1 (QEMU -serial file:). Our hook also
# pokes 0x3f8 directly so breadcrumbs work even if this is off.
mkdir -p /boot/home/config/settings/kernel/drivers
KSET=/boot/home/config/settings/kernel/drivers/kernel
if [ ! -f "$KSET" ] || ! grep -q serial_debug_output "$KSET"; then
	printf 'serial_debug_output true\nserial_debug_speed 115200\n' >> "$KSET"
	echo "[+] enabled serial_debug_output in $KSET"
fi
if ! grep -q syslog_debug_output "$KSET" 2>/dev/null; then
	printf 'syslog_debug_output true\n' >> "$KSET"
	echo "[+] enabled syslog_debug_output in $KSET"
fi
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/hello_fork_probe "$HOST/tests/hello_fork_probe"
curl -s -o /boot/home/hello_fork "$HOST/tests/hello_fork"
curl -s -o /boot/home/hello_exec "$HOST/tests/hello_exec"
curl -s -o /boot/home/hello_futex "$HOST/tests/hello_futex"
curl -s -o /boot/home/hello_poll "$HOST/tests/hello_poll"
curl -s -o /boot/home/hello_select "$HOST/tests/hello_select"
curl -s -o /boot/home/hello_mmapf "$HOST/tests/hello_mmapf"
curl -s -o /boot/home/hello_pipeline "$HOST/tests/hello_pipeline"
curl -s -o /boot/home/run_fork.sh "$HOST/scripts/guest_run_fork.sh"
curl -s -o /boot/home/run_exec.sh "$HOST/scripts/guest_run_exec.sh"
curl -s -o /boot/home/run_futex.sh "$HOST/scripts/guest_run_futex.sh"
curl -s -o /boot/home/run_poll.sh "$HOST/scripts/guest_run_poll.sh"
curl -s -o /boot/home/run_select.sh "$HOST/scripts/guest_run_select.sh"
curl -s -o /boot/home/run_mmapf.sh "$HOST/scripts/guest_run_mmapf.sh"
curl -s -o /boot/home/run_pipeline.sh "$HOST/scripts/guest_run_pipeline.sh"
chmod 755 /boot/home/hello_min /boot/home/hello_fork_probe \
	/boot/home/hello_fork /boot/home/hello_exec /boot/home/hello_futex \
	/boot/home/hello_poll /boot/home/hello_select /boot/home/hello_mmapf \
	/boot/home/hello_pipeline \
	/boot/home/run_fork.sh /boot/home/run_exec.sh /boot/home/run_futex.sh \
	/boot/home/run_poll.sh /boot/home/run_select.sh /boot/home/run_mmapf.sh \
	/boot/home/run_pipeline.sh
make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
curl -s -o dump_sc.c "$HOST/payload/ltp/dump_sc.c"
gcc -O2 dump_sc.c -o /tmp/dump_sc && /tmp/dump_sc | tee /tmp/dump_sc.txt
curl -s -X POST --data-binary @/tmp/dump_sc.txt "$HOST/results/dump_sc_exec.txt" || true
echo GO_FORK_DONE | tee /tmp/go_fork_done.txt
curl -s -X POST --data-binary @/tmp/go_fork_done.txt "$HOST/results/go_fork_done.txt" || true
echo GO_FORK_DONE

#!/bin/sh
# Install driver. UserBootscript only auto-starts Terminal.
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
# sys_compat_run is rebuilt below from the just-fetched .c
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/busybox "$HOST/payload/tests/busybox"
curl -s -o /boot/home/hello_fork_probe "$HOST/tests/hello_fork_probe"
curl -s -o /boot/home/hello_fork "$HOST/tests/hello_fork"
curl -s -o /boot/home/hello_exec "$HOST/tests/hello_exec"
curl -s -o /boot/home/hello_futex "$HOST/tests/hello_futex"
curl -s -o /boot/home/hello_poll "$HOST/tests/hello_poll"
curl -s -o /boot/home/hello_select "$HOST/tests/hello_select"
curl -s -o /boot/home/hello_mmapf "$HOST/tests/hello_mmapf"
curl -s -o /boot/home/hello_wstat "$HOST/tests/hello_wstat"
curl -s -o /boot/home/hello_pipeline "$HOST/tests/hello_pipeline"
mkdir -p /boot/home/ltp/bin
curl -s -o /boot/home/ltp/bin/uname01 "$HOST/payload/ltp/bin/uname01"
curl -s -o /boot/home/run_fork.sh "$HOST/scripts/guest_run_fork.sh"
curl -s -o /boot/home/run_exec.sh "$HOST/scripts/guest_run_exec.sh"
curl -s -o /boot/home/run_futex.sh "$HOST/scripts/guest_run_futex.sh"
curl -s -o /boot/home/run_poll.sh "$HOST/scripts/guest_run_poll.sh"
curl -s -o /boot/home/run_select.sh "$HOST/scripts/guest_run_select.sh"
curl -s -o /boot/home/run_mmapf.sh "$HOST/scripts/guest_run_mmapf.sh"
curl -s -o /boot/home/run_pipeline.sh "$HOST/scripts/guest_run_pipeline.sh"
curl -s -o /boot/home/run_sh.sh "$HOST/scripts/guest_run_sh.sh"
curl -s -o /boot/home/run_next.sh "$HOST/scripts/guest_run_next.sh"
curl -s -o /boot/home/dismiss_crash.sh "$HOST/scripts/guest_dismiss_crash.sh"
curl -s -o /boot/home/dc.sh "$HOST/scripts/guest_dc.sh"
curl -s -o /boot/home/linux_kconfig "$HOST/payload/linux_kconfig"
cp -f /boot/home/linux_kconfig /boot/config-6.1.0 2>/dev/null || true
chmod 644 /boot/home/linux_kconfig /boot/config-6.1.0 2>/dev/null || true
chmod 755 /boot/home/hello_min /boot/home/busybox /boot/home/hello_fork_probe \
	/boot/home/hello_fork /boot/home/hello_exec /boot/home/hello_futex \
	/boot/home/hello_poll /boot/home/hello_select /boot/home/hello_mmapf \
	/boot/home/hello_wstat /boot/home/hello_pipeline \
	/boot/home/ltp/bin/uname01 \
	/boot/home/run_fork.sh /boot/home/run_exec.sh /boot/home/run_futex.sh \
	/boot/home/run_poll.sh /boot/home/run_select.sh /boot/home/run_mmapf.sh \
	/boot/home/run_pipeline.sh /boot/home/run_sh.sh /boot/home/run_next.sh \
	/boot/home/dismiss_crash.sh /boot/home/dc.sh
rm -rf objects.* *.o objects 2>/dev/null || true
grep -n 'kser_puts("K"' sys_compat_dev.cpp || echo 'NO_K_IN_SRC'
grep -n 'PR38' sys_compat_dev.cpp || echo 'NO_PR38_IN_SRC'
grep -n 'sUserDeleteArea' sys_compat_dev.cpp || echo 'NO_UD_IN_SRC'
grep -n 'sKernWriteStatFn' sys_compat_dev.cpp || echo 'NO_WK_IN_SRC'
grep -n 'SF' sys_compat_dev.cpp || echo 'NO_SF_IN_SRC'
make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
# Keep exactly one addon. A leftover system-tree copy loads after
# the user one and re-hooks LSTAR (COM1 printed PR13 then PR12b).
# driverinstall writes the new binary to the system tree.
USERBIN=/boot/home/config/non-packaged/add-ons/kernel/drivers/bin/sys_compat
USERDEV=/boot/home/config/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat
SYSBIN=/boot/system/non-packaged/add-ons/kernel/drivers/bin/sys_compat
SYSDEV=/boot/system/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat
BUILT=$(ls -t objects.*/sys_compat 2>/dev/null | head -1)
mkdir -p "$(dirname "$USERBIN")" "$(dirname "$USERDEV")"
if [ -n "$BUILT" ] && [ -f "$BUILT" ]; then
	cp -f "$BUILT" "$USERBIN"
	echo "[+] copied $BUILT -> $USERBIN"
elif [ -f "$SYSBIN" ]; then
	cp -f "$SYSBIN" "$USERBIN"
	echo "[+] copied $SYSBIN -> $USERBIN"
fi
ln -sfn "$USERBIN" "$USERDEV"
# Remove every other sys_compat publish point. find both /boot and
# /system — a leftover PR12b in either tree re-hooks LSTAR last.
{
	echo "=== find before ==="
	find /boot /system -name 'sys_compat' 2>/dev/null
} > /tmp/addons.txt
for p in "$SYSBIN" "$SYSDEV" \
	/boot/system/add-ons/kernel/drivers/bin/sys_compat \
	/boot/system/add-ons/kernel/drivers/dev/misc/sys_compat \
	/boot/system/non-packaged/add-ons/kernel/drivers/bin/sys_compat \
	/boot/system/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat \
	/system/non-packaged/add-ons/kernel/drivers/bin/sys_compat \
	/system/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat
do
	if [ -e "$p" ] || [ -L "$p" ]; then
		echo "RM $p" >> /tmp/addons.txt
		rm -f "$p" || echo "RM_FAIL $p" >> /tmp/addons.txt
	fi
done
find /boot /system -name 'sys_compat' 2>/dev/null | while read f; do
	if [ "$f" != "$USERBIN" ] && [ "$f" != "$USERDEV" ]; then
		echo "RM2 $f" >> /tmp/addons.txt
		rm -f "$f" || echo "RM2_FAIL $f" >> /tmp/addons.txt
	fi
done
{
	echo "=== find after ==="
	find /boot /system -name 'sys_compat' 2>/dev/null
	echo "=== user ==="
	ls -la "$USERBIN" "$USERDEV" 2>&1
} >> /tmp/addons.txt
curl -s -X POST --data-binary @/tmp/addons.txt "$HOST/results/addons.txt" || true
echo "[+] user addon only; extras removed"
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
curl -s -o dump_sc.c "$HOST/payload/ltp/dump_sc.c"
gcc -O2 dump_sc.c -o /tmp/dump_sc && /tmp/dump_sc | tee /tmp/dump_sc.txt
curl -s -X POST --data-binary @/tmp/dump_sc.txt "$HOST/results/dump_sc_exec.txt" || true
# Desktop login: official Haiku boot/launch symlink + UserBootscript.
BOOTDIR=/boot/home/config/settings/boot
mkdir -p "$BOOTDIR/launch"
ln -sfn /boot/system/apps/Terminal "$BOOTDIR/launch/Terminal"
BOOT="$BOOTDIR/UserBootscript"
curl -s -o /tmp/haiku_UserBootscript "$HOST/scripts/haiku_UserBootscript"
if [ -s /tmp/haiku_UserBootscript ]; then
	if [ -f "$BOOT" ] && ! grep -q SYS_COMPAT_AUTOTERM "$BOOT" 2>/dev/null; then
		cp "$BOOT" "$BOOT.bak"
	fi
	cp /tmp/haiku_UserBootscript "$BOOT"
	chmod 755 "$BOOT"
	echo "[+] wrote $BOOTDIR/launch/Terminal and $BOOT"
fi
curl -s -o /boot/home/launch_term.sh "$HOST/scripts/guest_launch_term.sh"
chmod 755 /boot/home/launch_term.sh
# Re-fetch Linux test ELFs (earlier curls without _ clobbered them).
curl -s -o /boot/home/hello_wstat "$HOST/tests/hello_wstat"
curl -s -o /boot/home/hello_mmapf "$HOST/tests/hello_mmapf"
chmod 755 /boot/home/hello_wstat /boot/home/hello_mmapf
curl -s -o /boot/home/run_next.sh "$HOST/scripts/guest_run_next.sh"
chmod 755 /boot/home/run_next.sh
echo GO_FORK_DONE | tee /tmp/go_fork_done.txt
curl -s -X POST --data-binary @/tmp/go_fork_done.txt "$HOST/results/go_fork_done.txt" || true
echo GO_FORK_DONE

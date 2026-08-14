#!/bin/sh
# Rebuild driver with real fstat/newfstatat. Arm hello_stat + ls -l.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
rm -f /boot/home/run_once_stat
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o "$SRC/dump_sc.c" "$HOST/payload/ltp/dump_sc.c"
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/hello_stat "$HOST/tests/hello_stat"
curl -s -o /boot/home/run_stat.sh "$HOST/scripts/guest_run_stat.sh"
chmod 755 /boot/home/hello_min /boot/home/hello_stat /boot/home/run_stat.sh
if [ ! -x /boot/home/busybox ]; then
	curl -s -o /boot/home/busybox "$HOST/payload/tests/busybox"
	chmod 755 /boot/home/busybox
fi

echo "[+] dump Haiku syscall numbers + sizeof(stat)"
gcc -O2 dump_sc.c -o /tmp/dump_sc && /tmp/dump_sc

make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run

rm -f /boot/home/run_once_busy /boot/home/run_once_fs /boot/home/run_once_mem
rm -f /boot/home/run_once_rseq
touch /boot/home/run_once_stat
BOOT=/boot/home/config/settings/boot/UserBootscript
if ! grep -q run_once_stat "$BOOT" 2>/dev/null; then
	cat >> "$BOOT" << 'EOF'
if [ -f /boot/home/run_once_stat ]; then
	rm -f /boot/home/run_once_stat
	sleep 8
	sh /boot/home/run_stat.sh > /boot/home/boot_stat.log 2>&1
	/boot/system/apps/Terminal &
fi
EOF
fi
echo GO_STAT_DONE

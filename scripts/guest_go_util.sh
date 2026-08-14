#!/bin/sh
# Rebuild driver with rename/symlink/link/readlink/clock/dup/fsync/utimensat.
# Dump Haiku numbers first. Do NOT arm UserBootscript.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
rm -f /boot/home/run_once_stat /boot/home/run_once_mkdir /boot/home/run_once_fork
rm -f /boot/home/run_once_wstat /boot/home/run_once_util
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o "$SRC/dump_sc.c" "$HOST/payload/ltp/dump_sc.c"
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/hello_util "$HOST/tests/hello_util"
curl -s -o /boot/home/hello_wstat "$HOST/tests/hello_wstat"
curl -s -o /boot/home/run_util.sh "$HOST/scripts/guest_run_util.sh"
chmod 755 /boot/home/hello_min /boot/home/hello_util /boot/home/hello_wstat /boot/home/run_util.sh
if [ ! -x /boot/home/busybox ]; then
	curl -s -o /boot/home/busybox "$HOST/payload/tests/busybox"
	chmod 755 /boot/home/busybox
fi

echo "[+] dump Haiku syscall numbers"
gcc -O2 dump_sc.c -o /tmp/dump_sc && /tmp/dump_sc | tee /tmp/dump_sc.out
curl -s -X POST --data-binary @/tmp/dump_sc.out "$HOST/results/dump_sc_util.txt" || true

make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
echo GO_UTIL_DONE | tee /tmp/go_util_done.txt
curl -s -X POST --data-binary @/tmp/go_util_done.txt "$HOST/results/go_util_done.txt" || true
echo GO_UTIL_DONE

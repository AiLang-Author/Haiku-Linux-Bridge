#!/bin/sh
# Rebuild driver with fcntl + statx. Dump _kern_fcntl first. No bootscript.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o "$SRC/dump_sc.c" "$HOST/payload/ltp/dump_sc.c"
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/hello_fcntl "$HOST/tests/hello_fcntl"
curl -s -o /boot/home/hello_date "$HOST/tests/hello_date"
curl -s -o /boot/home/run_fcntl.sh "$HOST/scripts/guest_run_fcntl.sh"
chmod 755 /boot/home/hello_min /boot/home/hello_fcntl /boot/home/hello_date /boot/home/run_fcntl.sh

echo "[+] dump Haiku syscall numbers"
gcc -O2 dump_sc.c -o /tmp/dump_sc && /tmp/dump_sc | tee /tmp/dump_sc.out
curl -s -X POST --data-binary @/tmp/dump_sc.out "$HOST/results/dump_sc_fcntl.txt" || true

make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
echo GO_FCNTL_DONE | tee /tmp/go_fcntl_done.txt
curl -s -X POST --data-binary @/tmp/go_fcntl_done.txt "$HOST/results/go_fcntl_done.txt" || true
echo GO_FCNTL_DONE

#!/bin/sh
# Fetch + build driver/loader. Does NOT mark this shell.
# After this: reboot, then sh /boot/home/run_hello.sh
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/run_hello.sh "$HOST/payload/ltp/run_hello.sh"
curl -s -o "$SRC/dump_sc.c" "$HOST/payload/ltp/dump_sc.c"
chmod 755 /boot/home/hello_min /boot/home/run_hello.sh

echo "[+] dump Haiku syscall numbers"
gcc -O2 dump_sc.c -o /tmp/dump_sc && /tmp/dump_sc

echo "[+] make -f Makefile.driver"
make -f Makefile.driver clean || true
make -f Makefile.driver
make -f Makefile.driver driverinstall

echo "[+] compiling Haiku-native sys_compat_run"
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run

echo "[+] status before reboot:"
cat /dev/misc/sys_compat || true
ls -l /boot/home/sys_compat_run /boot/home/hello_min
echo "[+] go.sh done — reboot, then sh /boot/home/run_hello.sh"
echo GO_DONE

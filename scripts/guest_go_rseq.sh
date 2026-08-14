#!/bin/sh
# Rebuild driver with Linux rseq in the hook. Arm hello_min+hello_rseq.
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
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/hello_rseq "$HOST/payload/tests/hello_rseq"
curl -s -o /boot/home/run_rseq.sh "$HOST/scripts/guest_run_rseq.sh"
chmod 755 /boot/home/hello_min /boot/home/hello_rseq /boot/home/run_rseq.sh

make -f Makefile.driver clean || true
make -f Makefile.driver
make -f Makefile.driver driverinstall
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run

rm -f /boot/home/run_once_busy /boot/home/run_once_fs /boot/home/run_once_mem
touch /boot/home/run_once_rseq
BOOT=/boot/home/config/settings/boot/UserBootscript
if ! grep -q run_once_rseq "$BOOT" 2>/dev/null; then
	cat >> "$BOOT" << 'EOF'
if [ -f /boot/home/run_once_rseq ]; then
	rm -f /boot/home/run_once_rseq
	sleep 8
	sh /boot/home/run_rseq.sh > /boot/home/boot_rseq.log 2>&1
	/boot/system/apps/Terminal &
fi
EOF
fi
echo GO_RSEQ_DONE

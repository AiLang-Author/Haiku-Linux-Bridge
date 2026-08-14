#!/bin/sh
# Rebuild driver with read/close remaps and arm a one-shot rwc test.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o /boot/home/hello_rwc "$HOST/payload/tests/hello_rwc"
curl -s -o /boot/home/run_rwc.sh "$HOST/payload/ltp/run_rwc.sh"
chmod 755 /boot/home/hello_rwc /boot/home/run_rwc.sh

make -f Makefile.driver clean || true
make -f Makefile.driver
make -f Makefile.driver driverinstall
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run

touch /boot/home/run_once_rwc
BOOT=/boot/home/config/settings/boot/UserBootscript
if ! grep -q run_once_rwc "$BOOT" 2>/dev/null; then
	cat >> "$BOOT" << 'EOF'
if [ -f /boot/home/run_once_rwc ]; then
	rm -f /boot/home/run_once_rwc
	sleep 8
	sh /boot/home/run_rwc.sh > /boot/home/boot_rwc.log 2>&1
	/boot/system/apps/Terminal &
fi
EOF
fi
echo GO_RWC_DONE

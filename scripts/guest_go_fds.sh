#!/bin/sh
# Rebuild driver with lseek/open/openat and arm a one-shot fds test.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o /boot/home/hello_fds "$HOST/payload/tests/hello_fds"
curl -s -o /boot/home/run_fds.sh "$HOST/scripts/guest_run_fds.sh"
curl -s -o "$SRC/dump_flags.c" "$HOST/tests/dump_flags.c"
chmod 755 /boot/home/hello_fds /boot/home/run_fds.sh

gcc -O2 dump_flags.c -o /tmp/dump_flags && /tmp/dump_flags

make -f Makefile.driver clean || true
make -f Makefile.driver
make -f Makefile.driver driverinstall
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run

touch /boot/home/run_once_fds
BOOT=/boot/home/config/settings/boot/UserBootscript
if ! grep -q run_once_fds "$BOOT" 2>/dev/null; then
	cat >> "$BOOT" << 'EOF'
if [ -f /boot/home/run_once_fds ]; then
	rm -f /boot/home/run_once_fds
	sleep 8
	sh /boot/home/run_fds.sh > /boot/home/boot_fds.log 2>&1
	/boot/system/apps/Terminal &
fi
EOF
fi
echo GO_FDS_DONE

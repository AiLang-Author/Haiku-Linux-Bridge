#!/bin/sh
# Rebuild driver with Haiku-safe SET_FS and arm hello_min+hello_fs.
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
curl -s -o /boot/home/hello_fs "$HOST/payload/tests/hello_fs"
curl -s -o /boot/home/run_fs.sh "$HOST/scripts/guest_run_fs.sh"
chmod 755 /boot/home/hello_min /boot/home/hello_fs /boot/home/run_fs.sh

make -f Makefile.driver clean || true
make -f Makefile.driver
make -f Makefile.driver driverinstall
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run

rm -f /boot/home/run_once_busy /boot/home/run_once_mem
touch /boot/home/run_once_fs
BOOT=/boot/home/config/settings/boot/UserBootscript
if ! grep -q run_once_fs "$BOOT" 2>/dev/null; then
	cat >> "$BOOT" << 'EOF'
if [ -f /boot/home/run_once_fs ]; then
	rm -f /boot/home/run_once_fs
	sleep 8
	sh /boot/home/run_fs.sh > /boot/home/boot_fs.log 2>&1
	/boot/system/apps/Terminal &
fi
EOF
fi
echo GO_FS_DONE

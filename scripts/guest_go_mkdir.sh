#!/bin/sh
# Rebuild driver with mkdir/getcwd/chdir/unlink/access. Arm uname01/write01.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
rm -f /boot/home/run_once_stat /boot/home/run_once_mkdir
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o /boot/home/run_mkdir.sh "$HOST/scripts/guest_run_mkdir.sh"
chmod 755 /boot/home/run_mkdir.sh
make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
touch /boot/home/run_once_mkdir
BOOT=/boot/home/config/settings/boot/UserBootscript
if ! grep -q run_once_mkdir "$BOOT" 2>/dev/null; then
	cat >> "$BOOT" << 'EOF'
if [ -f /boot/home/run_once_mkdir ]; then
	rm -f /boot/home/run_once_mkdir
	sleep 8
	sh /boot/home/run_mkdir.sh > /boot/home/boot_mkdir.log 2>&1
	/boot/system/apps/Terminal &
fi
EOF
fi
echo GO_MKDIR_DONE

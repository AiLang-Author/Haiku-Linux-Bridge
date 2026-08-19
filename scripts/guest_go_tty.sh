#!/bin/sh
# Rebuild PR39 ioctl TTY trap, then reboot so LSTAR loads.
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
grep -n 'PR39' sys_compat_dev.cpp || echo 'NO_PR39_IN_SRC'
grep -n 'sys_compat_ioctl' syscall_hook.S || echo 'NO_IOCTL_IN_HOOK'
rm -rf objects.* *.o objects 2>/dev/null || true
make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
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
for p in "$SYSBIN" "$SYSDEV" \
	/boot/system/add-ons/kernel/drivers/bin/sys_compat \
	/boot/system/add-ons/kernel/drivers/dev/misc/sys_compat \
	/boot/system/non-packaged/add-ons/kernel/drivers/bin/sys_compat \
	/boot/system/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat \
	/system/non-packaged/add-ons/kernel/drivers/bin/sys_compat \
	/system/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat
do
	if [ -e "$p" ] || [ -L "$p" ]; then
		rm -f "$p" || true
	fi
done
find /boot /system -name 'sys_compat' 2>/dev/null | while read f; do
	if [ "$f" != "$USERBIN" ] && [ "$f" != "$USERDEV" ]; then
		rm -f "$f" || true
	fi
done
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
curl -s -o /boot/home/hello_tty "$HOST/payload/tests/hello_tty"
curl -s -o /boot/home/run_tty.sh "$HOST/scripts/guest_run_tty.sh"
chmod 755 /boot/home/hello_tty /boot/home/run_tty.sh
echo GO_TTY_DONE | tee /tmp/go_tty_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_tty_done.txt "$HOST/results/go_tty_done.txt" || true
echo GO_TTY_DONE
echo "[+] driverinstall already re-hooks LSTAR; reboot only if an old addon is still last"
# Haiku has no reboot(1). Use: shutdown -r

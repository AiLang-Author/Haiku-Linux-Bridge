#!/bin/sh
# Rebuild poll trap (kernel wait_for_objects_etc; ELF nfds==1).
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
grep -n 'PR45' sys_compat_dev.cpp || echo 'NO_PR45_IN_SRC'
grep -n 'gPollSnap' syscall_hook.S || echo 'NO_POLLSNAP'
rm -rf objects.* *.o objects 2>/dev/null || true
make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
USERBIN=/boot/home/config/non-packaged/add-ons/kernel/drivers/bin/sys_compat
USERDEV=/boot/home/config/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat
BUILT=$(ls -t objects.*/sys_compat 2>/dev/null | head -1)
mkdir -p "$(dirname "$USERBIN")" "$(dirname "$USERDEV")"
if [ -n "$BUILT" ] && [ -f "$BUILT" ]; then
	cp -f "$BUILT" "$USERBIN"
fi
ln -sfn "$USERBIN" "$USERDEV"
rm -f /boot/system/non-packaged/add-ons/kernel/drivers/bin/sys_compat \
	/boot/system/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat 2>/dev/null || true
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
curl -s -o /boot/home/hello_poll "$HOST/payload/tests/hello_poll"
curl -s -o /boot/home/run_poll.sh "$HOST/scripts/guest_run_poll.sh"
chmod 755 /boot/home/hello_poll /boot/home/run_poll.sh
echo GO_POLL_BUILT | tee /tmp/go_poll_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_poll_built.txt "$HOST/results/go_poll_built.txt" || true
sh /boot/home/run_poll.sh
echo GO_POLL_DONE | tee /tmp/go_poll_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_poll_done.txt "$HOST/results/go_poll_done.txt" || true
echo GO_POLL_DONE

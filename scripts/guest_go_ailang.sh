#!/bin/sh
# PR54: 768MB arena + /proc/self/exe; run ailang.x on Haiku.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
hey -o debug_server quit of Window "Crashed program" 2>/dev/null || true
hey -o debug_server quit of Window 0 2>/dev/null || true
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr54.cpp"
curl -s -o syscall_hook.S "$HOST/src/syscall_hook_pr54.S"
curl -s -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54.c"
for f in sys_compat_abi.h Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
grep -n 'PR54' sys_compat_dev.cpp || echo 'NO_PR54'
grep -n '768u' sys_compat_run.c || echo 'NO_ARENA768'
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
mkdir -p /boot/home/Librarys
curl -s -o /boot/home/ailang.x "$HOST/payload/ailang/ailang.x"
curl -s -o /boot/home/hi.ailang "$HOST/payload/ailang/hi.ailang"
curl -s -o /boot/home/Librarys/Library.Arena.ailang "$HOST/payload/ailang/Librarys/Library.Arena.ailang"
chmod 755 /boot/home/ailang.x
echo GO_AILANG_BUILT | tee /tmp/go_ailang_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_ailang_built.txt "$HOST/results/go_ailang_built.txt" || true
echo "=== ailang usage ==="
/boot/home/sys_compat_run /boot/home/ailang.x; echo AILANG_HELP_RC=$?
echo "=== ailang compile hi.ailang ==="
/boot/home/sys_compat_run /boot/home/ailang.x /boot/home/hi.ailang /boot/home/hi.x
echo AILANG_CC_RC=$?
ls -l /boot/home/hi.x 2>/dev/null || echo NO_HI_X
echo GO_AILANG_DONE | tee /tmp/go_ailang_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_ailang_done.txt "$HOST/results/go_ailang_done.txt" || true
echo GO_AILANG_DONE

#!/bin/sh
# PR54u: mmap worker, B_STACK_AREA overcommit, no DONT_COMMIT (kernel read).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s --max-time 30 -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr54u.cpp"
curl -s --max-time 30 -o syscall_hook.S "$HOST/src/syscall_hook_pr54u.S"
curl -s --max-time 30 -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54u.c"
for f in sys_compat_abi.h Makefile.driver; do
	curl -s --max-time 15 -o "$f" "$HOST/src/$f"
done
grep -n 'PR54u' sys_compat_dev.cpp || echo 'NO_PR54U'
grep -n 'Do not CREATE_AREA_DONT_COMMIT' sys_compat_dev.cpp || echo 'NO_NOTE'
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
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
echo GO_PR54U_BUILT | tee /tmp/go_pr54u_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54u_built.txt "$HOST/results/go_pr54u_built.txt" || true
echo GO_PR54U_BUILT

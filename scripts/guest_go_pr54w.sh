#!/bin/sh
# PR54w: mmap ANON = create_area_etc on the syscall thread (not worker).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s --max-time 30 -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr54w.cpp"
curl -s --max-time 30 -o syscall_hook.S "$HOST/src/syscall_hook_pr54w.S"
curl -s --max-time 30 -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54w.c"
for f in sys_compat_abi.h Makefile.driver; do
	curl -s --max-time 15 -o "$f" "$HOST/src/$f"
done
grep -n 'PR54w' sys_compat_dev.cpp || echo 'NO_PR54W'
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
echo GO_PR54W_BUILT | tee /tmp/go_pr54w_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54w_built.txt "$HOST/results/go_pr54w_built.txt" || true
echo GO_PR54W_BUILT

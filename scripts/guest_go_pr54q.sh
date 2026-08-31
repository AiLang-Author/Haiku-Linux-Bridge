#!/bin/sh
# PR54q: cap 8..128MB ANON mmap to 4MB; log Mz=size; 2GB arena; install.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr54q.cpp"
curl -s -o syscall_hook.S "$HOST/src/syscall_hook_pr54q.S"
curl -s -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54q.c"
for f in sys_compat_abi.h Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
grep -n 'PR54q' sys_compat_dev.cpp || echo 'NO_PR54Q'
grep -n 'Mz=' sys_compat_dev.cpp || echo 'NO_MZ'
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
echo GO_PR54Q_BUILT | tee /tmp/go_pr54q_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54q_built.txt "$HOST/results/go_pr54q_built.txt" || true
echo GO_PR54Q_BUILT

#!/bin/sh
# PR54q: POST Desktop reports, then cap-8-128MB driver install.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"

ls -l /boot/home/Desktop > /tmp/deskls.txt
ls -l /boot/home/Desktop/*.report /boot/home/*.report >> /tmp/deskls.txt 2>/dev/null || true
curl -s --max-time 8 -X POST --data-binary @/tmp/deskls.txt "$HOST/results/deskls_q.txt" || true
n=1
for f in /boot/home/Desktop/*.report /boot/home/*.report; do
	if [ -f "$f" ]; then
		bn=$(basename "$f")
		echo "POST $bn"
		curl -s --max-time 8 -X POST --data-binary @"$f" "$HOST/results/deskq_${n}_${bn}" || true
		n=$((n+1))
	fi
done

SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s --max-time 30 -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr54q.cpp"
curl -s --max-time 30 -o syscall_hook.S "$HOST/src/syscall_hook_pr54q.S"
curl -s --max-time 30 -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54q.c"
for f in sys_compat_abi.h Makefile.driver; do
	curl -s --max-time 15 -o "$f" "$HOST/src/$f"
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

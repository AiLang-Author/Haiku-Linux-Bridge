#!/bin/sh
# Dump in-situ clone, re-run hello_world, compile tracked CAD demo_anchors.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd /boot/home
echo GO_GIT55B_GO | tee /tmp/go_git55b_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git55b_go.txt "$HOST/results/go_git55b_go.txt" || true

{
	echo "=== dest ==="
	ls -la "$DEST" | head -40
	echo "=== git ==="
	if [ -d "$DEST/.git" ]; then
		(cd "$DEST" && git log -1 --oneline && git rev-parse HEAD && git status -sb | head)
		echo GIT_CLONE_OK=1
	else
		echo NO_GIT_DIR
	fi
	echo "=== df ==="
	df -h
	echo "=== bins ==="
	ls -l /boot/home/ailang_new.x /boot/home/hello_world.x /boot/home/hello_sys.x \
		/boot/home/sys_compat_run 2>/dev/null
	echo "=== sources ==="
	ls -l "$DEST/Demo Programs/programs/001_hello_world.ailang" \
		"$DEST/CAD/demo_anchors.ailang" \
		"$DEST/Librarys/Library.Arena.ailang" \
		"$DEST/Librarys/Cad/Library.CAD_Sys.ailang" 2>/dev/null
} > /tmp/git55b_info.txt 2>&1
cat /tmp/git55b_info.txt
curl -s --max-time 15 -X POST --data-binary @/tmp/git55b_info.txt "$HOST/results/git55b_info.txt" || true

cd "$DEST" || exit 1

echo "=== re-run hello_world ==="
if [ -x /boot/home/hello_world.x ]; then
	/boot/home/sys_compat_run /boot/home/hello_world.x
	echo HELLORUN_RC=$?
else
	echo "=== compile 001_hello_world ==="
	/boot/home/sys_compat_run /boot/home/ailang_new.x \
		"Demo Programs/programs/001_hello_world.ailang" \
		/boot/home/hello_world.x
	echo HELLOCC_RC=$?
	ls -l /boot/home/hello_world.x
	/boot/home/sys_compat_run /boot/home/hello_world.x
	echo HELLORUN_RC=$?
fi

echo "=== compile CAD/demo_anchors ==="
/boot/home/sys_compat_run /boot/home/ailang_new.x \
	CAD/demo_anchors.ailang \
	/boot/home/demo_anchors.x
echo ANCHORCC_RC=$?
ls -l /boot/home/demo_anchors.x 2>/dev/null || echo NO_ANCHORS_X

echo "=== run demo_anchors ==="
/boot/home/sys_compat_run /boot/home/demo_anchors.x
echo ANCHORRUN_RC=$?

echo GO_GIT55B_DONE | tee /tmp/go_git55b_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git55b_done.txt "$HOST/results/go_git55b_done.txt" || true
echo GO_GIT55B_DONE

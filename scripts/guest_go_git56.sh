#!/bin/sh
# GIT56: compiler reads /boot/home/Librarys via /proc/self/exe.
# That tree was a curl copy and is missing Cad/SketchProfile/ProfIR.
# Point it at the GitHub clone so nested imports match Linux.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
echo GO_GIT56_GO | tee /tmp/go_git56_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git56_go.txt "$HOST/results/go_git56_go.txt" || true

{
	echo "=== home Librarys (exe-relative, what ailang.x actually opens) ==="
	ls -ld /boot/home/Librarys
	ls -la /boot/home/Librarys/Cad/SketchProfile/ 2>&1
	echo "=== CAD_SketchProfile in home Librarys ==="
	sed -n '1,20p' /boot/home/Librarys/Cad/Library.CAD_SketchProfile.ailang 2>&1
	echo "=== git clone SketchProfile ==="
	ls -la "$DEST/Librarys/Cad/SketchProfile/" 2>&1
	echo "=== CAD_SketchProfile in git clone ==="
	sed -n '1,20p' "$DEST/Librarys/Cad/Library.CAD_SketchProfile.ailang" 2>&1
	echo "=== git HEAD ==="
	if [ -d "$DEST/.git" ]; then
		(cd "$DEST" && git log -1 --oneline && git rev-parse HEAD && git status -sb | head)
	else
		echo NO_GIT_DIR
	fi
} > /tmp/git56_before.txt 2>&1
cat /tmp/git56_before.txt
curl -s --max-time 15 -X POST --data-binary @/tmp/git56_before.txt "$HOST/results/git56_before.txt" || true

export GIT_SSL_NO_VERIFY=1
if [ ! -d "$DEST/.git" ]; then
	echo NO_CLONE
	echo GO_GIT56_FAIL | tee /tmp/go_git56_done.txt
	curl -s --max-time 8 -X POST --data-binary @/tmp/go_git56_done.txt "$HOST/results/go_git56_done.txt" || true
	exit 1
fi

cd "$DEST" || exit 1
git -c http.sslVerify=false fetch --depth 1 origin master
git reset --hard origin/master
git log -1 --oneline
git rev-parse HEAD
echo GO_GIT56_PULL | tee /tmp/go_git56_pull.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git56_pull.txt "$HOST/results/go_git56_pull.txt" || true

# Replace the half-copied Librarys with the git tree. Compiler binary lives
# at /boot/home/ailang*.x so Import_FindLibBase uses /boot/home/Librarys.
if [ -L /boot/home/Librarys ]; then
	echo LIB_ALREADY_SYMLINK
	ls -ld /boot/home/Librarys
else
	if [ -d /boot/home/Librarys ]; then
		rm -rf /boot/home/Librarys.curlcopy
		mv /boot/home/Librarys /boot/home/Librarys.curlcopy
	fi
	ln -s "$DEST/Librarys" /boot/home/Librarys
fi
ls -ld /boot/home/Librarys
ls -la /boot/home/Librarys/Cad/SketchProfile/
grep -n ProfIR /boot/home/Librarys/Cad/Library.CAD_SketchProfile.ailang
test -f /boot/home/Librarys/Cad/SketchProfile/Library.ProfIR.ailang && echo PROFIR_PRESENT
df -h

echo GO_GIT56_LINK | tee /tmp/go_git56_link.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git56_link.txt "$HOST/results/go_git56_link.txt" || true

# Nested import only: CAD_SketchProfile pulls Loop/Tess/Snap/ProfIR.
printf '%s\n' \
	'LibraryImport.Cad.CAD_SketchProfile' \
	'SubRoutine.Main { }' \
	'RunTask(Main)' > /tmp/hi_nest.ailang

echo "=== nest compile (CAD_SketchProfile -> ProfIR) ==="
/boot/home/sys_compat_run /boot/home/ailang_new.x /tmp/hi_nest.ailang /tmp/hi_nest.x
echo NESTCC_RC=$?
ls -l /tmp/hi_nest.x 2>/dev/null || echo NO_NEST_X
echo GO_GIT56_NEST | tee /tmp/go_git56_nest.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git56_nest.txt "$HOST/results/go_git56_nest.txt" || true

echo "=== cad_app compile ==="
cd "$DEST" || exit 1
/boot/home/sys_compat_run /boot/home/ailang_new.x CAD/cad_app.ailang /boot/home/cad_app.x
echo CADCC_RC=$?
ls -l /boot/home/cad_app.x 2>/dev/null || echo NO_CAD_APP

# Free the stale copy after the compile so a miss still has a fallback.
if [ -d /boot/home/Librarys.curlcopy ]; then
	rm -rf /boot/home/Librarys.curlcopy
	echo CURLCOPY_REMOVED
fi
df -h

echo GO_GIT56_DONE | tee /tmp/go_git56_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git56_done.txt "$HOST/results/go_git56_done.txt" || true
echo GO_GIT56_DONE

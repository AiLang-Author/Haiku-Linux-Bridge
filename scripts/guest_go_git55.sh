#!/bin/sh
# Clone Ailang on Haiku via git, compile+run a demo in situ with ailang_new.x.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
cd /boot/home
echo GO_GIT55_GO | tee /tmp/go_git55_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git55_go.txt "$HOST/results/go_git55_go.txt" || true

echo "=== probe ==="
date
df -h
echo "---bins---"
ls -l /boot/home/ailang_new.x /boot/home/sys_compat_run /boot/home/ailang.x
echo "---git---"
command -v git
git --version || echo NO_GIT
command -v pkgman
echo "---net---"
curl -sI --max-time 12 "$HOST/health" | head -3
curl -skI --max-time 20 https://github.com/ | head -5 || echo NO_GITHUB_HEAD

if ! command -v git >/dev/null 2>&1; then
	echo NEED_GIT_PKG
	pkgman install -y git || pkgman --yes install git || yes | pkgman install git
	command -v git
	git --version || echo STILL_NO_GIT
fi

echo GO_GIT55_PROBE | tee /tmp/go_git55_probe.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git55_probe.txt "$HOST/results/go_git55_probe.txt" || true

DEST=/boot/home/Ailang-Self-Hosting-
rm -rf "$DEST"
export GIT_SSL_NO_VERIFY=1
CLONE_RC=1
if command -v git >/dev/null 2>&1; then
	echo "=== git clone --depth 1 ==="
	git -c http.sslVerify=false clone --depth 1 \
		https://github.com/AiLang-Author/Ailang-Self-Hosting-.git \
		"$DEST"
	CLONE_RC=$?
	echo CLONE_RC=$CLONE_RC
fi

if [ "$CLONE_RC" != "0" ] || [ ! -d "$DEST/.git" ]; then
	echo "=== fallback tarball ==="
	mkdir -p "$DEST"
	curl -s --max-time 60 -o /boot/home/insitu_src_git55.tgz \
		"$HOST/payload/ailang/insitu_src_git55.tgz"
	(cd "$DEST" && tar -xzf /boot/home/insitu_src_git55.tgz)
	echo TAR_RC=$?
	echo FALLBACK_TAR=1
else
	echo GIT_CLONE_OK=1
	(cd "$DEST" && git log -1 --oneline && git rev-parse --short HEAD)
fi

echo "=== tree ==="
ls -la "$DEST" | head -30
df -h
ls "$DEST/Demo Programs/programs/001_hello_world.ailang" \
	"$DEST/Librarys/Library.Arena.ailang" \
	"$DEST/CAD/hello_sys.ailang" 2>/dev/null || echo MISSING_SRC

echo GO_GIT55_TREE | tee /tmp/go_git55_tree.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git55_tree.txt "$HOST/results/go_git55_tree.txt" || true

cd "$DEST" || exit 1

echo "=== compile 001_hello_world ==="
/boot/home/sys_compat_run /boot/home/ailang_new.x \
	"Demo Programs/programs/001_hello_world.ailang" \
	/boot/home/hello_world.x
echo HELLOCC_RC=$?
ls -l /boot/home/hello_world.x 2>/dev/null || echo NO_HELLO_X

echo "=== run hello_world ==="
/boot/home/sys_compat_run /boot/home/hello_world.x
echo HELLORUN_RC=$?

echo "=== compile CAD/hello_sys ==="
/boot/home/sys_compat_run /boot/home/ailang_new.x \
	CAD/hello_sys.ailang \
	/boot/home/hello_sys.x
echo SYSCC_RC=$?
ls -l /boot/home/hello_sys.x 2>/dev/null || echo NO_SYS_X

echo "=== run hello_sys ==="
/boot/home/sys_compat_run /boot/home/hello_sys.x
echo SYSRUN_RC=$?

echo GO_GIT55_DONE | tee /tmp/go_git55_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_git55_done.txt "$HOST/results/go_git55_done.txt" || true
echo GO_GIT55_DONE

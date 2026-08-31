#!/bin/sh
# Fetch PostgreSQL 18.4, apply HaikuPorts patches, make check.
# Official suite: src/test/regress (make check). check-world is later.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/postgresql-18.4
LOG=/boot/home/pgcheck.log
PATCH=/boot/home/haikuports/dev-db/postgresql/patches/postgresql18-18.4.patchset
export PGGSSENCMODE=disable PGSSLMODE=disable
export PAGER=cat
: > "$LOG"
exec >>"$LOG" 2>&1
post() {
	curl -s --max-time 20 -X POST --data-binary @"$LOG" "$HOST/results/pgcheck.log" || true
	echo "$1" | curl -s --max-time 8 -X POST --data-binary @- "$HOST/results/pgcheck_stat.txt" || true
}

post START
# don't let leftover psql eat the box
kill -9 $(ps | awk '/psql/ && !/awk/ {print $2}') 2>/dev/null || true

echo "=== fetch tarball ==="
cd /boot/home
if [ ! -f postgresql-18.4.tar.bz2 ]; then
	curl -fL --retry 3 -o postgresql-18.4.tar.bz2 "$HOST/downloads/pg/postgresql-18.4.tar.bz2"
fi
ls -l postgresql-18.4.tar.bz2
post TARBALL

if [ ! -d "$SRC/src" ]; then
	rm -rf "$SRC"
	tar xjf postgresql-18.4.tar.bz2
fi
post EXTRACT

echo "=== apply HaikuPorts patchset ==="
cd "$SRC"
if [ ! -f .haiku_patched ]; then
	if git apply --check "$PATCH" 2>/tmp/apply_check.txt; then
		git apply "$PATCH"
	else
		cat /tmp/apply_check.txt
		# mailbox format: try git am in a throwaway repo
		git init
		git add -A
		git -c user.email=pg@haiku -c user.name=pg commit -m base
		git am "$PATCH"
	fi
	touch src/template/haiku
	touch .haiku_patched
fi
post PATCHED

echo "=== autoconf ==="
libtoolize --force --copy --install || true
autoconf
post AUTOCONF

echo "=== configure ==="
CFLAGS="-D_BSD_SOURCE -O2" LDFLAGS="-lnetwork" \
	./configure \
		--prefix=/boot/home/pg-prefix \
		--bindir=/boot/home/pg-prefix/bin \
		--with-icu \
		--with-ldap \
		--with-libxml \
		--with-libxslt \
		--with-openssl \
		--with-pam \
		--with-template=haiku \
		--disable-static
echo CONFIGURE_RC=$?
post CONFIGURED

echo "=== make -j4 ==="
make -j4
echo MAKE_RC=$?
post BUILT

echo "=== make check (src/test/regress) ==="
# extra conf: if BFS fsync hangs, tests never finish. log both.
# first try as the port ships (this is the honest test)
make check
echo CHECK_RC=$?
post CHECK_DONE

if [ -f src/test/regress/regression.diffs ]; then
	curl -s --max-time 30 -X POST --data-binary @src/test/regress/regression.diffs \
		"$HOST/results/regression.diffs" || true
fi
ls -l src/test/regress/regression.out src/test/regress/regression.diffs 2>/dev/null
tail -80 src/test/regress/regression.out 2>/dev/null
echo PGCHECK_FINISHED
post PGCHECK_FINISHED

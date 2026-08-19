#!/bin/sh
# Host-side: busybox applets under strace -c.
# Emits unique Linux syscall names they actually issue.
# License: Public Domain / CC0 1.0 Universal
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BB="$ROOT/payload/tests/busybox"
OUTDIR="$ROOT/results/ltp"
WORKDIR=/tmp/bbfix
mkdir -p "$OUTDIR" "$WORKDIR"
cd "$WORKDIR"
rm -rf work
mkdir -p work/sub
printf 'hello world\nfoo bar\nhello linux\nzzz\n' > work/a.txt
printf 'hello world\nfoo bar\n' > work/b.txt
cp work/a.txt work/c.txt
ln -sf a.txt work/link.txt
"$BB" gzip -c work/a.txt > work/a.txt.gz
"$BB" tar -cf work/t.tar -C work a.txt

run() {
	name="$1"
	shift
	echo "=== $name ==="
	strace -c -f -o "$OUTDIR/strace_$name.txt" -- "$@" \
		>/tmp/bbfix/out."$name" 2>/tmp/bbfix/err."$name" || true
}

run echo "$BB" echo hello
run uname "$BB" uname -a
run cat "$BB" cat work/a.txt
run ls "$BB" ls -l work
run cp "$BB" cp work/a.txt work/cp.txt
run mv "$BB" mv work/cp.txt work/moved.txt
run ln "$BB" ln -sf a.txt work/ln2.txt
run readlink "$BB" readlink work/link.txt
run touch "$BB" touch work/touched
run rm "$BB" rm -f work/moved.txt
run date "$BB" date -u
run grep "$BB" grep hello work/a.txt
run sed "$BB" sed s/hello/hi/ work/a.txt
run wc "$BB" wc -l work/a.txt
run head "$BB" head -n 2 work/a.txt
run tail "$BB" tail -n 1 work/a.txt
run sort "$BB" sort work/a.txt
run cut "$BB" cut -d' ' -f1 work/a.txt
run awk "$BB" awk '{print $1}' work/a.txt
run find "$BB" find work -name '*.txt'
printf 'a.txt\n' | strace -c -f -o "$OUTDIR/strace_xargs.txt" -- \
	"$BB" xargs echo >/tmp/bbfix/out.xargs 2>/tmp/bbfix/err.xargs || true
run tr "$BB" sh -c 'tr a-z A-Z < work/a.txt'
run uniq "$BB" uniq work/a.txt
run tee "$BB" sh -c 'tee work/tee.txt < work/a.txt'
run cmp "$BB" cmp work/a.txt work/b.txt
run diff "$BB" diff work/a.txt work/b.txt
run test "$BB" test -f work/a.txt
run expr "$BB" expr 1 + 2
run seq "$BB" seq 1 3
run dd "$BB" dd if=work/a.txt of=work/dd.txt bs=4 count=2
run md5sum "$BB" md5sum work/a.txt
run sha256sum "$BB" sha256sum work/a.txt
run sha1sum "$BB" sha1sum work/a.txt
run base64 "$BB" base64 work/a.txt
run realpath "$BB" realpath work/a.txt
run mktemp "$BB" mktemp /tmp/bbfix/tmp.XXXXXX
run mkdir "$BB" mkdir -p work/d/e
run rmdir "$BB" rmdir work/d/e
run stat "$BB" stat work/a.txt
run chmod "$BB" chmod 644 work/a.txt
run od "$BB" od -An -tx1 work/a.txt
run hexdump "$BB" hexdump -C work/a.txt
run xxd "$BB" xxd work/a.txt
run strings "$BB" strings work/a.txt
run nl "$BB" nl work/a.txt
run paste "$BB" paste work/a.txt work/b.txt
run gzipc "$BB" gzip -c work/a.txt
run tarcf "$BB" tar -tf work/t.tar
run zcat "$BB" zcat work/a.txt.gz
run crc32 "$BB" crc32 work/a.txt
run env "$BB" env
run getopt "$BB" getopt -o ab: -- -a -b x
run factor "$BB" factor 12
run sync "$BB" sync
run truncate "$BB" truncate -s 8 work/trunc.txt
run sleep "$BB" sleep 0
run true "$BB" true
run false "$BB" false
run printf "$BB" printf '%s\n' hi
run dirname "$BB" dirname /tmp/x/y
run basename "$BB" basename /tmp/x/y
run pwd "$BB" pwd
run id "$BB" id
run nproc "$BB" nproc
run shfor "$BB" sh -c 'echo A; echo B'
run shredir "$BB" sh -c 'echo hi > /tmp/bbfix/redir.txt && cat /tmp/bbfix/redir.txt'
run shpipe "$BB" sh -c 'echo HI | cat'
run ar "$BB" ar -rc work/x.a work/a.txt

{
	echo "# Unique Linux syscalls from host strace -c of busybox applets"
	echo "# generated $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "# binary: $BB"
	for f in "$OUTDIR"/strace_*.txt; do
		[ -f "$f" ] || continue
		awk 'NF>=5 && $NF ~ /^[a-z_][a-z0-9_]*$/ && $1 ~ /^[0-9]/ {print $NF}' "$f"
	done | sort -u
} > "$OUTDIR/applet_syscalls_host.txt"
echo "=== unique syscalls ==="
grep -v '^#' "$OUTDIR/applet_syscalls_host.txt" || true
echo "count=$(grep -c '^[a-z]' "$OUTDIR/applet_syscalls_host.txt" || true)"
echo CATALOG_DONE

#!/bin/sh
# Guest: busybox applets via sys_compat_run.
# Fetch/POST with Haiku curl (BSD sockets). --max-time so a stuck
# POST cannot hang the script.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/applets.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
if [ ! -x "$BB" ]; then
	curl -s -o "$BB" "$HOST/payload/tests/busybox"
	chmod 755 "$BB"
fi
if [ ! -x "$RUN" ]; then
	echo NO_RUNNER
	exit 1
fi
W=/tmp/apfix
rm -rf "$W"
mkdir -p "$W/sub"
printf 'hello world\nfoo bar\nhello linux\nzzz\n' > "$W/a.txt"
printf 'hello world\nfoo bar\n' > "$W/b.txt"
cp "$W/a.txt" "$W/c.txt"
ln -s a.txt "$W/link.txt"

rc_of() {
	name="$1"
	shift
	echo "=== $name ==="
	$RUN "$@"
	echo "${name}_RC=$?"
}

{
	echo "=== applets start ==="
	rc_of ECHO $BB echo hello
	rc_of UNAME $BB uname -a
	rc_of CAT $BB cat "$W/a.txt"
	rc_of LS $BB ls -l "$W"
	rc_of CP $BB cp "$W/a.txt" "$W/cp.txt"
	rc_of MV $BB mv "$W/cp.txt" "$W/moved.txt"
	rc_of LN $BB ln -sf a.txt "$W/ln2.txt"
	rc_of READLINK $BB readlink "$W/link.txt"
	rc_of TOUCH $BB touch "$W/touched"
	rc_of RM $BB rm -f "$W/moved.txt"
	rc_of DATE $BB date -u
	rc_of GREP $BB grep hello "$W/a.txt"
	rc_of SED $BB sed s/hello/hi/ "$W/a.txt"
	rc_of WC $BB wc -l "$W/a.txt"
	rc_of HEAD $BB head -n 2 "$W/a.txt"
	rc_of TAIL $BB tail -n 1 "$W/a.txt"
	rc_of SORT $BB sort "$W/a.txt"
	rc_of CUT $BB cut -d' ' -f1 "$W/a.txt"
	rc_of AWK $BB awk '{print $1}' "$W/a.txt"
	rc_of FIND $BB find "$W" -name '*.txt'
	rc_of TR $BB sh -c "tr a-z A-Z < $W/a.txt"
	rc_of UNIQ $BB uniq "$W/a.txt"
	rc_of TEE $BB sh -c "tee $W/tee.txt < $W/a.txt"
	rc_of CMP $BB cmp "$W/a.txt" "$W/b.txt"
	rc_of DIFF $BB diff "$W/a.txt" "$W/b.txt"
	rc_of TEST $BB test -f "$W/a.txt"
	rc_of EXPR $BB expr 1 + 2
	rc_of SEQ $BB seq 1 3
	rc_of DD $BB dd if="$W/a.txt" of="$W/dd.txt" bs=4 count=2
	rc_of MD5 $BB md5sum "$W/a.txt"
	rc_of SHA256 $BB sha256sum "$W/a.txt"
	rc_of SHA1 $BB sha1sum "$W/a.txt"
	rc_of B64 $BB base64 "$W/a.txt"
	rc_of REALPATH $BB realpath "$W/a.txt"
	rc_of MKTEMP $BB mktemp /tmp/apfix/tmp.XXXXXX
	rc_of MKDIR $BB mkdir -p "$W/d/e"
	rc_of RMDIR $BB rmdir "$W/d/e"
	rc_of STAT $BB stat "$W/a.txt"
	rc_of CHMOD $BB chmod 644 "$W/a.txt"
	rc_of OD $BB od -An -tx1 "$W/a.txt"
	rc_of HEXDUMP $BB hexdump -C "$W/a.txt"
	rc_of XXD $BB xxd "$W/a.txt"
	rc_of STRINGS $BB strings "$W/a.txt"
	rc_of NL $BB nl "$W/a.txt"
	rc_of PASTE $BB paste "$W/a.txt" "$W/b.txt"
	rc_of TARCF $BB tar -cf "$W/t.tar" -C "$W" a.txt
	rc_of TARTF $BB tar -tf "$W/t.tar"
	$BB gzip -c "$W/a.txt" > "$W/a.txt.gz" || true
	rc_of ZCAT $BB zcat "$W/a.txt.gz"
	rc_of CRC32 $BB crc32 "$W/a.txt"
	rc_of ENV $BB env
	rc_of GETOPT $BB getopt -o ab: -- -a -b x
	rc_of FACTOR $BB factor 12
	rc_of SYNC $BB sync
	rc_of TRUNC $BB truncate -s 8 "$W/trunc.txt"
	rc_of SLEEP $BB sleep 0
	rc_of TRUE $BB true
	rc_of FALSE $BB false
	rc_of PRINTF $BB printf '%s\n' hi
	rc_of DIRNAME $BB dirname /tmp/x/y
	rc_of BASENAME $BB basename /tmp/x/y
	rc_of PWD $BB pwd
	rc_of ID $BB id
	rc_of NPROC $BB nproc
	rc_of SHFOR $BB sh -c 'echo A; echo B'
	rc_of SHREDIR $BB sh -c "echo hi > $W/redir.txt && cat $W/redir.txt"
	rc_of SHPIPE $BB sh -c 'echo HI | cat'
	rc_of AR $BB ar -rc "$W/x.a" "$W/a.txt"
	echo "=== applets end ==="
} > "$OUT" 2>&1
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/applets_out.txt" || true
echo RUN_APPLETS_DONE

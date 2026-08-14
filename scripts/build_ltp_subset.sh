#!/usr/bin/env bash
# Configure LTP and statically compile the curated sys_compat syscall subset.
# License: Public Domain / CC0 1.0 Universal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LTP_DIR="${BASE_DIR}/downloads/ltp"
STAGE_DIR="${BASE_DIR}/downloads/ltp-stage"
PAYLOAD_DIR="${BASE_DIR}/payload/ltp"
RUNLIST="${BASE_DIR}/tests/ltp_sys_compat.run"
SYSCALL_ROOT="${LTP_DIR}/testcases/kernel/syscalls"

if [ ! -d "${LTP_DIR}/.git" ]; then
    echo "[-] LTP not found. Run ${SCRIPT_DIR}/download_ltp.sh first." >&2
    exit 1
fi

if [ ! -f "${RUNLIST}" ]; then
    echo "[-] Missing runlist ${RUNLIST}" >&2
    exit 1
fi

mapfile -t TESTS < <(awk 'NF && $1 !~ /^#/ { print $1 }' "${RUNLIST}")
if [ "${#TESTS[@]}" -eq 0 ]; then
    echo "[-] Runlist ${RUNLIST} is empty." >&2
    exit 1
fi

echo "=================================================================="
echo " Building ${#TESTS[@]} LTP syscall tests for sys_compat"
echo "=================================================================="

# Resolve each test binary to its source directory (search by .c name first).
declare -A DIRS=()
for test_name in "${TESTS[@]}"; do
    found=""
    match="$(find "${SYSCALL_ROOT}" -maxdepth 2 -type f -name "${test_name}.c" -printf '%P\n' | head -1 || true)"
    if [ -n "${match}" ]; then
        found="$(dirname "${match}")"
    elif [ -d "${SYSCALL_ROOT}/${test_name}" ]; then
        found="${test_name}"
    fi
    if [ -z "${found}" ] || [ "${found}" = "." ]; then
        echo "[!] Could not locate source dir for ${test_name}"
        continue
    fi
    DIRS["${found}"]=1
    echo "    ${test_name}  <-  syscalls/${found}"
done

echo "[1/4] Generating configure (make autotools)..."
(
    cd "${LTP_DIR}"
    if [ ! -x ./configure ]; then
        make autotools
    fi
)

echo "[2/4] Configuring LTP (static, no POSIX/realtime extras)..."
(
    cd "${LTP_DIR}"
    if [ ! -f include/mk/config.mk ]; then
        if ! ./configure \
            --prefix="${STAGE_DIR}" \
            --without-open-posix-testsuite \
            --without-realtime-testsuite \
            --without-numa \
            LDFLAGS="-static" \
            CFLAGS="-O2 -g -static"; then
            echo "[!] Static configure failed; retrying dynamic (sys_compat dynamic linker is still WIP)."
            rm -f include/mk/config.mk include/config.h
            ./configure \
                --prefix="${STAGE_DIR}" \
                --without-open-posix-testsuite \
                --without-realtime-testsuite \
                --without-numa
        fi
    else
        echo "    already configured (include/mk/config.mk exists)"
    fi
)

echo "[3/4] Building LTP library + selected syscall dirs..."
make -C "${LTP_DIR}" -j"$(getconf _NPROCESSORS_ONLN)" lib-all

failed=0
for dir in "${!DIRS[@]}"; do
    echo "    make syscalls/${dir}"
    if ! make -C "${LTP_DIR}/testcases/kernel/syscalls/${dir}" -j"$(getconf _NPROCESSORS_ONLN)"; then
        echo "[!] build failed: ${dir}"
        failed=$((failed + 1))
    fi
done

echo "[4/4] Staging binaries into payload/ltp/bin ..."
mkdir -p "${PAYLOAD_DIR}/bin" "${STAGE_DIR}/bin"
copied=0
missing=0
for test_name in "${TESTS[@]}"; do
    bin="$(find "${SYSCALL_ROOT}" -maxdepth 2 -type f -name "${test_name}" -perm -111 | head -1 || true)"
    if [ -z "${bin}" ]; then
        echo "[!] missing binary: ${test_name}"
        missing=$((missing + 1))
        continue
    fi
    cp -f "${bin}" "${PAYLOAD_DIR}/bin/${test_name}"
    cp -f "${bin}" "${STAGE_DIR}/bin/${test_name}"
    copied=$((copied + 1))
done

cp -f "${RUNLIST}" "${PAYLOAD_DIR}/ltp_sys_compat.run"
cp -f "${RUNLIST}" "${STAGE_DIR}/ltp_sys_compat.run"

# Guest-side runner: fetch is optional; this copy rides the FAT payload too.
cat > "${PAYLOAD_DIR}/run_guest.sh" << 'EOF'
#!/bin/sh
# Run staged LTP binaries through sys_compat_run and emit a single results file.
set -eu
LTP_DIR="${LTP_DIR:-/boot/home/ltp}"
OUT="${OUT:-/boot/home/ltp_results.txt}"
RUNNER=""
for cand in /boot/home/sys_compat_run /boot/home/tests/sys_compat_run /payload/tests/sys_compat_run; do
    if [ -x "$cand" ]; then
        RUNNER="$cand"
        break
    fi
done
if [ -z "$RUNNER" ]; then
    echo "FATAL: sys_compat_run not found" | tee "$OUT"
    exit 1
fi

: > "$OUT"
echo "LTP sys_compat guest run $(date)" >> "$OUT"
echo "runner=$RUNNER" >> "$OUT"
echo "========================================" >> "$OUT"

pass=0
fail=0
skip=0
for bin in "$LTP_DIR"/bin/*; do
    [ -f "$bin" ] || continue
    name="$(basename "$bin")"
    echo "----- $name -----" | tee -a "$OUT"
    chmod +x "$bin" 2>/dev/null || true
    set +e
    "$RUNNER" "$bin" >> "$OUT" 2>&1
    rc=$?
    set -e
    echo "EXIT:$name=$rc" | tee -a "$OUT"
    case "$rc" in
        0) pass=$((pass + 1)) ;;
        4|32) skip=$((skip + 1)) ;;
        *) fail=$((fail + 1)) ;;
    esac
done

echo "========================================" >> "$OUT"
echo "SUMMARY pass=$pass fail=$fail skip=$skip" | tee -a "$OUT"

if command -v curl >/dev/null 2>&1; then
    curl -sS -X POST --data-binary @"$OUT" "http://10.0.2.2:8083/results/ltp_results.txt" || true
fi
EOF
chmod +x "${PAYLOAD_DIR}/run_guest.sh"

echo
echo "[+] staged ${copied} binaries  (missing=${missing}, dir-build-fail=${failed})"
echo "[+] payload: ${PAYLOAD_DIR}"
echo "[+] host bin: ${STAGE_DIR}/bin"
echo "=================================================================="

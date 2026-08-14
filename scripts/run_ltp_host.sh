#!/usr/bin/env bash
# Run the staged LTP subset natively on Linux as a gold baseline.
# Uses kirk when available; otherwise execs each binary directly.
# License: Public Domain / CC0 1.0 Universal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
STAGE_DIR="${BASE_DIR}/downloads/ltp-stage"
KIRK="${BASE_DIR}/downloads/ltp/tools/kirk/kirk-src/kirk"
RUNLIST="${BASE_DIR}/tests/ltp_sys_compat.run"
RESULT_DIR="${BASE_DIR}/results/ltp"
OUT="${RESULT_DIR}/ltp_host_baseline.txt"

mkdir -p "${RESULT_DIR}"

if [ ! -d "${STAGE_DIR}/bin" ]; then
    echo "[-] No staged binaries. Run ${SCRIPT_DIR}/build_ltp_subset.sh first." >&2
    exit 1
fi

if [ -x "${KIRK}" ]; then
    echo "[+] kirk is available for QEMU/SSH/network runs:"
    echo "    ${KIRK} --help"
    echo "    Linux-QEMU baseline example:"
    echo "      ${KIRK} --com qemu:image=PATH.qcow2:user=root:password=root \\"
    echo "              --sut default:com=qemu --run-suite syscalls"
    echo
fi

echo "[+] Running staged LTP subset on this Linux host -> ${OUT}"
: > "${OUT}"
pass=0
fail=0
skip=0

while read -r name cmd; do
    [[ -z "${name}" || "${name}" == \#* ]] && continue
    bin="${STAGE_DIR}/bin/${name}"
    if [ ! -x "${bin}" ]; then
        echo "SKIP ${name} (binary missing)" | tee -a "${OUT}"
        skip=$((skip + 1))
        continue
    fi
    echo "----- ${name} -----" | tee -a "${OUT}"
    set +e
    "${bin}" >> "${OUT}" 2>&1
    rc=$?
    set -e
    echo "EXIT:${name}=${rc}" | tee -a "${OUT}"
    case "${rc}" in
        0) pass=$((pass + 1)) ;;
        4|32) skip=$((skip + 1)) ;;
        *) fail=$((fail + 1)) ;;
    esac
done < "${RUNLIST}"

echo "SUMMARY pass=${pass} fail=${fail} skip=${skip}" | tee -a "${OUT}"

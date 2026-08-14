#!/usr/bin/env bash
# Download the Linux Test Project (LTP) syscall suite and the kirk QEMU/network runner.
# License: Public Domain / CC0 1.0 Universal
#
# LTP itself is GPL-2.0-or-later and is kept under downloads/ (gitignored).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DOWNLOAD_DIR="${BASE_DIR}/downloads"
LTP_DIR="${DOWNLOAD_DIR}/ltp"
KIRK_DIR="${LTP_DIR}/tools/kirk/kirk-src"

LTP_GIT_REPO="${LTP_GIT_REPO:-https://github.com/linux-test-project/ltp.git}"
KIRK_GIT_REPO="${KIRK_GIT_REPO:-https://github.com/linux-test-project/kirk.git}"

mkdir -p "${DOWNLOAD_DIR}"

echo "=================================================================="
echo " Linux Test Project downloader (syscall ABI suite + kirk runner)"
echo " Target: ${LTP_DIR}"
echo "=================================================================="

clone_or_update() {
    local url="$1"
    local dest="$2"
    local label="$3"

    if [ -d "${dest}/.git" ]; then
        echo "[+] ${label} already present. Fetching latest tip..."
        git -C "${dest}" fetch --depth 1 origin HEAD
        git -C "${dest}" reset --hard FETCH_HEAD
    else
        echo "[+] Cloning ${label} (depth=1) from ${url}..."
        rm -rf "${dest}"
        git clone --depth 1 --single-branch "${url}" "${dest}"
    fi
    echo "    HEAD: $(git -C "${dest}" log -1 --oneline)"
}

clone_or_update "${LTP_GIT_REPO}" "${LTP_DIR}" "LTP"
clone_or_update "${KIRK_GIT_REPO}" "${KIRK_DIR}" "kirk (QEMU / SSH / network executor)"

SYSCALL_DIRS="$(find "${LTP_DIR}/testcases/kernel/syscalls" -mindepth 1 -maxdepth 1 -type d | wc -l)"
RUNTEST_LINES="$(grep -cve '^#' -e '^$' "${LTP_DIR}/runtest/syscalls" || true)"

echo
echo "[+] LTP version:     $(tr -d '\n' < "${LTP_DIR}/VERSION")"
echo "[+] Syscall dirs:    ${SYSCALL_DIRS}"
echo "[+] syscalls runlist entries: ${RUNTEST_LINES}"
echo "[+] kirk runner:     ${KIRK_DIR}/kirk"
echo
echo "Next:"
echo "  ${SCRIPT_DIR}/build_ltp_subset.sh     # static-build the sys_compat subset"
echo "  python3 ${SCRIPT_DIR}/ltp_net_server.py &"
echo "  python3 ${SCRIPT_DIR}/run_ltp_haiku.py  # QEMU + network collect"
echo "=================================================================="

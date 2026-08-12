#!/usr/bin/env bash
# Script to clone Haiku buildtools and configure x86_64 cross-compilation
# License: Public Domain / CC0 1.0 Universal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DOWNLOAD_DIR="${BASE_DIR}/downloads"
BUILDTOOLS_DIR="${DOWNLOAD_DIR}/buildtools"
HAIKU_SRC_DIR="${DOWNLOAD_DIR}/haiku_sources"

BUILDTOOLS_REPO="https://git.haiku-os.org/buildtools"
BUILDTOOLS_GITHUB="https://github.com/haiku/buildtools.git"

echo "=================================================================="
echo " Haiku Buildtools & Cross-Compilation Configurator"
echo "=================================================================="

mkdir -p "${DOWNLOAD_DIR}"

if [ ! -d "${BUILDTOOLS_DIR}" ]; then
    echo "[1/2] Cloning Haiku buildtools repository..."
    git clone --depth 1 "${BUILDTOOLS_REPO}" "${BUILDTOOLS_DIR}" || \
    git clone --depth 1 "${BUILDTOOLS_GITHUB}" "${BUILDTOOLS_DIR}" || {
        echo "Error: Failed to clone buildtools repository." >&2
        exit 1
    }
else
    echo "[1/2] Buildtools repository already exists at ${BUILDTOOLS_DIR}"
fi

echo "[2/2] Running Haiku configure for x86_64 target..."
cd "${HAIKU_SRC_DIR}"

if [ -f "configure" ]; then
    ./configure --cross-tools-source "${BUILDTOOLS_DIR}" --build-cross-tools x86_64 || {
        echo "[!] Configure with cross tools returned non-zero status."
    }
fi

echo "Setup script completed."

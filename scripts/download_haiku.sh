#!/usr/bin/env bash
# Script to download Haiku ISO/Image release and Haiku source repository
# License: Public Domain / CC0 1.0 Universal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DOWNLOAD_DIR="${BASE_DIR}/downloads"

HAIKU_ISO_URL="https://ftp.osuosl.org/pub/haiku/r1beta5/haiku-r1beta5-x86_64-anyboot.iso"
HAIKU_NIGHTLY_URL="https://files.haiku-os.org/build-master/x86_64/current/haiku-nightly-anyboot.zip"
HAIKU_GIT_REPO="https://git.haiku-os.org/haiku"

mkdir -p "${DOWNLOAD_DIR}"

echo "=================================================================="
echo " Haiku OS & Sources Downloader Script"
echo " Target Directory: ${DOWNLOAD_DIR}"
echo "=================================================================="

# Check available tools
FETCH_CMD=""
if command -v curl &>/dev/null; then
    FETCH_CMD="curl -L -o"
elif command -v wget &>/dev/null; then
    FETCH_CMD="wget -O"
else
    echo "Error: Neither curl nor wget is installed." >&2
    exit 1
fi

echo "[1/3] Downloading Haiku R1/Beta5 anyboot ISO..."
if [ ! -f "${DOWNLOAD_DIR}/haiku-r1beta5-x86_64-anyboot.iso" ]; then
    echo "Fetching ${HAIKU_ISO_URL}..."
    $FETCH_CMD "${DOWNLOAD_DIR}/haiku-r1beta5-x86_64-anyboot.iso" "${HAIKU_ISO_URL}" || {
        echo "Primary release download failed, attempting release mirror..."
        $FETCH_CMD "${DOWNLOAD_DIR}/haiku-r1beta5-x86_64-anyboot.iso" "https://fs.haiku-os.org/files/r1beta5/haiku-r1beta5-x86_64-anyboot.iso" || echo "Release ISO download skipped/failed."
    }
else
    echo "Haiku ISO already present at ${DOWNLOAD_DIR}/haiku-r1beta5-x86_64-anyboot.iso"
fi

echo "[2/3] Cloning Haiku source repository..."
if [ ! -d "${DOWNLOAD_DIR}/haiku_sources" ]; then
    if command -v git &>/dev/null; then
        echo "Cloning lightweight depth=1 from ${HAIKU_GIT_REPO}..."
        git clone --depth 1 "${HAIKU_GIT_REPO}" "${DOWNLOAD_DIR}/haiku_sources" || {
            echo "Git clone failed, cloning GitHub mirror..."
            git clone --depth 1 "https://github.com/haiku/haiku.git" "${DOWNLOAD_DIR}/haiku_sources" || echo "Git clone skipped/failed."
        }
    else
        echo "git not found, skipping source repo clone."
    fi
else
    echo "Haiku source repository already present at ${DOWNLOAD_DIR}/haiku_sources"
fi

echo "[3/3] Downloads setup complete."
echo "Files located in: ${DOWNLOAD_DIR}"

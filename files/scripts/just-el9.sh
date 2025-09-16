#!/bin/bash
set -euo pipefail

JUST_VER=1.39.0
ARCH="$(uname -m)"
JUST_TAR="just-${JUST_VER}-${ARCH}-unknown-linux-musl.tar.gz"
BASE_URL="https://github.com/casey/just/releases/download/${JUST_VER}"

cd /tmp
echo "Downloading just ${JUST_VER} for ${ARCH}..."
curl -fLO "${BASE_URL}/${JUST_TAR}"
curl -fLO "${BASE_URL}/SHA256SUMS"

echo "Verifying checksum..."
sha256sum --check --ignore-missing SHA256SUMS

echo "Extracting and installing..."
tar -xzf "${JUST_TAR}"

# Ensure target dir exists in the image root
install -d /usr/local/bin
install -m 0755 just /usr/local/bin/just

echo "Installed:"
/usr/local/bin/just --version

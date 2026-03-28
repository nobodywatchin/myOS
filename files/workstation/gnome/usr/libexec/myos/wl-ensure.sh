#!/usr/bin/env bash
set -euo pipefail

KVER="$(uname -r)"

# If wl isn't available for this kernel, build it
if ! modinfo wl >/dev/null 2>&1; then
  echo "wl: module not found for ${KVER}, invoking akmods..."
  akmods --force --kernels "${KVER}" || true
  depmod -a "${KVER}" || true
fi

# Load the module (requires Secure Boot OFF)
modprobe wl 2>/dev/null || true

# Bring Wi-Fi up if NetworkManager is present
if command -v nmcli >/dev/null 2>&1; then
  nmcli radio wifi on || true
fi
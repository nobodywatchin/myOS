#!/usr/bin/env bash
# Build & load Negativo17 NVIDIA akmods on immutable (EL BootC) systems.
# Robust RPM discovery: cache -> log "Wrote:" -> /tmp/akmodsbuild.* glob
set -euo pipefail

KVER="$(uname -r)"
STAMP_DIR="/var/lib/akmods"
STAMP_FILE="${STAMP_DIR}/.nvidia-built-${KVER}"
CACHE_DIR="/var/cache/akmods/nvidia"
EXTRACT_ROOT="/var/lib/nvidia-akmods/${KVER}"
need_pkgs=(gcc make binutils elfutils-libelf-devel rpm cpio xz)

log()  { printf "[nvidia-akmods] %s\n" "$*"; }
fail() { log "ERROR: $*"; exit 1; }

# Idempotency
if [[ -f "${STAMP_FILE}" ]]; then
  log "Already built/loaded for ${KVER}."
  exit 0
fi

log "Kernel: ${KVER}"

# Prereqs (headers + toolchain)
[[ -d "/usr/src/kernels/${KVER}" ]] || fail "Missing /usr/src/kernels/${KVER}. Install kernel-devel-${KVER}."
missing=()
for p in "${need_pkgs[@]}"; do rpm -q "$p" >/dev/null 2>&1 || missing+=("$p"); done
(( ${#missing[@]} )) && fail "Missing packages: ${missing[*]}"

# Secure Boot key (harmless if SB off)
if [[ ! -f /etc/pki/akmods/certs/public_key.der ]]; then
  log "No akmods key found; generating (kmodgenca -a)…"
  kmodgenca -a
else
  log "akmods key present."
fi

# Build. akmods will try to install (and fail on BootC), that's fine—we just need the RPM.
log "Building akmod 'nvidia' for ${KVER}…"
set +e
akmods --force --kernels "${KVER}" --akmod nvidia
akrc=$?
set -e

# Find latest akmods log (success or fail)
build_log="$(ls -1t ${CACHE_DIR}/*-for-${KVER}.{log,failed.log} 2>/dev/null | head -n1 || true)"
[[ -z "${build_log}" ]] && build_log="$(ls -1t ${CACHE_DIR}/*${KVER}*.{log,failed.log} 2>/dev/null | head -n1 || true)"
[[ -n "${build_log}" ]] && { log "Build log: ${build_log}"; tail -n 40 "${build_log}" || true; }

# Discover the built RPM:
RPM=""

# 1) Preferred: cache
if [[ -z "${RPM}" ]]; then
  RPM="$(ls -1t ${CACHE_DIR}/kmod-nvidia-*for-${KVER}*.rpm 2>/dev/null | head -n1 || true)"
fi
if [[ -z "${RPM}" ]]; then
  RPM="$(ls -1t ${CACHE_DIR}/kmod-nvidia-*${KVER}*.rpm 2>/dev/null | head -n1 || true)"
fi

# 2) Parse "Wrote: /tmp/...rpm" from log
if [[ -z "${RPM}" && -n "${build_log}" ]]; then
  wrote_path="$(grep -Eo 'Wrote: /tmp/akmodsbuild\.[^ ]+/RPMS/x86_64/kmod-nvidia[^ ]+\.rpm' "${build_log}" | awk '{print $2}' | tail -n1 || true)"
  [[ -n "${wrote_path}" && -f "${wrote_path}" ]] && RPM="${wrote_path}"
fi

# 3) Fallback: glob under /tmp/akmodsbuild.*
if [[ -z "${RPM}" ]]; then
  RPM="$(ls -1t /tmp/akmodsbuild.*/RPMS/x86_64/kmod-nvidia-*${KVER}*.rpm 2>/dev/null | head -n1 || true)"
fi

[[ -n "${RPM}" && -f "${RPM}" ]] || fail "Build did not leave a kmod RPM anywhere I can find."

log "Using built RPM: ${RPM}"

# Extract into a private root in /var (RO-safe)
log "Extracting modules to ${EXTRACT_ROOT}…"
rm -rf "${EXTRACT_ROOT}"
mkdir -p "${EXTRACT_ROOT}"
rpm2cpio "${RPM}" | (cd "${EXTRACT_ROOT}" && cpio -idmv >/dev/null 2>&1 || true)

MODTREE="${EXTRACT_ROOT}/lib/modules/${KVER}"
[[ -d "${MODTREE}" ]] || fail "Extraction missing ${MODTREE}."

# Generate private depmod data (in our EXTRACT_ROOT); ignore failures
log "Generating depmod metadata in private root…"
depmod -b "${EXTRACT_ROOT}" -a "${KVER}" || true

# Load from private root (no writes to /lib/modules)
log "Loading NVIDIA modules from private root…"
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia_modeset || true
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia_uvm || true
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia_drm || true

# Devices
command -v nvidia-modprobe >/dev/null 2>&1 && nvidia-modprobe -u -c=0 || true

mkdir -p "${STAMP_DIR}"
touch "${STAMP_FILE}"
log "Success. Loaded modules for ${KVER}."
lsmod | grep -E '^nvidia(_(modeset|uvm|drm))?' || true
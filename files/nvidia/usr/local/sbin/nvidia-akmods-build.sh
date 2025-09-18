#!/usr/bin/env bash
# Build & load Negativo17 NVIDIA akmods for the running kernel (EL BootC)
set -euo pipefail

STAMP_DIR="/var/lib/akmods"
STAMP_FILE="${STAMP_DIR}/.nvidia-built-$(uname -r)"
KVER="$(uname -r)"
CACHE_DIR="/var/cache/akmods/nvidia"

log() { printf "[nvidia-akmods] %s\n" "$*"; }

# Skip if we already succeeded for this kernel
if [[ -f "${STAMP_FILE}" ]]; then
  log "Already built for ${KVER} (stamp present: ${STAMP_FILE}). Exiting."
  exit 0
fi

log "Kernel: ${KVER}"

# Ensure local akmods key exists (for Secure Boot signing). Safe if SB is off.
if [[ ! -f /etc/pki/akmods/certs/public_key.der ]]; then
  log "No akmods key found; generating local CA (kmodgenca -a)..."
  kmodgenca -a
else
  log "akmods key present."
fi

# Trigger the build (only builds if needed)
log "Building akmod 'nvidia' for ${KVER}..."
akmods --force --kernels "${KVER}" --akmod nvidia

# Run depmod in case akmods didn’t (usually it does)
log "Running depmod for ${KVER}..."
depmod -a "${KVER}"

# Surface the most recent akmods build log (useful for debugging)
if compgen -G "${CACHE_DIR}"/*-for-"${KVER}".log >/dev/null; then
  LOGFILE="$(ls -1t ${CACHE_DIR}/*-for-${KVER}.log | head -n1)"
  log "Last akmods log: ${LOGFILE}"
  # If the log contains 'error', fail early
  if grep -qiE '\berror\b' "${LOGFILE}"; then
    log "ERROR detected in ${LOGFILE}"
    exit 1
  fi
fi

# Load modules (order matters)
log "Loading NVIDIA kernel modules..."
modprobe nvidia
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia_drm || true   # may be absent on compute-only installs

# Create device nodes & set perms (harmless if already present)
if command -v nvidia-modprobe >/dev/null 2>&1; then
  nvidia-modprobe -u -c=0 || true
fi

# Stamp success so we don’t run again for this kernel
mkdir -p "${STAMP_DIR}"
touch "${STAMP_FILE}"

log "Success. Modules present:"
lsmod | grep -E '^nvidia(_(uvm|modeset|drm))?' || true

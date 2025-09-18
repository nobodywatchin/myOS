#!/usr/bin/env bash
# Build & load Negativo17 NVIDIA akmods on immutable (EL BootC) systems.
set -euo pipefail

KVER="$(uname -r)"
STAMP_DIR="/var/lib/akmods"
STAMP_FILE="${STAMP_DIR}/.nvidia-built-${KVER}"
CACHE_DIR="/var/cache/akmods/nvidia"
EXTRACT_ROOT="/var/lib/nvidia-akmods/${KVER}"

log() { printf "[nvidia-akmods] %s\n" "$*"; }

# Idempotency: already done for this kernel?
if [[ -f "${STAMP_FILE}" ]]; then
  log "Already built/loaded for ${KVER}."
  exit 0
fi

log "Kernel: ${KVER}"

# Ensure local signing key exists (harmless if Secure Boot is off)
if [[ ! -f /etc/pki/akmods/certs/public_key.der ]]; then
  log "No akmods key found; generating local CA (kmodgenca -a)..."
  kmodgenca -a
else
  log "akmods key present."
fi

# Build akmod into cache (install of kmod RPM will fail on RO root, that's fine)
log "Building akmod 'nvidia' for ${KVER}..."
if ! akmods --force --kernels "${KVER}" --akmod nvidia; then
  log "akmods returned failure; checking cache log…"
fi

# Surface build log (useful even on success)
if compgen -G "${CACHE_DIR}"/*-for-"${KVER}".log >/dev/null; then
  LOGFILE="$(ls -1t ${CACHE_DIR}/*-for-${KVER}.log | head -n1)"
  log "Last akmods log: ${LOGFILE}"
  if grep -qiE '\berror\b' "${LOGFILE}"; then
    log "ERROR in akmods build. See ${LOGFILE}"
    exit 1
  fi
fi

# Find the built kmod RPM matching this kernel
RPM="$(ls -1t ${CACHE_DIR}/kmod-nvidia-*for-${KVER}*.rpm 2>/dev/null | head -n1 || true)"
if [[ -z "${RPM}" ]]; then
  # Some akmods versions name the RPM slightly differently; try a broader match:
  RPM="$(ls -1t ${CACHE_DIR}/kmod-nvidia-*${KVER}*.rpm 2>/dev/null | head -n1 || true)"
fi

if [[ -z "${RPM}" ]]; then
  log "Could not locate built kmod RPM in ${CACHE_DIR} for ${KVER}."
  exit 1
fi
log "Using built RPM: ${RPM}"

# Extract the RPM into a private root under /var (read-only safe)
log "Extracting modules to ${EXTRACT_ROOT}…"
mkdir -p "${EXTRACT_ROOT}"
# Clean any previous partials for this kernel
rm -rf "${EXTRACT_ROOT:?}/"*
rpm2cpio "${RPM}" | (cd "${EXTRACT_ROOT}" && cpio -idmv >/dev/null 2>&1 || true)

# Our extracted tree should now contain: lib/modules/${KVER}/extra/nvidia*.ko*
MODTREE="${EXTRACT_ROOT}/lib/modules/${KVER}"
if [[ ! -d "${MODTREE}" ]]; then
  log "Extraction did not create ${MODTREE}. Aborting."
  exit 1
fi

# (Optional) generate depmod data inside our private root (not strictly required)
log "Generating depmod metadata in private root…"
depmod -b "${EXTRACT_ROOT}" -a "${KVER}" || true

# Load modules from the private root without touching /lib/modules (RO-safe)
log "Loading NVIDIA modules from private root…"
# Base first, then modeset, uvm, drm
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia_modeset || true
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia_uvm || true
modprobe -d "${EXTRACT_ROOT}" -S "${KVER}" nvidia_drm || true

# Create device nodes & perms (harmless if present)
if command -v nvidia-modprobe >/dev/null 2>&1; then
  nvidia-modprobe -u -c=0 || true
fi

# Stamp success for this kernel so we don’t rerun
mkdir -p "${STAMP_DIR}"
touch "${STAMP_FILE}"

log "Success. Loaded modules for ${KVER}."
lsmod | grep -E '^nvidia(_(modeset|uvm|drm))?' || true
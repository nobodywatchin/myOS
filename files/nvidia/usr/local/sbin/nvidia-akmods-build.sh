#!/usr/bin/env bash
set -Eeuo pipefail

KVER="$(uname -r)"
WORK="$(mktemp -d -t nvidia-akmods-XXXXXX)"
CACHE_DIR="/var/cache/akmods/nvidia"
ROOT="/var/lib/nvidia-kmods/${KVER}"
MODDIR="${ROOT}/lib/modules/${KVER}/extra/nvidia"
MODPATH="${MODDIR}/nvidia.ko"

# NVIDIA module set we care about (some may be absent depending on build)
# Files are hyphenated; modprobe names use underscores. We'll handle both.
NV_FILES=(nvidia.ko nvidia-modeset.ko nvidia-uvm.ko nvidia-drm.ko nvidia-peermem.ko)
NV_NAMES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm nvidia_peermem)

log()  { echo "[nvidia-akmods] $*"; }
fail() { echo "[nvidia-akmods] ERROR: $*" >&2; exit 1; }
cleanup(){ rm -rf "${WORK}"; }
trap cleanup EXIT

need_tools=(rpm2cpio cpio xz modprobe depmod modinfo)
for bin in "${need_tools[@]}"; do
  command -v "$bin" >/dev/null 2>&1 || fail "Missing tool: $bin"
done

# ---------- FAST PATH: use existing staged modules if valid -------------------
if [[ -f "${MODPATH}" ]]; then
  VMOD="$(/usr/sbin/modinfo -F vermagic "${MODPATH}" | awk '{print $1}')"
  if [[ "${VMOD}" == "${KVER}" ]]; then
    log "Fast path: staged nvidia.ko matches ${KVER}, skipping akmods."
    # Ensure SELinux labels so kmod can read staged tree
    if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
      if command -v semanage >/dev/null 2>&1; then
        semanage fcontext -a -t modules_object_t '/var/lib/nvidia-kmods(/.*)?' 2>/dev/null || true
        restorecon -RF "${ROOT}" || true
      else
        chcon -R -t modules_object_t "${ROOT}" || true
      fi
    fi

    # Preload any dependencies exposed by primary module
    DEPS="$({ /usr/sbin/modinfo -F depends "${MODPATH}" || true; } | tr ',' ' ' | xargs -r echo || true)"
    for d in ${DEPS:-}; do /usr/sbin/modprobe "${d}" 2>/dev/null || true; done

    # Prepare module dependency metadata and try loading in sane order
    depmod -b "${ROOT}" "${KVER}"
    # Load base; others will auto-pull if deps are correct, but try explicit order
    /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia        2>/dev/null || true
    /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia_modeset 2>/dev/null || true
    /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia_uvm     2>/dev/null || true
    /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia_drm     2>/dev/null || true
    /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia_peermem 2>/dev/null || true

    if lsmod | grep -q '^nvidia\s'; then
      log "Loaded NVIDIA modules (fast path)."
      exit 0
    fi
    log "Fast path load failed; falling back to akmods build."
  fi
fi

# ---------- SLOW PATH: build for this kernel via akmods ----------------------
rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1 \
  || fail "Missing kernel-devel for ${KVER} (dnf -y install kernel-devel-${KVER})"
command -v akmods >/dev/null 2>&1 || fail "Missing tool: akmods"

log "Building akmod 'nvidia' for ${KVER} (first boot after kernel update)..."
/usr/sbin/akmods --kernels "${KVER}" --akmod nvidia || {
  log "WARNING: akmods returned non-zero (immutable base likely). Will use cached RPM if produced."
}

RPM="$(ls -1t \
  "${CACHE_DIR}"/*-for-"${KVER}".rpm \
  "${CACHE_DIR}"/kmod-nvidia-*.rpm \
  2>/dev/null | head -n1 || true)"

[[ -n "${RPM}" && -f "${RPM}" ]] || {
  log "Build logs (if any):"
  ls -1 "${CACHE_DIR}"/*-for-"${KVER}".{log,failed.log} 2>/dev/null || true
  fail "No kmod-nvidia RPM produced for ${KVER}."
}
log "Using RPM: ${RPM}"

pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM}"

# Collect produced module files (some may be absent depending on build)
declare -A FOUND_MAP=()
for f in "${NV_FILES[@]}"; do
  cand="$(find "${WORK}" -type f \( -name "${f}" -o -name "${f}.xz" \) -print -quit || true)"
  [[ -n "${cand}" ]] || continue
  if [[ "${cand}" == *.xz ]]; then
    xz -df "${cand}"
    cand="${cand%.xz}"
  fi
  FOUND_MAP["${f}"]="${cand}"
done
popd >/dev/null

# We require at least nvidia.ko for a valid stack
[[ -n "${FOUND_MAP[nvidia.ko]:-}" ]] || fail "nvidia.ko(.xz) not found in ${RPM}"

# Stage into our per-kernel root
install -d -m 0755 "${MODDIR}"
for f in "${NV_FILES[@]}"; do
  src="${FOUND_MAP[$f]:-}"
  [[ -n "${src}" ]] || continue
  install -m 0644 "${src}" "${MODDIR}/${f}"
done
log "Staged NVIDIA modules under ${MODDIR}"

# ---------- SELinux: label staged tree so kmod can read it -------------------
if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
  if command -v semanage >/dev/null 2>&1; then
    semanage fcontext -a -t modules_object_t '/var/lib/nvidia-kmods(/.*)?' 2>/dev/null || true
    restorecon -RF "${ROOT}" || true
  else
    chcon -R -t modules_object_t "${ROOT}" || true
  fi
  log "SELinux labels applied (modules_object_t) under ${ROOT}"
fi

# ---------- Optional signing (Secure Boot) -----------------------------------
PRIV="/etc/pki/akmods/private/private_key.priv"
PUB="/etc/pki/akmods/certs/public_key.der"
if [[ -f "${PRIV}" && -f "${PUB}" && -x "$(command -v kmodsign || true)" ]]; then
  log "Signing NVIDIA modules with akmods key..."
  for f in "${NV_FILES[@]}"; do
    dest="${MODDIR}/${f}"
    [[ -f "${dest}" ]] || continue
    kmodsign sha512 "${PRIV}" "${PUB}" "${dest}" || fail "kmodsign failed for ${f}"
  done
fi

# ---------- Verify vermagic; preload deps; load ------------------------------
VMOD="$(/usr/sbin/modinfo -F vermagic "${MODPATH}" | awk '{print $1}')"
[[ "${VMOD}" == "${KVER}" ]] || fail "vermagic mismatch: nvidia.ko built for ${VMOD}, running ${KVER}"

# Preload dependencies of primary module (drm, i2c-core, etc.) if listed
DEPS="$({ /usr/sbin/modinfo -F depends "${MODPATH}" || true; } | tr ',' ' ' | xargs -r echo || true)"
for d in ${DEPS:-}; do /usr/sbin/modprobe "${d}" 2>/dev/null || true; done

# Build module dependency metadata in the staged root and load modules
depmod -b "${ROOT}" "${KVER}"

# Load in safe order; ignore missing ones
for name in "${NV_NAMES[@]}"; do
  /usr/sbin/insmod "${MODDIR}/${name//_/-}.ko" 2>/dev/null \
    || /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" "${name}" 2>/dev/null \
    || true
done

if lsmod | grep -q '^nvidia\s'; then
  log "Loaded NVIDIA modules (build path)."
  exit 0
else
  dmesg | tail -n 120 || true
  fail "Failed to load NVIDIA modules."
fi

#!/usr/bin/env bash

set -Eeuo pipefail

KVER="$(uname -r)"
WORK="$(mktemp -d -t nvkmods-XXXXXX)"
CACHE_DIR="/var/cache/akmods/nvidia"
ROOT="/var/lib/nvidia-kmods/${KVER}"
MODBASE="${ROOT}/lib/modules/${KVER}/extra/nvidia"
MOD_NVIDIA="${MODBASE}/nvidia.ko"
MOD_MODESET="${MODBASE}/nvidia-modeset.ko"
MOD_UVM="${MODBASE}/nvidia-uvm.ko"
MOD_DRM="${MODBASE}/nvidia-drm.ko"
REQUIRED=( "${MOD_NVIDIA}" "${MOD_MODESET}" "${MOD_UVM}" "${MOD_DRM}" )

log()  { echo "[nvidia-akmods] $*"; }
fail() { echo "[nvidia-akmods] ERROR: $*" >&2; exit 1; }
cleanup(){ rm -rf "${WORK}"; }
trap cleanup EXIT

need_tools=(rpm2cpio cpio xz modprobe depmod modinfo)
for bin in "${need_tools[@]}"; do command -v "$bin" >/dev/null 2>&1 || fail "Missing tool: $bin"; done

ensure_selinux_labels() {
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    if command -v semanage >/dev/null 2>&1; then
      semanage fcontext -a -t modules_object_t '/var/lib/nvidia-kmods(/.*)?' 2>/dev/null || true
      restorecon -RF "${ROOT}" || true
    else
      chcon -R -t modules_object_t "${ROOT}" || true
    fi
    log "SELinux labels applied (modules_object_t) under ${ROOT}"
  fi
}

vermagic_of() { /usr/sbin/modinfo -F vermagic "$1" 2>/dev/null | awk '{print $1}'; }
vermagic_ok()  { [[ -f "$1" ]] && [[ "$(vermagic_of "$1")" == "$KVER" ]]; }

preload_deps_for() {
  local f="$1" deps
  deps="$({ /usr/sbin/modinfo -F depends "$f" || true; } | tr ',' ' ' | xargs -r echo || true)"
  for d in ${deps:-}; do /usr/sbin/modprobe "$d" 2>/dev/null || log "WARN: dep ${d} not preloaded (maybe built-in)"; done
}

load_sequence() {
  if lsmod | grep -q '^nouveau\s'; then
    log "Detected nouveau; attempting to unload"
    rmmod nouveau 2>/dev/null || true
  fi
  depmod -b "${ROOT}" "${KVER}"
  /usr/sbin/modprobe drm 2>/dev/null || true
  /usr/sbin/modprobe drm_kms_helper 2>/dev/null || true
  /usr/sbin/modprobe i2c-core 2>/dev/null || true

  preload_deps_for "${MOD_NVIDIA}"
  preload_deps_for "${MOD_MODESET}"
  preload_deps_for "${MOD_UVM}"
  preload_deps_for "${MOD_DRM}"

  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia                 || fail "load nvidia failed"
  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia-modeset         || fail "load nvidia-modeset failed"
  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia-uvm             || log "WARN: nvidia-uvm load failed (OK if unused)"
  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia-drm modeset=1   || fail "load nvidia-drm failed"

  lsmod | grep -q '^nvidia\s' && lsmod | grep -q '^nvidia_drm\s' || fail "NVIDIA modules not active"
  log "SUCCESS: NVIDIA modules loaded (nvidia + modeset + drm [+ uvm])."
}

# ---------- FAST PATH -------------------------------------------------------
fast_path=true
for f in "${REQUIRED[@]}"; do
  if ! vermagic_ok "$f"; then fast_path=false; break; fi
done
if $fast_path; then
  log "FAST PATH: staged NVIDIA modules match ${KVER}; skipping akmods."
  ensure_selinux_labels
  load_sequence
  exit 0
fi

# ---------- SLOW PATH: build, then require exact or matching vermagic -------
rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1 || \
  fail "Missing kernel-devel for ${KVER} (dnf -y install kernel-devel-${KVER})"
command -v akmods >/dev/null 2>&1 || fail "Missing tool: akmods"

log "SLOW PATH: building akmod 'nvidia' for ${KVER}..."
# Try a clean rebuild attempt
/usr/sbin/akmods --rebuild --force --kernels "${KVER}" --akmod nvidia || \
  log "WARNING: akmods returned non-zero (install likely failed on immutable base); continuing."

# Prefer an exact-for RPM
RPM_FOR="$(ls -1t "${CACHE_DIR}"/*-for-"${KVER}".rpm 2>/dev/null | head -n1 || true)"
RPM_GEN=""

if [[ -z "${RPM_FOR}" || ! -f "${RPM_FOR}" ]]; then
  # Fallback: consider newest generic, but only if its embedded vermagic matches
  RPM_GEN="$(ls -1t "${CACHE_DIR}"/kmod-nvidia-*.rpm 2>/dev/null | head -n1 || true)"
  if [[ -z "${RPM_GEN}" || ! -f "${RPM_GEN}" ]]; then
    log "Build logs (if any):"; ls -1 "${CACHE_DIR}"/*-for-"${KVER}".{log,failed.log} 2>/dev/null || true
    fail "No kmod-nvidia RPM produced for ${KVER}."
  fi
  log "No exact-for RPM; testing generic RPM vermagic…"
  # Quick vermagic probe of generic RPM by extracting just one .ko path
  pushd "${WORK}" >/dev/null
  rpm2cpio "${RPM_GEN}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM_GEN}"
  ONE_KO="$(find . -type f -name 'nvidia.ko*' -o -name 'nvidia-modeset.ko*' | head -n1)"
  [[ -n "${ONE_KO}" ]] || fail "Generic RPM contained no nvidia*.ko"
  [[ "${ONE_KO}" == *.xz ]] && xz -df "${ONE_KO}" && ONE_KO="${ONE_KO%.xz}"
  VMOD_PROBE="$(vermagic_of "${ONE_KO}")"
  popd >/dev/null
  if [[ "${VMOD_PROBE}" != "${KVER}" ]]; then
    log "Build logs (if any):"; ls -1 "${CACHE_DIR}"/*-for-"${KVER}".{log,failed.log} 2>/dev/null || true
    fail "Exact-for RPM missing and generic RPM vermagic (${VMOD_PROBE}) != running (${KVER})."
  fi
  RPM_USE="${RPM_GEN}"
  log "Using generic RPM (vermagic matches): ${RPM_USE}"
else
  RPM_USE="${RPM_FOR}"
  log "Using exact RPM: ${RPM_USE}"
fi

# Extract and stage all NVIDIA .ko files
pushd "${WORK}" >/dev/null
rpm2cpio "${RPM_USE}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM_USE}"
FOUND="$(find "${WORK}" -type f \( -name 'nvidia*.ko' -o -name 'nvidia*.ko.xz' \) | sort)"
popd >/dev/null
[[ -n "${FOUND}" ]] || fail "No nvidia*.ko files found in ${RPM_USE}"

install -d -m 0755 "${MODBASE}"
while IFS= read -r f; do
  if [[ "$f" == *.xz ]]; then xz -df "$f" || fail "Decompress failed for $f"; f="${f%.xz}"; fi
  install -m 0644 "$f" "${MODBASE}/$(basename "$f")"
done <<< "${FOUND}"
log "Staged NVIDIA modules under ${MODBASE}"

ensure_selinux_labels

# Optional Secure Boot signing
PRIV="/etc/pki/akmods/private/private_key.priv"
PUB="/etc/pki/akmods/certs/public_key.der"
if [[ -f "${PRIV}" && -f "${PUB}" && -x "$(command -v kmodsign || true)" ]]; then
  log "Signing NVIDIA modules with akmods key..."
  for f in "${REQUIRED[@]}"; do
    [[ -f "$f" ]] && kmodsign sha512 "${PRIV}" "${PUB}" "$f" || fail "kmodsign failed for $(basename "$f")"
  done
fi

# Final sanity: staged files must match vermagic
for f in "${REQUIRED[@]}"; do
  vermagic_ok "$f" || fail "vermagic mismatch for $(basename "$f")"
done

load_sequence
exit 0

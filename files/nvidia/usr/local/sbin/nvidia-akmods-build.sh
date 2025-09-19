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

vermagic_ok() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local v m
  v="$(/usr/sbin/modinfo -F vermagic "$f" 2>/dev/null | awk '{print $1}')" || return 1
  [[ "$v" == "$KVER" ]]
}

preload_deps_for() {
  local f="$1"
  local deps; deps="$({ /usr/sbin/modinfo -F depends "$f" || true; } | tr ',' ' ' | xargs -r echo || true)"
  for d in ${deps:-}; do /usr/sbin/modprobe "$d" 2>/dev/null || log "WARN: dep ${d} not preloaded (maybe built-in)"; done
}

load_sequence() {
  # Make sure nouveau isn't in the way
  if lsmod | grep -q '^nouveau\s'; then
    log "Detected nouveau; attempting to unload"
    rmmod nouveau 2>/dev/null || true
  fi

  # Generate deps in our private root
  depmod -b "${ROOT}" "${KVER}"

  # Preload common DRM deps from the host tree
  /usr/sbin/modprobe drm 2>/dev/null || true
  /usr/sbin/modprobe drm_kms_helper 2>/dev/null || true
  /usr/sbin/modprobe i2c-core 2>/dev/null || true

  # Preload per-module declared deps
  preload_deps_for "${MOD_NVIDIA}"
  preload_deps_for "${MOD_MODESET}"
  preload_deps_for "${MOD_UVM}"
  preload_deps_for "${MOD_DRM}"

  # Load in correct order; use modprobe -d so parameters work (e.g., modeset=1)
  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia || fail "load nvidia failed"
  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia-modeset || fail "load nvidia-modeset failed"
  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia-uvm || log "WARN: nvidia-uvm load failed (OK if not used by workload)"
  /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia-drm modeset=1 || fail "load nvidia-drm failed"

  # Verify
  lsmod | grep -q '^nvidia\s' && lsmod | grep -q '^nvidia_drm\s' || fail "NVIDIA modules not active"
  log "SUCCESS: NVIDIA modules loaded (nvidia + modeset + drm [+ uvm])."
}

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

# ----- SLOW PATH (first boot after kernel update): build & stage -------------
rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1 || \
  fail "Missing kernel-devel for ${KVER} (dnf -y install kernel-devel-${KVER})"
command -v akmods >/dev/null 2>&1 || fail "Missing tool: akmods"

log "SLOW PATH: building akmod 'nvidia' for ${KVER}..."
if ! /usr/sbin/akmods --kernels "${KVER}" --akmod nvidia; then
  log "WARNING: akmods install step failed (immutable base). Will use cached RPM if produced."
fi

# Find the newest cached kmod RPM (names vary slightly)
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

# Extract modules
pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM}"
FOUND="$(find "${WORK}" -type f \( -name 'nvidia*.ko' -o -name 'nvidia*.ko.xz' \) | sort)"
popd >/dev/null
[[ -n "${FOUND}" ]] || fail "No nvidia*.ko files found in ${RPM}"

# Stage
install -d -m 0755 "${MODBASE}"
while IFS= read -r f; do
  tgt="${MODBASE}/$(basename "${f%.*}")"  # strip .xz if present
  if [[ "$f" == *.xz ]]; then
    tmp="${f%.xz}"; xz -df "$f" && f="$tmp"
  fi
  install -m 0644 "$f" "${tgt}.ko"
done <<< "${FOUND}"
log "Staged NVIDIA modules under ${MODBASE}"

# SELinux labels so modprobe can read
ensure_selinux_labels

# Optional: sign all staged modules (Secure Boot)
PRIV="/etc/pki/akmods/private/private_key.priv"
PUB="/etc/pki/akmods/certs/public_key.der"
if [[ -f "${PRIV}" && -f "${PUB}" && -x "$(command -v kmodsign || true)" ]]; then
  log "Signing NVIDIA modules with akmods key..."
  for f in "${REQUIRED[@]}"; do kmodsign sha512 "${PRIV}" "${PUB}" "$f" || fail "kmodsign failed for $(basename "$f")"; done
fi

# Sanity: vermagic checks
for f in "${REQUIRED[@]}"; do vermagic_ok "$f" || fail "vermagic mismatch for $(basename "$f")"; done

# Load them
load_sequence
exit 0

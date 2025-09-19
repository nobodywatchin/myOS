#!/usr/bin/env bash
set -Eeuo pipefail

KVER="$(uname -r)"
WORK="$(mktemp -d -t nvidia-akmods-XXXXXX)"
CACHE_DIR="/var/cache/akmods/nvidia"
ROOT="/var/lib/nvidia-kmods/${KVER}"
BASE="${ROOT}/lib/modules/${KVER}"
MODDIR="${BASE}/extra/nvidia"
MODPATH="${MODDIR}/nvidia.ko"

NV_FILES=(nvidia.ko nvidia-modeset.ko nvidia-drm.ko nvidia-uvm.ko nvidia-peermem.ko)
NV_NAMES=(nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem)

log()  { echo "[nvidia-akmods] $*"; }
fail() { echo "[nvidia-akmods] ERROR: $*" >&2; exit 1; }
cleanup(){ rm -rf "${WORK}"; }
trap cleanup EXIT

need_tools=(rpm2cpio cpio xz modprobe depmod modinfo)
for bin in "${need_tools[@]}"; do command -v "$bin" >/dev/null 2>&1 || fail "Missing tool: $bin"; done

# ---------------- Helpers -----------------------------------------------------
_have_mod() { lsmod | awk '{print $1}' | grep -qx "$1"; }

_copy_kernel_meta() {
  # Give depmod a more complete view inside ${BASE}
  local src="/lib/modules/${KVER}"
  install -d -m 0755 "${BASE}"
  for f in modules.order modules.builtin modules.builtin.modinfo; do
    [[ -f "${src}/${f}" ]] && install -m 0644 "${src}/${f}" "${BASE}/${f}"
  done
}

_label_selinux() {
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    if command -v semanage >/dev/null 2>&1; then
      # Modify rule if it exists, else add it
      semanage fcontext -a -t modules_object_t '/var/lib/nvidia-kmods(/.*)?' 2>/dev/null || \
      semanage fcontext -m -t modules_object_t '/var/lib/nvidia-kmods(/.*)?' 2>/dev/null || true
      restorecon -RF "${ROOT}" || true
    else
      chcon -R -t modules_object_t "${ROOT}" || true
    fi
    log "SELinux labels applied (modules_object_t) under ${ROOT}"
  fi
}

_try_unload_nouveau() {
  # Best effort: if nouveau is loaded, try to remove it to avoid clashes
  if _have_mod nouveau; then
    log "Detected nouveau loaded; attempting to unload (best effort)."
    # common helpers sometimes hold references; try in a safe-ish order
    sudo /usr/sbin/modprobe -r nouveau 2>/dev/null || true
    _have_mod nouveau && {
      log "Could not unload nouveau (in use). Consider reboot with nouveau blacklisted."
      return 1
    }
    log "Unloaded nouveau."
  fi
  return 0
}

_load_stack_from_staged() {
  # Load in solid order; ignore missing pieces
  depmod -b "${ROOT}" "${KVER}"
  local ok=0
  for name in nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem; do
    local file="${MODDIR}/${name//_/-}.ko"
    [[ -f "${file}" ]] || { continue; }
    /usr/sbin/insmod "${file}" 2>/dev/null || \
    /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" "${name}" 2>/dev/null || true
  done
  _have_mod nvidia && ok=1
  return "${ok}"
}

post_fail_hints() {
  # Tail a bigger window so we catch the first failure
  local logtail
  logtail="$(dmesg | tail -n 800 || true)"

  if grep -q 'does not include the required GPU System Processor' <<<"$logtail"; then
    log "Detected OpenRM/GSP error on a non-GSP GPU (e.g., Pascal)."
    log "This script only stages the CLOSED/proprietary path. Ensure you do NOT have any '*-open' NVIDIA packages installed."
    log "Then rebuild akmods for this kernel and rerun."
    exit 42
  fi
  return 0
}

# ---------------- FAST PATH ---------------------------------------------------
if [[ -f "${MODPATH}" ]]; then
  log "Fast path candidate found at ${MODPATH}."
  _label_selinux
  _copy_kernel_meta
  if _try_unload_nouveau; then
    if _load_stack_from_staged; then
      log "Loaded NVIDIA modules (fast path)."
      exit 0
    else
      log "Fast path load failed; will try build path."
    fi
  else
    log "Fast path blocked by nouveau; will try build path."
  fi
fi

# ---------------- SLOW PATH: build via akmods ---------------------------------
# We only need akmods to *produce* an RPM in the cache; install is not required.
if ! command -v akmods >/dev/null 2>&1; then
  fail "Missing tool: akmods"
fi
rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1 || \
  fail "Missing kernel-devel for ${KVER} (dnf -y install kernel-devel-${KVER})"

log "Building akmod 'nvidia' for ${KVER} (immutable-safe: cache artefact only)..."
/usr/sbin/akmods --kernels "${KVER}" --akmod nvidia || \
  log "WARNING: akmods returned non-zero (install likely failed on immutable base); continuing."

RPM="$(ls -1t \
  "${CACHE_DIR}"/*-for-"${KVER}".rpm \
  "${CACHE_DIR}"/kmod-nvidia-*.rpm \
  2>/dev/null | head -n1 || true)"

[[ -n "${RPM}" && -f "${RPM}" ]] || {
  log "Build logs (if any):"; ls -1 "${CACHE_DIR}"/*-for-"${KVER}".{log,failed.log} 2>/dev/null || true
  fail "No kmod-nvidia RPM produced for ${KVER}."
}
log "Using RPM: ${RPM}"

pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM}"

declare -A FOUND_MAP=()
for f in "${NV_FILES[@]}"; do
  cand="$(find "${WORK}" -type f \( -name "${f}" -o -name "${f}.xz" \) -print -quit || true)"
  [[ -n "${cand}" ]] || continue
  if [[ "${cand}" == *.xz ]]; then xz -df "${cand}"; cand="${cand%.xz}"; fi
  FOUND_MAP["${f}"]="${cand}"
done
popd >/dev/null

[[ -n "${FOUND_MAP[nvidia.ko]:-}" ]] || fail "nvidia.ko(.xz) not found in ${RPM}"

install -d -m 0755 "${MODDIR}"
for f in "${NV_FILES[@]}"; do
  src="${FOUND_MAP[$f]:-}"
  [[ -n "${src}" ]] || continue
  install -m 0644 "${src}" "${MODDIR}/${f}"
done
log "Staged NVIDIA modules under ${MODDIR}"

_label_selinux
_copy_kernel_meta

# --------- Optional signing (Secure Boot) ------------------------------------
PRIV="/etc/pki/akmods/private/private_key.priv"
PUB="/etc/pki/akmods/certs/public_key.der"
if [[ -f "${PRIV}" && -f "${PUB}" && -x "$(command -v kmodsign || true)" ]]; then
  log "Signing NVIDIA modules with akmods key..."
  for f in "${NV_FILES[@]}"; do
    dest="${MODDIR}/${f}"; [[ -f "${dest}" ]] || continue
    kmodsign sha512 "${PRIV}" "${PUB}" "${dest}" || fail "kmodsign failed for ${f}"
  done
fi

# --------- Try to load (then validate on failure) -----------------------------
if _try_unload_nouveau && _load_stack_from_staged; then
  log "Loaded NVIDIA modules (build path)."
  exit 0
fi

# If we got here, loading failed. Provide useful diagnostics.
VMOD="$(/usr/sbin/modinfo -F vermagic "${MODPATH}" 2>/dev/null | awk '{print $1}')"
if [[ -n "${VMOD}" && "${VMOD}" != "${KVER}" ]]; then
  log "Note: vermagic for nvidia.ko is ${VMOD}, running kernel is ${KVER}."
  log "If Secure Boot is on, ensure the akmods key is enrolled (MOK) and modules are signed."
fi

post_fail_hints
dmesg | tail -n 200 || true
fail "Failed to load NVIDIA modules."

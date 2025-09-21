#!/usr/bin/env bash
set -Eeuo pipefail

# ---------------- Vars --------------------------------------------------------
KVER="$(uname -r)"
WORK="$(mktemp -d -t nvidia-akmods-XXXXXX)"
CACHE_DIR="/var/cache/akmods/nvidia"

ROOT="/var/lib/nvidia-kmods/${KVER}" 
BASE="${ROOT}/lib/modules/${KVER}"
MODDIR="${BASE}/extra/nvidia"
MODPATH="${MODDIR}/nvidia.ko"

NV_FILES=(nvidia.ko nvidia-modeset.ko nvidia-drm.ko nvidia-uvm.ko nvidia-peermem.ko)
NV_NAMES=(nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem)

# Ensure the module options we need exist in real /etc (source of truth)
REQ_MODPROBE_CONF="/etc/modprobe.d/nvidia-drm.conf"
REQ_MODPROBE_LINE="options nvidia-drm modeset=1 fbdev=1"

log()  { echo "[nvidia-akmods] $*"; }
fail() { echo "[nvidia-akmods] ERROR: $*" >&2; exit 1; }
cleanup(){ rm -rf "${WORK}"; }
trap cleanup EXIT

need_tools=(rpm2cpio cpio xz modprobe depmod modinfo)
for bin in "${need_tools[@]}"; do command -v "$bin" >/dev/null 2>&1 || fail "Missing tool: $bin"; done

# ---------------- Helpers -----------------------------------------------------
_have_mod() { lsmod | awk '{print $1}' | grep -qx "$1"; }

_copy_kernel_meta() {
  local src="/lib/modules/${KVER}"
  install -d -m 0755 "${BASE}"
  for f in modules.order modules.builtin modules.builtin.modinfo; do
    [[ -f "${src}/${f}" ]] && install -m 0644 "${src}/${f}" "${BASE}/${f}"
  done
}

_label_selinux() {
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    if command -v semanage >/dev/null 2>&1; then
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
  if _have_mod nouveau; then
    log "Detected nouveau loaded; attempting to unload."
    /usr/sbin/modprobe -r nouveau 2>/dev/null || true
    _have_mod nouveau && { log "Could not unload nouveau (in use). Reboot with nouveau blacklisted."; return 1; }
    log "Unloaded nouveau."
  fi
  return 0
}

# Mirror /etc/modprobe.d into staged ROOT so modprobe -d sees the same options.
_sync_modprobe_conf_into_root() {
  install -d -m 0755 "${ROOT}/etc/modprobe.d"
  # Copy all existing confs (best effort)
  if [[ -d /etc/modprobe.d ]]; then
    # Do not overwrite staged file if we just wrote the required one below; copy others first.
    for f in /etc/modprobe.d/*.conf; do
      [[ -f "$f" ]] || continue
      # Skip our target file here; we'll (re)write authoritative contents next.
      [[ "$(basename -- "$f")" == "$(basename -- "$REQ_MODPROBE_CONF")" ]] && continue
      install -m 0644 "$f" "${ROOT}/etc/modprobe.d/$(basename -- "$f")"
    done
  fi
  # Write the required option (authoritative inside staged root)
  printf '%s\n' "${REQ_MODPROBE_LINE}" > "${ROOT}${REQ_MODPROBE_CONF}"
}

# Safer loader that respects options: uses staged ROOT for modules, but reads options from staged /etc we just synced.
_load_stack_from_staged() {
  # Build module dependency metadata inside staged root
  depmod -b "${ROOT}" "${KVER}"

  # Load in correct order; pass params explicitly for nvidia_drm as well
  for name in nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem; do
    local file="${MODDIR}/${name//_/-}.ko"
    [[ -f "${file}" ]] || continue
    if [[ "${name}" == "nvidia_drm" ]]; then
      # Prefer modprobe so aliases/deps/options apply; fall back to insmod with params.
      /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia_drm modeset=1 fbdev=1 2>/dev/null || \
      /usr/sbin/insmod "${file}" modeset=1 fbdev=1 2>/dev/null || true
    else
      /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" "${name}" 2>/dev/null || \
      /usr/sbin/insmod "${file}" 2>/dev/null || true
    fi
  done

  _have_mod nvidia && _have_mod nvidia_drm
}

_ensure_nvidia_devnodes() {
  if command -v nvidia-modprobe >/dev/null 2>&1; then
    nvidia-modprobe -u -c=0 || true
  fi
  if [[ ! -e /dev/nvidiactl || ! -e /dev/nvidia0 ]]; then
    local maj_nv maj_uvm
    maj_nv="$(awk '/^Character devices:/{f=1;next}/^Block devices:/{f=0} f && $2=="nvidia"{print $1}' /proc/devices || true)"
    maj_uvm="$(awk '/^Character devices:/{f=1;next}/^Block devices:/{f=0} f && $2=="nvidia-uvm"{print $1}' /proc/devices || true)"
    [[ -n "${maj_nv}" ]] || { log "WARNING: No 'nvidia' major in /proc/devices yet."; return 1; }
    [[ -e /dev/nvidiactl ]] || mknod -m 0666 /dev/nvidiactl c "${maj_nv}" 255
    [[ -e /dev/nvidia0   ]] || mknod -m 0666 /dev/nvidia0   c "${maj_nv}" 0
    if [[ -n "${maj_uvm}" ]]; then
      [[ -e /dev/nvidia-uvm       ]] || mknod -m 0666 /dev/nvidia-uvm       c "${maj_uvm}" 0
      [[ -e /dev/nvidia-uvm-tools ]] || mknod -m 0666 /dev/nvidia-uvm-tools c "${maj_uvm}" 1
    fi
    if getent group video >/dev/null 2>&1; then
      chgrp video /dev/nvidia* 2>/dev/null || true
      chmod 0660 /dev/nvidia* 2>/dev/null || true
    else
      chmod 0666 /dev/nvidia* 2>/dev/null || true
    fi
  fi
  return 0
}

_post_fail_hints() {
  local logtail; logtail="$(dmesg | tail -n 800 || true)"
  if grep -q 'does not include the required GPU System Processor' <<<"$logtail"; then
    log "Detected OpenRM/GSP error on a non-GSP GPU (e.g., Pascal)."
    log "Ensure /etc/nvidia/kernel.conf contains 'kernel' (proprietary) and rebuild akmods."
    exit 42
  fi
}

# ---------------- Enforce proprietary flavor (Negativo17) ---------------------
if ! grep -q 'MODULE_VARIANT=kernel' /etc/nvidia/kernel.conf 2>/dev/null; then
  log "Writing /etc/nvidia/kernel.conf for proprietary modules."
  cat > /etc/nvidia/kernel.conf <<'EOF'
# Selected NVIDIA kernel module flavor (proprietary vs open)
# Valid values: kernel (proprietary), kernel-open (open)
MODULE_VARIANT=kernel
FLAVOR=kernel
VARIANT=kernel
EOF
fi

# Ensure required modprobe option exists in real /etc
if ! grep -qsF "${REQ_MODPROBE_LINE}" "${REQ_MODPROBE_CONF}" 2>/dev/null; then
  log "Writing ${REQ_MODPROBE_CONF}"
  printf '%s\n' "${REQ_MODPROBE_LINE}" | tee "${REQ_MODPROBE_CONF}" >/dev/null
fi

# ---------------- FAST PATH ---------------------------------------------------
if [[ -f "${MODPATH}" ]]; then
  lic="$(/usr/sbin/modinfo -l "${MODPATH}" 2>/dev/null || true)"
  if [[ "${lic}" == "Dual MIT/GPL" ]]; then
    log "Found staged kernel-open module on a non-GSP GPU; removing staged tree."
    rm -rf "${ROOT}"
  fi
fi

if [[ -f "${MODPATH}" ]]; then
  log "Fast path candidate found at ${MODPATH}."
  _label_selinux
  _copy_kernel_meta
  _sync_modprobe_conf_into_root
  if _try_unload_nouveau && _load_stack_from_staged; then
    _ensure_nvidia_devnodes || true
    if lsmod | grep -q '^nvidia\s' && nvidia-smi -L >/dev/null 2>&1; then
      log "Loaded NVIDIA modules (fast path)."
      # Verify modeset actually enabled
      if [[ -f /sys/module/nvidia_drm/parameters/modeset ]]; then
        ms="$(cat /sys/module/nvidia_drm/parameters/modeset || true)"
        log "nvidia_drm.modeset=${ms}"
      fi
      exit 0
    fi
    log "Fast path load incomplete; will try build path."
  fi
fi

# ---------------- BUILD PATH (akmods) ----------------------------------------
command -v akmods >/dev/null 2>&1 || fail "Missing tool: akmods"
rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1 || \
  fail "Missing kernel-devel for ${KVER} (dnf -y install kernel-devel-${KVER})"

log "Building akmod 'nvidia' for ${KVER} (cache artifact only)."
/usr/sbin/akmods --kernels "${KVER}" --akmod nvidia || \
  log "WARNING: akmods returned non-zero; continuing with best-effort."

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
_sync_modprobe_conf_into_root

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

# --------- Load & verify ------------------------------------------------------
if _try_unload_nouveau && _load_stack_from_staged; then
  _ensure_nvidia_devnodes || true
  if nvidia-smi -L >/dev/null 2>&1; then
    log "Loaded NVIDIA modules (build path)."
    if [[ -f /sys/module/nvidia_drm/parameters/modeset ]]; then
      ms="$(cat /sys/module/nvidia_drm/parameters/modeset || true)"
      log "nvidia_drm.modeset=${ms}"
    fi
    exit 0
  fi
fi

# Diagnostics if we reach here
VMOD="$(/usr/sbin/modinfo -F vermagic "${MODPATH}" 2>/dev/null | awk '{print $1}')"
if [[ -n "${VMOD}" && "${VMOD}" != "${KVER}" ]]; then
  log "Note: vermagic=${VMOD}, running kernel=${KVER}. If Secure Boot is on, ensure MOK enrolled and modules signed."
fi

# Last-ditch hints
dmesg | tail -n 200 || true
fail "Failed to load NVIDIA modules."

#!/usr/bin/env bash

# nvidia-akmods-fastload
# Purpose: Prefer loading pre-staged NVIDIA kmods for the running kernel; if stale/missing,
#          build akmods, stage them under /var/lib/nvidia-kmods/$KVER, and then load.
# Notes:
#   - Detects if an NVIDIA GPU is present; exits immediately if not.
#   - Uses pre-staged NVIDIA kernel modules under /var/lib/nvidia-kmods/$KVER when valid.
#   - Detects driver upgrades (EVR mismatch) or stale modules and rebuilds them with akmods.
#   - Signs modules automatically if Secure Boot is enabled and keys are available.
#   - Fails with clear instructions if Secure Boot is enabled but signing cannot be done (unless bypassed).
#   - Unloads nouveau if present, applies SELinux labels, and mirrors modprobe options into the staged root.
#   - Creates /dev/nvidia* device nodes with correct permissions if they are missing.
#   - Concurrency lock prevents multiple runs from racing at boot or on demand.
#   - Safe to run manually or as a systemd unit before the display manager/graphical.target.

set -Eeuo pipefail

# ---------------- CONSTANTS ---------------------------------------------------
LOCK="/run/lock/nvidia-akmods.lock"
CACHE_DIR="/var/cache/akmods/nvidia"
REQ_MODPROBE_CONF="/etc/modprobe.d/nvidia-drm.conf"
REQ_MODPROBE_LINE="options nvidia-drm modeset=1 fbdev=1"
NV_FILES=(nvidia.ko nvidia-modeset.ko nvidia-drm.ko nvidia-uvm.ko nvidia-peermem.ko)
NV_NAMES=(nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem)

# ---------------- DERIVED -----------------------------------------------------
KVER="$(uname -r)"
WORK="$(mktemp -d -t nvidia-akmods-XXXXXX)"

# ---------------- STAGING PATHS ----------------------------------------------
ROOT="/var/lib/nvidia-kmods/${KVER}"
BASE="${ROOT}/lib/modules/${KVER}"
MODDIR="${BASE}/extra/nvidia"
MODPATH="${MODDIR}/nvidia.ko"

# ---------------- DRIVER/PKG VERSION STATE -----------------------------------
# Ensure staged module version matches installed driver/akmod; EVR=Epoch:Version-Release
PKG_EVR="$(
  rpm -q --qf '%{EVR}' akmod-nvidia 2>/dev/null || \
  rpm -q --qf '%{EVR}' nvidia-driver 2>/dev/null || \
  rpm -q --qf '%{EVR}' xorg-x11-drv-nvidia 2>/dev/null || \
  echo ''
)"
PKG_VER="${PKG_EVR%%-*}"
MOD_VER="$(/usr/sbin/modinfo -F version "${MODPATH}" 2>/dev/null || echo '')"

# ---------------- LOGGING / EXIT HANDLING ------------------------------------
log()  { echo "[nvidia-akmods] $*"; }
fail() { echo "[nvidia-akmods] ERROR: $*" >&2; exit 1; }
cleanup(){ rm -rf "${WORK}"; }
trap cleanup EXIT INT TERM

# Concurrency lock: avoid racing parallel runs (system boot vs manual, etc.)
install -d -m 0755 "$(dirname -- "${LOCK}")"
exec 9>"${LOCK}"
flock -n 9 || fail "Another nvidia-akmods run is in progress."

# ---------------- PRE-FLIGHT CHECKS ------------------------------------------
# Skip on hosts/VMs without an NVIDIA GPU to avoid wasted work
if command -v lspci >/dev/null 2>&1; then
  if ! lspci -nn | grep -qiE '(^|\s)(3d controller|vga compatible controller):.*NVIDIA'; then
    log "No NVIDIA GPU detected; nothing to do."
    exit 0
  fi
else
  # Fallback: check vendor 0x10de in sysfs
  if ! grep -qi '^0x10de$' /sys/bus/pci/devices/*/vendor 2>/dev/null; then
    log "No NVIDIA GPU detected (sysfs); nothing to do."
    exit 0
  fi
fi

# Ensure hard dependencies exist (rpm2cpio, cpio, xz for extracting cache RPMs, etc.)
need_tools=(rpm2cpio cpio xz modprobe depmod modinfo)
for bin in "${need_tools[@]}"; do command -v "$bin" >/dev/null 2>&1 || fail "Missing tool: $bin"; done

# has module currently loaded?
_have_mod() { lsmod | awk '{print $1}' | grep -qx "$1"; }

# copy kernel metadata into staged tree so depmod can compute dependencies
_copy_kernel_meta() {
  local src="/lib/modules/${KVER}"
  install -d -m 0755 "${BASE}"
  for f in modules.order modules.builtin modules.builtin.modinfo; do
    [[ -f "${src}/${f}" ]] && install -m 0644 "${src}/${f}" "${BASE}/${f}"
  done
}

# label staged files for SELinux so kernel can read modules from our private tree
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

# try to remove nouveau if it’s in the way; if in use, warn and continue
_try_unload_nouveau() {
  if _have_mod nouveau; then
    log "Detected nouveau loaded; attempting to unload."
    /usr/sbin/modprobe -r nouveau 2>/dev/null || true
    _have_mod nouveau && { log "Could not unload nouveau (in use). Reboot with nouveau blacklisted."; return 1; }
    log "Unloaded nouveau."
  fi
  return 0
}

# stage /etc/modprobe.d into the private root so modprobe -d sees the right options
_sync_modprobe_conf_into_root() {
  install -d -m 0755 "${ROOT}/etc/modprobe.d"
  if [[ -d /etc/modprobe.d ]]; then
    for f in /etc/modprobe.d/*.conf; do
      [[ -f "$f" ]] || continue
      [[ "$(basename -- "$f")" == "$(basename -- "$REQ_MODPROBE_CONF")" ]] && continue
      install -m 0644 "$f" "${ROOT}/etc/modprobe.d/$(basename -- "$f")"
    done
  fi
  printf '%s\n' "${REQ_MODPROBE_LINE}" > "${ROOT}${REQ_MODPROBE_CONF}"
}

# load modules from the staged tree, honoring options/aliases via modprobe -d
_load_stack_from_staged() {
  depmod -b "${ROOT}" "${KVER}"
  for name in nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem; do
    local file="${MODDIR}/${name//_/-}.ko"
    [[ -f "${file}" ]] || continue
    if [[ "${name}" == "nvidia_drm" ]]; then
      /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" nvidia_drm modeset=1 fbdev=1 2>/dev/null || \
      /usr/sbin/insmod "${file}" modeset=1 fbdev=1 2>/dev/null || true
    else
      /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" "${name}" 2>/dev/null || \
      /usr/sbin/insmod "${file}" 2>/dev/null || true
    fi
  done
  _have_mod nvidia && _have_mod nvidia_drm
}

# ensure /dev nodes are present/permissions sane for user-space to talk to the driver
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

# post-failure hints for common pitfalls (e.g., OpenRM/GSP on non-GSP GPUs)
_post_fail_hints() {
  local logtail; logtail="$(dmesg | tail -n 800 || true)"
  if grep -q 'does not include the required GPU System Processor' <<<"$logtail"; then
    log "Detected OpenRM/GSP error on a non-GSP GPU (e.g., Pascal)."
    log "Ensure /etc/nvidia/kernel.conf contains 'kernel' (proprietary) and rebuild akmods."
    exit 42
  fi
}

# is Secure Boot enabled?
_sb_enabled() {
  command -v mokutil >/dev/null 2>&1 || return 1
  mokutil --sb-state 2>/dev/null | grep -qi 'enabled'
}

# sign staged modules if needed; error if SB is on and signing impossible (unless bypassed)
_sign_staged_modules_if_needed() {
  local PRIV="/etc/pki/akmods/private/private_key.priv"
  local PUB="/etc/pki/akmods/certs/public_key.der"
  local need_sign=0

  # If Secure Boot is disabled, we don't require signatures
  if ! _sb_enabled; then
    log "Secure Boot disabled; skipping module signing."
    return 0
  fi

  # If any staged module is unsigned, we must sign it
  for f in "${NV_FILES[@]}"; do
    local dest="${MODDIR}/${f}"
    [[ -f "${dest}" ]] || continue
    local signer; signer="$(/usr/sbin/modinfo -F signer "${dest}" 2>/dev/null | tr -d '\n' || true)"
    if [[ -z "${signer}" ]]; then
      need_sign=1
      break
    fi
  done

  # Nothing to do if all are already signed
  if [[ "${need_sign}" -eq 0 ]]; then
    log "All staged NVIDIA modules already signed."
    return 0
  fi

  # Enforce prerequisites (unless bypassed)
  if [[ -z "${NVIDIA_AKMODS_IGNORE_SB:-}" ]]; then
    command -v kmodsign >/dev/null 2>&1 || \
      fail "Secure Boot enabled but kmodsign not found. Install kmod, then rerun."
    [[ -f "${PRIV}" && -f "${PUB}" ]] || \
      fail "Secure Boot enabled but akmods keys missing.
Create or install keys at:
  ${PRIV}
  ${PUB}
Then enroll the public key and reboot:
  sudo mokutil --import ${PUB}
  [set a one-time password, then reboot and enroll in MOK manager]"
  else
    log "Secure Boot enabled but bypass requested (NVIDIA_AKMODS_IGNORE_SB=1); NOT signing."
    return 0
  fi

  log "Signing NVIDIA modules with akmods key (Secure Boot)…"
  for f in "${NV_FILES[@]}"; do
    local dest="${MODDIR}/${f}"
    [[ -f "${dest}" ]] || continue
    # Only sign if unsigned
    local signer; signer="$(/usr/sbin/modinfo -F signer "${dest}" 2>/dev/null | tr -d '\n' || true)"
    if [[ -z "${signer}" ]]; then
      kmodsign sha512 "${PRIV}" "${PUB}" "${dest}" || fail "kmodsign failed for ${f}"
    fi
  done
}

# ---------------- POLICY: enforce proprietary flavor (Negativo17 packaging) ---
# Open (kernel-open) can break on non-GSP GPUs; force proprietary flavor.
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

# ---------------- POLICY: ensure DRM modeset=1 for Wayland/mutter stability ----
if ! grep -qsF "${REQ_MODPROBE_LINE}" "${REQ_MODPROBE_CONF}" 2>/dev/null; then
  log "Writing ${REQ_MODPROBE_CONF}"
  printf '%s\n' "${REQ_MODPROBE_LINE}" | tee "${REQ_MODPROBE_CONF}" >/dev/null
fi

# ---------------- FAST PATH ---------------------------------------------------
# If staged modules exist and match this driver & kernel, load them immediately.
if [[ -f "${MODPATH}" ]]; then
  lic="$(/usr/sbin/modinfo -l "${MODPATH}" 2>/dev/null || true)"
  if [[ "${lic}" == "Dual MIT/GPL" ]]; then
    log "Found staged kernel-open module on a non-GSP GPU; removing staged tree."
    rm -rf "${ROOT}"
  fi
fi

# Invalidate staged modules if driver EVR changed (prevents stale fast-path loads).
if [[ -n "${PKG_VER}" ]]; then
  mismatch=0
  if [[ -n "${MOD_VER}" && "${PKG_VER}" != "${MOD_VER}" ]]; then
    mismatch=1
  else
    # Double-check another sentinel to be safe
    for _m in nvidia nvidia-modeset; do
      _f="${MODDIR}/${_m//_/-}.ko"
      [[ -f "${_f}" ]] || continue
      _v="$("/usr/sbin/modinfo" -F version "${_f}" 2>/dev/null || echo '')"
      if [[ -n "${_v}" && "${_v}" != "${PKG_VER}" ]]; then
        mismatch=1; break
      fi
    done
  fi
  if (( mismatch )); then
    log "Driver update detected (pkg ${PKG_VER} != staged module version); clearing staged modules."
    rm -rf "${ROOT}"
  fi
fi

if [[ -f "${MODPATH}" ]]; then
  log "Fast path candidate found at ${MODPATH}."
  _label_selinux
  _copy_kernel_meta
  _sync_modprobe_conf_into_root
  _sign_staged_modules_if_needed
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
# If fast path failed/missing, build cached kmods for this kernel and stage them.
command -v akmods >/dev/null 2>&1 || fail "Missing tool: akmods"
rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1 || \
  fail "Missing kernel-devel for ${KVER} (dnf -y install kernel-devel-${KVER})"

log "Building akmod 'nvidia' for ${KVER} (cache artifact only)."
/usr/sbin/akmods --kernels "${KVER}" --akmod nvidia || \
  log "WARNING: akmods returned non-zero; continuing with best-effort."

# Prefer exact kernel-targeted RPM first; fall back to generic cache as last resort
RPM="$(ls -1t "${CACHE_DIR}"/*-for-"${KVER}".rpm 2>/dev/null | head -n1 || true)"
if [[ -z "${RPM}" ]]; then
  RPM="$(ls -1t "${CACHE_DIR}"/kmod-nvidia-*.rpm 2>/dev/null | head -n1 || true)"
fi

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
_sign_staged_modules_if_needed

# --------- Secure Boot hint ---------------------------------------------------
if _sb_enabled; then
  log "Secure Boot is enabled; unsigned modules will be rejected."
fi

# ---------------- VERIFY / DIAGNOSTICS ---------------------------------------
# Load from staged tree, verify nvidia-smi works, emit modeset status; else print hints.
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

VMOD="$(/usr/sbin/modinfo -F vermagic "${MODPATH}" 2>/dev/null | awk '{print $1}')"
if [[ -n "${VMOD}" && "${VMOD}" != "${KVER}" ]]; then
  log "Note: vermagic=${VMOD}, running kernel=${KVER}. If Secure Boot is on, ensure MOK enrolled and modules signed."
fi

_post_fail_hints
dmesg | tail -n 200 || true
fail "Failed to load NVIDIA modules."
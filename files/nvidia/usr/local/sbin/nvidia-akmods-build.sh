#!/usr/bin/env bash
# Build (via akmods), stage, bind-mount, and load NVIDIA modules for the current kernel on ostree systems.
# Mirrors the working wl flow: reloads when marked, clears mark if files missing, builds only when needed.

set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/nvidia-akmods/done-${KVER}"
WORK="/var/lib/nvidia-spool"
SRC_BASE="/var/lib/nvidia-mount/${KVER}/updates"
SRC_NVIDIA="${SRC_BASE}/nvidia"
DST="/usr/lib/modules/${KVER}/updates"
UNIT="$(systemd-escape --path --suffix=mount "${DST}")"  # e.g. usr-lib-modules-<...>-updates.mount

log(){ echo "[nvidia-akmods] $*"; }

restore_label(){
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    command -v restorecon >/dev/null 2>&1 && restorecon -RF "$1" || true
  fi
}

ensure_mount_unit(){
  install -d -m 0755 "${DST}"
  restore_label "${DST}"
  local unit_path="/etc/systemd/system/${UNIT}"
  if [ ! -f "${unit_path}" ]; then
    install -d -m 0755 /etc/systemd/system
    cat > "${unit_path}" <<EOF
[Unit]
Description=Bind mount for kernel updates (akmods staging) for ${KVER}
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target

[Mount]
What=${SRC_BASE}
Where=${DST}
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now "${UNIT}"
  else
    systemctl is-active --quiet "${UNIT}" || systemctl start "${UNIT}"
  fi
  mountpoint -q "${DST}" && restore_label "${DST}"
}

blacklist_conf(){
  install -d -m 0755 /etc/modprobe.d
  cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
EOF
  cat > /etc/modprobe.d/nvidia-kms.conf <<'EOF'
options nvidia-drm modeset=1
EOF
}

ensure_akmods_key(){
  if [ -x /usr/local/sbin/akmods-key-ensure.sh ]; then
    /usr/local/sbin/akmods-key-ensure.sh || true
    return
  fi
  local der="/etc/pki/akmods/certs/public_key.der"
  if [ ! -f "${der}" ] && command -v kmodgenca >/dev/null 2>&1; then
    log "No akmods key found; generating via kmodgenca -a"
    kmodgenca -a || true
  fi
  # If Secure Boot is enabled, MOK enrollment of the DER is still required once.
}

try_insmod(){
  depmod -a "${KVER}" || true
  modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null || true
  modprobe nvidia || insmod "${DST}/nvidia/nvidia.ko" || return 1
  modprobe nvidia-modeset 2>/dev/null || insmod "${DST}/nvidia/nvidia-modeset.ko" || true
  modprobe nvidia-uvm     2>/dev/null || insmod "${DST}/nvidia/nvidia-uvm.ko"     || true
  modprobe nvidia-drm     2>/dev/null || insmod "${DST}/nvidia/nvidia-drm.ko"     || true
  return 0
}

have_any_nvidia(){
  # true if we see staged or mounted NVIDIA modules
  [ -e "${SRC_NVIDIA}/nvidia.ko" ] || [ -e "${DST}/nvidia/nvidia.ko" ]
}

stage_existing(){
  # Copy any built nvidia*.ko* we can find into staging
  local -a roots=(
    "/var/lib/akmods/${KVER}/extra/nvidia"
    "/var/lib/akmods/${KVER}/weak-updates/nvidia"
    "/usr/lib/modules/${KVER}/extra/nvidia"
    "/lib/modules/${KVER}/extra/nvidia"
    "/var/cache/akmods/nvidia"
  )
  local -a found=()
  for r in "${roots[@]}"; do
    [ -d "$r" ] || continue
    while IFS= read -r -d '' f; do
      found+=("$f")
    done < <(find "$r" -type f -name 'nvidia*.ko*' -print0 2>/dev/null || true)
  done
  [ "${#found[@]}" -gt 0 ] || return 1

  install -d -m 0755 "${SRC_NVIDIA}"
  for f in "${found[@]}"; do
    install -m 0644 "$f" "${SRC_NVIDIA}/"
  done
  restore_label "${SRC_BASE}"
  return 0
}

build_with_akmods(){
  if ! command -v akmods >/dev/null 2>&1; then
    log "ERROR: akmods not installed. Ensure akmod-nvidia is installed from negativo17."
    return 1
  fi
  log "Building akmods for --akmod nvidia on ${KVER} (only if needed)"
  /usr/sbin/akmods --akmod nvidia --kernels "${KVER}" || true
}

# ──────────────────────────────────────────────────────────────────────────────
# 0) If mark exists but modules are actually missing (e.g. after a base update), clear the mark to force restage.
if [[ -f "${MARK}" && ! -e "${DST}/nvidia/nvidia.ko" && ! -e "${SRC_NVIDIA}/nvidia.ko" ]]; then
  rm -f "${MARK}"
fi

# 1) If we’ve already done this for this kernel, ensure mount/labels, then (re)load.
if [[ -f "${MARK}" ]]; then
  ensure_mount_unit
  restore_label "${SRC_BASE}"
  mountpoint -q "${DST}" && restore_label "${DST}"
  blacklist_conf
  try_insmod || log "WARN: module load failed; check Secure Boot / MOK and dmesg."
  exit 0
fi

# 2) If modules already exist somewhere, just stage them and finish.
if stage_existing; then
  ensure_mount_unit
  restore_label "${SRC_BASE}"
  mountpoint -q "${DST}" && restore_label "${DST}"
  blacklist_conf
  try_insmod || true
  install -d -m 0755 /var/lib/nvidia-akmods
  : > "${MARK}"
  log "used existing nvidia*.ko for ${KVER}"
  exit 0
fi

# 3) No modules yet: ensure key, build with akmods, stage whatever was produced.
ensure_akmods_key
build_with_akmods || true
if ! stage_existing; then
  log "ERROR: Could not locate built NVIDIA modules for ${KVER}. See /var/cache/akmods/nvidia/*.log"
  exit 1
fi

# 4) Bind-mount -> relabel -> blacklist -> load -> mark
ensure_mount_unit
restore_label "${SRC_BASE}"
mountpoint -q "${DST}" && restore_label "${DST}"
blacklist_conf
try_insmod || true

install -d -m 0755 /var/lib/nvidia-akmods
: > "${MARK}"
log "nvidia modules staged/mounted for ${KVER}"

#!/usr/bin/env bash
# Build + stage NVIDIA kmods from negativo17's akmod-nvidia on immutable/ostree systems.
# Safe to run at boot or manually; re-runs are idempotent.

set -euo pipefail

log() { echo "[nvidia-akmods] $*"; }

KVER="$(uname -r)"
STATE_DIR="/var/lib/nvidia-akmods"
MARK="${STATE_DIR}/done-${KVER}"

# Stage modules to a writable tree and bind-mount into /usr/lib/modules/<kver>/updates
SRC_BASE="/var/lib/nvidia-mount/${KVER}/updates"
SRC_DIR="${SRC_BASE}/nvidia"
DST_BASE="/usr/lib/modules/${KVER}/updates"
DST_MOUNT_UNIT="$(systemd-escape --path --suffix=mount "${DST_BASE}")"

restore_label() {
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    command -v restorecon >/dev/null 2>&1 && restorecon -RF "$1" || true
  fi
}

ensure_akmods_key() {
  if [ -x /usr/local/sbin/akmods-key-ensure.sh ]; then
    /usr/local/sbin/akmods-key-ensure.sh || true
    return
  fi
  local der="/etc/pki/akmods/certs/public_key.der"
  if [ ! -f "$der" ] && command -v kmodgenca >/dev/null 2>&1; then
    log "No akmods key detected; generating with kmodgenca -a"
    kmodgenca -a || true
  fi
  # If Secure Boot is enabled, remember to MOK-enroll the DER once.
}

ensure_updates_bind_mount() {
  install -d -m 0755 "${SRC_BASE}" "${DST_BASE}"
  restore_label "${SRC_BASE}" ; restore_label "${DST_BASE}"

  local unit_path="/etc/systemd/system/${DST_MOUNT_UNIT}"
  if [ ! -f "${unit_path}" ]; then
    install -d -m 0755 /etc/systemd/system
    cat > "${unit_path}" <<EOF
[Unit]
Description=Bind mount for /usr/lib/modules/${KVER}/updates (akmods staging)
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target

[Mount]
What=${SRC_BASE}
Where=${DST_BASE}
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now "${DST_MOUNT_UNIT}"
  else
    systemctl is-active --quiet "${DST_MOUNT_UNIT}" || systemctl start "${DST_MOUNT_UNIT}"
  fi

  restore_label "${DST_BASE}"
}

blacklist_nouveau_and_enable_kms() {
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

build_akmod_nvidia() {
  if ! command -v akmods >/dev/null 2>&1; then
    log "ERROR: akmods not installed. Ensure negativo17 repo and akmod-nvidia are installed."
    return 1
  fi
  log "Building akmods for --akmod nvidia on ${KVER} (only if needed)"
  akmods --akmod nvidia --kernels "${KVER}" || true
}

collect_built_modules() {
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

  install -d -m 0755 "${SRC_DIR}"
  for f in "${found[@]}"; do
    install -m 0644 "$f" "${SRC_DIR}/"
  done
  restore_label "${SRC_DIR}"
}

load_modules() {
  depmod -a "${KVER}" || true
  modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null || true

  local rc=0
  modprobe nvidia || rc=1
  modprobe nvidia-modeset 2>/dev/null || true
  modprobe nvidia-uvm 2>/dev/null || true
  modprobe nvidia-drm 2>/dev/null || true
  return "${rc}"
}

main() {
  if [ -f "${MARK}" ]; then
    log "Already staged for ${KVER}; nothing to do."
    exit 0
  fi

  if ! rpm -q akmod-nvidia >/dev/null 2>&1; then
    log "ERROR: akmod-nvidia not installed. Install it from negativo17 and re-run."
    exit 1
  fi

  ensure_akmods_key
  blacklist_nouveau_and_enable_kms
  build_akmod_nvidia || true

  if ! collect_built_modules; then
    log "ERROR: No built NVIDIA modules found for ${KVER}."
    log "Check akmods logs under: /var/cache/akmods/nvidia/ and dmesg."
    exit 1
  fi

  ensure_updates_bind_mount

  if ! load_modules; then
    log "WARN: modprobe nvidia failed. If Secure Boot is enabled, MOK enrollment is likely required."
  fi

  install -d -m 0755 "${STATE_DIR}"
  : > "${MARK}"
  log "NVIDIA modules staged (and mounted) for ${KVER}."
}

main "$@"

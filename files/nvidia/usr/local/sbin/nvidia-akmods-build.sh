#!/usr/bin/env bash
# Build (via akmods), stage, bind-mount, and load NVIDIA kmods for the current kernel on ostree/immutable systems.
# Idempotent: will only rebuild/restage when needed; safe to run at boot or manually.

set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/nvidia-akmods/done-${KVER}"
WORK="/var/lib/nvidia-spool"
SRC_BASE="/var/lib/nvidia-mount/${KVER}/updates"
SRC_NVIDIA="${SRC_BASE}/nvidia"
DST="/usr/lib/modules/${KVER}/updates"
UNIT="$(systemd-escape --path --suffix=mount "${DST}")"  # e.g. usr-lib-modules-<...>-updates.mount

log() { echo "[nvidia-akmods] $*"; }

restore_label() {
  # Ensure SELinux labels allow module_load on staged files and bind-mounted target
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    command -v restorecon >/dev/null 2>&1 && restorecon -RF "$1" || true
  fi
}

ensure_mount_unit() {
  # Ensure our bind-mount of /usr/lib/modules/<kver>/updates exists via a systemd .mount
  install -d -m 0755 "${DST}"
  restore_label "${DST}"

  # Create a transient .mount unit if a unit file doesn't already exist
  if ! systemctl is-enabled --quiet "${UNIT}" 2>/dev/null; then
    # Create a drop-in mount unit
    local unit_path="/etc/systemd/system/${UNIT}"
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
    # If unit exists but not started, start it
    systemctl is-active --quiet "${UNIT}" || systemctl start "${UNIT}"
  fi

  # If someone manually mounted it, make sure the label is sane
  if mountpoint -q "${DST}"; then
    restore_label "${DST}"
  fi
}

blacklist_conf() {
  # Blacklist nouveau (and its fbdev helper) to avoid conflicts
  install -d -m 0755 /etc/modprobe.d
  cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
EOF
  # Enable DRM KMS for NVIDIA (optional but recommended)
  cat > /etc/modprobe.d/nvidia-kms.conf <<'EOF'
options nvidia-drm modeset=1
EOF
}

ensure_akmods_key() {
  # Try your helper if present; otherwise, generate if missing.
  if [ -x /usr/local/sbin/akmods-key-ensure.sh ]; then
    /usr/local/sbin/akmods-key-ensure.sh || true
    return
  fi
  local pub="/etc/pki/akmods/certs/public_key.der"
  if [ ! -f "${pub}" ]; then
    if command -v kmodgenca >/dev/null 2>&1; then
      log "No akmods key found; generating via kmodgenca -a"
      kmodgenca -a || true
    fi
    # Note: mokutil enrollment typically handled elsewhere during provisioning
  fi
}

find_built_modules() {
  # Heuristics to locate nvidia*.ko produced/installed by akmods for this KVER.
  # We gather the core set if present: nvidia, nvidia-modeset, nvidia-uvm, nvidia-drm, nvidia-peermem
  local -a candidates=(
    "/usr/lib/modules/${KVER}/extra/nvidia"
    "/lib/modules/${KVER}/extra/nvidia"
    "/var/lib/akmods/${KVER}/extra/nvidia"
    "/var/lib/akmods/${KVER}/weak-updates/nvidia"
    "/var/cache/akmods/nvidia"
  )
  local -a found=()
  for base in "${candidates[@]}"; do
    [ -d "${base}" ] || continue
    while IFS= read -r -d '' f; do
      found+=("$f")
    done < <(find "${base}" -type f -name 'nvidia*.ko*' -print0 2>/dev/null || true)
  done

  if [ "${#found[@]}" -eq 0 ]; then
    return 1
  fi

  # Filter to the key modules if multiple versions are present
  # Prefer the plain .ko over compressed variants where both exist
  local -a need=(nvidia nvidia-modeset nvidia-uvm nvidia-drm nvidia-peermem)
  local -A best=()
  for mod in "${need[@]}"; do
    local picked=""
    for f in "${found[@]}"; do
      case "$(basename "$f")" in
        "${mod}.ko") picked="$f"; break ;;
        "${mod}.ko."*) [ -z "$picked" ] && picked="$f" ;;
      esac
    done
    if [ -n "$picked" ]; then best["$mod"]="$picked"; fi
  done

  # Always include core nvidia.ko if available
  if [ -z "${best[nvidia]:-}" ]; then
    return 1
  fi

  # Emit list to stdout
  for k in "${!best[@]}"; do
    echo "${best[$k]}"
  done
  return 0
}

try_insmod() {
  # Load in safe order; ignore failures for optional modules
  depmod -a "${KVER}" || true
  modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null || true

  # Core
  modprobe nvidia || insmod "${DST}/nvidia/nvidia.ko" || return 1
  # Stack
  modprobe nvidia-modeset 2>/dev/null || insmod "${DST}/nvidia/nvidia-modeset.ko" || true
  modprobe nvidia-uvm 2>/dev/null || insmod "${DST}/nvidia/nvidia-uvm.ko" || true
  modprobe nvidia-drm 2>/dev/null || insmod "${DST}/nvidia/nvidia-drm.ko" || true

  return 0
}

main() {
  if [ -f "${MARK}" ]; then
    log "Already done for ${KVER}; exiting."
    exit 0
  fi

  ensure_akmods_key

  # 1) Build via akmods (if not already)
  log "Building akmods for nvidia on ${KVER} (if needed)"
  if command -v akmods >/dev/null 2>&1; then
    akmods --force --kernels "${KVER}" nvidia || true
  else
    log "akmods not found; expecting modules to be present from prior build/install"
  fi

  # 2) Locate built modules
  log "Searching for built nvidia*.ko for ${KVER}"
  mapfile -t MODULES < <(find_built_modules || true)
  if [ "${#MODULES[@]}" -eq 0 ]; then
    log "ERROR: Could not locate built NVIDIA modules for ${KVER}. See /var/cache/akmods/nvidia/*.log for details."
    exit 1
  fi
  for m in "${MODULES[@]}"; do log "Found: ${m}"; done

  # 3) Stage into our mountable updates/ tree
  install -d -m 0755 "${SRC_NVIDIA}"
  for f in "${MODULES[@]}"; do
    base="$(basename "$f")"
    install -m 0644 "${f}" "${SRC_NVIDIA}/${base%.*}.ko"
  done
  restore_label "${SRC_BASE}"

  # 4) Bind-mount -> relabel -> blacklist -> load -> mark
  ensure_mount_unit
  restore_label "${SRC_BASE}"
  if mountpoint -q "${DST}"; then restore_label "${DST}"; fi
  blacklist_conf
  if ! try_insmod; then
    log "WARN: Module load failed; will still mark as staged/mounted. Check dmesg and ensure Secure Boot/MOK enrollment."
  fi

  # 5) Mark done
  install -d -m 0755 /var/lib/nvidia-akmods
  : > "${MARK}"
  log "NVIDIA modules staged/mounted for ${KVER}"
}

main "$@"

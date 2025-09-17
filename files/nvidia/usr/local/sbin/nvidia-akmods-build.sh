#!/usr/bin/env bash
# nvidia-akmods-build.sh
# Build via akmods, harvest modules (from loose .ko, results/, OR by extracting the kmod RPM),
# stage to /var/lib/nvidia-mount/<kver>/updates/nvidia, bind-mount to /usr/lib/modules/<kver>/updates, and load.

set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/nvidia-akmods/done-${KVER}"
SRC_BASE="/var/lib/nvidia-mount/${KVER}/updates"
SRC_NVIDIA="${SRC_BASE}/nvidia"
DST="/usr/lib/modules/${KVER}/updates"
UNIT="$(systemd-escape --path --suffix=mount "${DST}")"

log(){ echo "[nvidia-akmods] $*"; }

restore_label(){
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    command -v restorecon >/dev/null 2>&1 && restorecon -RF "$1" || true
  fi
}

ensure_mount_unit(){
  install -d -m 0755 "${DST}"
  restore_label "${DST}"
  if ! systemctl list-unit-files --type=mount | grep -q "^${UNIT}"; then
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
  local pub="/etc/pki/akmods/certs/public_key.der"
  if [ ! -f "${pub}" ] && command -v kmodgenca >/dev/null 2>&1; then
    log "Generating akmods key (kmodgenca -a)"
    kmodgenca -a || true
  fi
}

# --- Harvesters --------------------------------------------------------------

# 1) Find loose .ko files produced by akmods
harvest_from_paths(){
  local -a candidates=(
    "/usr/lib/modules/${KVER}/extra/nvidia"
    "/lib/modules/${KVER}/extra/nvidia"
    "/var/lib/akmods/${KVER}/extra/nvidia"
    "/var/lib/akmods/${KVER}/weak-updates/nvidia"
    "/var/cache/akmods/nvidia"
    "/var/cache/akmods/nvidia/*-for-${KVER}*/results/kmods"
    "/var/cache/akmods/nvidia/*-for-${KVER}*/results"
    "/tmp/akmods*/results/kmods"
    "/tmp/akmods*/results"
  )

  local -a found=()
  for base in "${candidates[@]}"; do
    for d in $(compgen -G "$base" || true); do
      [ -d "$d" ] || continue
      while IFS= read -r -d '' f; do
        found+=("$f")
      done < <(find "$d" -type f -name 'nvidia*.ko*' -print0 2>/dev/null || true)
    done
  done

  if [ "${#found[@]}" -gt 0 ]; then
    # Prefer uncompressed .ko when both exist
    local -a need=(nvidia nvidia-modeset nvidia-uvm nvidia-drm nvidia-peermem)
    declare -A best=()
    for mod in "${need[@]}"; do
      local picked=""
      for f in "${found[@]}"; do
        case "$(basename "$f")" in
          "${mod}.ko") picked="$f"; break ;;
          "${mod}.ko."*) [ -z "$picked" ] && picked="$f" ;;
        esac
      done
      [ -n "$picked" ] && best["$mod"]="$picked"
    done
    [ -n "${best[nvidia]:-}" ] || return 1
    printf '%s\n' "${best[@]}"
    return 0
  fi
  return 1
}

# 2) Extract .ko from kmod RPM that akmods left in results/
harvest_from_kmod_rpm(){
  local rpm
  rpm="$(ls -1 /var/cache/akmods/nvidia/*-for-${KVER}*/results/kmod-nvidia-*.rpm /tmp/akmods.*/results/kmod-nvidia-*.rpm 2>/dev/null | head -n1 || true)"
  [ -n "${rpm:-}" ] || return 1
  log "Extracting modules from $(basename "$rpm")"
  local tmpd; tmpd="$(mktemp -d)"
  ( cd "$tmpd" && rpm2cpio "$rpm" | cpio -idmv >/dev/null 2>&1 )
  find "$tmpd/lib/modules/${KVER}/extra/nvidia" -type f -name 'nvidia*.ko*' -print 2>/dev/null || true
}

# ---------------------------------------------------------------------------

stage_modules(){
  install -d -m 0755 "${SRC_NVIDIA}"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    local base; base="$(basename "$f")"
    if [[ "$base" == *.ko.* ]]; then
      install -m 0644 "$f" "${SRC_NVIDIA}/${base%%.ko.*}.ko"
    else
      install -m 0644 "$f" "${SRC_NVIDIA}/${base}"
    fi
  done
  restore_label "${SRC_BASE}"
}

try_insmod(){
  depmod -a "${KVER}" || true
  modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null || true
  modprobe nvidia 2>/dev/null || insmod "${DST}/nvidia/nvidia.ko" || return 1
  modprobe nvidia-modeset 2>/dev/null || insmod "${DST}/nvidia/nvidia-modeset.ko" || true
  modprobe nvidia-uvm 2>/dev/null || insmod "${DST}/nvidia/nvidia-uvm.ko" || true
  modprobe nvidia-drm 2>/dev/null || insmod "${DST}/nvidia/nvidia-drm.ko" || true
  return 0
}

main(){
  if [ -f "${MARK}" ]; then
    log "Already done for ${KVER}; exiting."
    exit 0
  fi

  ensure_akmods_key

  log "Building akmods for --akmod nvidia on ${KVER} (only if needed)"
  if command -v akmods >/dev/null 2>&1; then
    akmods --kernels "${KVER}" --akmod nvidia || log "akmods failed to install RPM (expected on immutable); will harvest results."
  else
    log "akmods not found; expecting modules to exist from prior build"
  fi

  log "Searching for built nvidia*.ko for ${KVER}"
  mapfile -t MODULES < <(harvest_from_paths || true)
  if [ "${#MODULES[@]}" -eq 0 ]; then
    log "No loose .ko found; attempting to extract from kmod RPM cache..."
    mapfile -t MODULES < <(harvest_from_kmod_rpm || true)
  fi
  if [ "${#MODULES[@]}" -eq 0 ]; then
    log "ERROR: Could not locate built NVIDIA modules for ${KVER}. Check /var/cache/akmods/nvidia/*failed.log"
    exit 1
  fi
  for m in "${MODULES[@]}"; do log "Found: $m"; done

  stage_modules

  ensure_mount_unit
  restore_label "${SRC_BASE}"
  mountpoint -q "${DST}" && restore_label "${DST}"

  blacklist_conf

  if ! try_insmod; then
    log "WARN: Module load failed; check dmesg for signature/symbol errors (Secure Boot MOK enrollment may be needed)."
  fi

  install -d -m 0755 /var/lib/nvidia-akmods
  : > "${MARK}"
  log "NVIDIA modules staged/mounted for ${KVER}"
}

main "$@"

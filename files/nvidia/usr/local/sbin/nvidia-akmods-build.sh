#!/usr/bin/env bash
# nvidia-akmods-build.sh
# Build (via akmods), harvest, stage, bind-mount, and load NVIDIA kmods on ostree/immutable systems.
# - Works even when akmods cannot "install" the RPM (common on read-only /usr).
# - Idempotent per kernel version.
# - Handles SELinux labels, nouveau blacklist, and nvidia-drm KMS.
# - Stages modules under /var/lib/nvidia-mount/<kver>/updates/nvidia and bind-mounts to /usr/lib/modules/<kver>/updates.
# - Tries to ensure an akmods signing key; actual MOK enrollment is up to provisioning if Secure Boot is enabled.

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
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    command -v restorecon >/dev/null 2>&1 && restorecon -RF "$1" || true
  fi
}

ensure_mount_unit() {
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

  if mountpoint -q "${DST}"; then
    restore_label "${DST}"
  fi
}

blacklist_conf() {
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

ensure_akmods_key() {
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
  fi
}

find_built_modules() {
  # Locate nvidia*.ko produced by akmods for this KVER, including "results/kmods" when RPM install fails.
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

  if [ "${#found[@]}" -eq 0 ]; then
    return 1
  fi

  # Prefer uncompressed .ko if both exist. Target the common set.
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
  for k in "${!best[@]}"; do echo "${best[$k]}"; done
  return 0
}

try_insmod() {
  depmod -a "${KVER}" || true
  modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null || true

  # Core + stack; ignore optional failures
  modprobe nvidia 2>/dev/null || insmod "${DST}/nvidia/nvidia.ko" || return 1
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

  log "Building akmods for --akmod nvidia on ${KVER} (only if needed)"
  if command -v akmods >/dev/null 2>&1; then
    # akmods will often compile but fail to install the RPM on ostree; that's fine—we harvest results.
    if ! akmods --kernels "${KVER}" --akmod nvidia; then
      log "akmods reported a failure (likely RPM install on immutable). Proceeding to harvest any compiled results."
    fi
  else
    log "akmods not found; expecting modules to be present from prior build/install"
  fi

  log "Searching for built nvidia*.ko for ${KVER}"
  mapfile -t MODULES < <(find_built_modules || true)
  if [ "${#MODULES[@]}" -eq 0 ]; then
    log "ERROR: Could not locate built NVIDIA modules for ${KVER}. See /var/cache/akmods/nvidia/*.log for details."
    exit 1
  fi
  for m in "${MODULES[@]}"; do log "Found: ${m}"; done

  # Stage into mountable updates tree
  install -d -m 0755 "${SRC_NVIDIA}"
  for f in "${MODULES[@]}"; do
    base="$(basename "$f")"
    # Normalize name to .ko (strip compression extension if any)
    if [[ "$base" == *.ko.* ]]; then
      # If compressed, copy as-is but drop extension in target name to .ko
      install -m 0644 "$f" "${SRC_NVIDIA}/${base%%.ko.*}.ko"
    else
      install -m 0644 "$f" "${SRC_NVIDIA}/${base}"
    fi
  done
  restore_label "${SRC_BASE}"

  ensure_mount_unit
  restore_label "${SRC_BASE}"
  if mountpoint -q "${DST}"; then restore_label "${DST}"; fi

  blacklist_conf

  if ! try_insmod; then
    log "WARN: Module load failed; check dmesg for signature or symbol errors (Secure Boot/MOK enrollment may be required)."
  fi

  install -d -m 0755 /var/lib/nvidia-akmods
  : > "${MARK}"
  log "NVIDIA modules staged/mounted for ${KVER}"
}

main "$@"

#!/usr/bin/env bash
# Build (via akmods), stage, bind-mount, and load Broadcom wl for the current kernel on ostree systems.
# Idempotent: will only rebuild/restage when needed; safe to run at boot or manually.

set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
WORK="/var/lib/wl-spool"
SRC_BASE="/var/lib/wl-mount/${KVER}/updates"
SRC_WL="${SRC_BASE}/wl"
DST="/usr/lib/modules/${KVER}/updates"
UNIT="$(systemd-escape --path --suffix=mount "${DST}")"  # e.g. usr-lib-modules-<...>-updates.mount

restore_label() {
  # Ensure SELinux labels allow module_load on staged files and bind-mounted target
  local path="$1"
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -Rv "${path}" || true
  else
    # Fallback if relabel tool is unavailable
    chcon -R -t modules_object_t "${path}" || true
  fi
}

ensure_mount_unit() {
  # Create a bind-mount unit whose *name* matches the Where= path (systemd requires this)
  install -d -m 0755 "${SRC_WL}"
  install -d -m 0755 "${DST}" || true

  cat >/etc/systemd/system/"${UNIT}" <<EOF
[Unit]
Description=Bind-mount wl updates for kernel ${KVER}

[Mount]
Where=${DST}
What=${SRC_BASE}
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${UNIT}"
}

blacklist_conf() {
  # Block in-kernel Broadcom drivers that conflict with wl (runtime-only; lives under /run)
  install -d -m 0755 /run/modprobe.d
  cat >/run/modprobe.d/wl-blacklist.conf <<'EOF'
blacklist b43
blacklist bcma
blacklist brcmsmac
EOF
}

try_insmod() {
  # If already loaded, nothing to do
  if lsmod | awk '{print $1}' | grep -qx wl; then
    return 0
  fi

  # Load dependencies first (cfg80211 modular on EL; lib80211 may be built-in)
  local cfg lib80211
  cfg="$(find "/usr/lib/modules/${KVER}" -name 'cfg80211.ko*' -print -quit || true)"
  lib80211="$(find "/usr/lib/modules/${KVER}" -name 'lib80211.ko*' -print -quit || true)"

  [[ -n "${cfg}" ]] && insmod "${cfg}" || true
  [[ -n "${lib80211}" ]] && insmod "${lib80211}" || true

  # Load wl directly by path (modprobe can’t see bind-mounted modules without depmod on ostree)
  insmod "${DST}/wl/wl.ko"
}

# ──────────────────────────────────────────────────────────────────────────────
# 0) If mark exists but wl is actually missing (e.g., after a base update), clear the mark so we restage.
if [[ -f "${MARK}" && ! -e "${DST}/wl/wl.ko" && ! -e "${SRC_WL}/wl.ko" ]]; then
  rm -f "${MARK}"
fi

# 1) If we’ve already done this for this kernel, ensure mount & labels, then try to load.
if [[ -f "${MARK}" ]]; then
  ensure_mount_unit
  # Relabel both sides before inserting (prevents SELinux module_load denials)
  restore_label "${SRC_BASE}"
  if mountpoint -q "${DST}"; then restore_label "${DST}"; fi
  blacklist_conf
  try_insmod || true
  exit 0
fi

# 2) If wl.ko is already present (staged or mounted), just mount + label + load + mark done.
if [[ -e "${DST}/wl/wl.ko" || -e "${SRC_WL}/wl.ko" ]]; then
  ensure_mount_unit
  restore_label "${SRC_BASE}"
  if mountpoint -q "${DST}"; then restore_label "${DST}"; fi
  blacklist_conf
  try_insmod || true
  install -d -m 0755 /var/lib/wl-akmods
  : > "${MARK}"
  echo "[wl-akmods] used existing wl.ko for ${KVER}"
  exit 0
fi

# 3) No wl.ko yet: build with akmods → extract wl.ko from the produced kmod RPM → stage it.
install -d -m 0755 /var/log/akmods || true
/usr/sbin/akmods --kernels "${KVER}" --akmod wl || true

RPM="$(ls -1t /var/cache/akmods/wl/kmod-wl-${KVER%%.*}-*.x86_64.rpm 2>/dev/null | head -n1 || true)"
if [[ -z "${RPM}" || ! -f "${RPM}" ]]; then
  echo "[wl-akmods] ERROR: no kmod-wl RPM produced for ${KVER}"
  exit 1
fi

rm -rf "${WORK}"
install -d -m 0755 "${WORK}"
pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv
FOUND="$(find "${WORK}" -type f \( -name 'wl.ko' -o -name 'wl.ko.xz' \) -print -quit || true)"
popd >/dev/null

if [[ -z "${FOUND}" ]]; then
  echo "[wl-akmods] ERROR: wl.ko(.xz) not found in ${RPM}"
  exit 1
fi

# Decompress if needed and stage to the writable source dir that we bind-mount
if [[ "${FOUND}" == *.xz ]]; then
  xz -df "${FOUND}"
  FOUND="${FOUND%.xz}"
fi

install -d -m 0755 "${SRC_WL}"
install -m 0644 "${FOUND}" "${SRC_WL}/wl.ko"

# 4) Bind-mount -> relabel -> blacklist -> load -> mark
ensure_mount_unit
restore_label "${SRC_BASE}"
if mountpoint -q "${DST}"; then restore_label "${DST}"; fi
blacklist_conf
try_insmod || true

install -d -m 0755 /var/lib/wl-akmods
: > "${MARK}"
echo "[wl-akmods] wl staged/mounted for ${KVER}"
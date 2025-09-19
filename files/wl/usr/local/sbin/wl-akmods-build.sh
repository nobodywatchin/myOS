#!/usr/bin/env bash
# Fast WL loader for rpm-ostree/BootC systems.
# - FAST PATH: if a staged wl.ko matches the running kernel, skip akmods and just load.
# - SLOW PATH (first boot after kernel update): build via akmods, extract to /var, label, then load.
# - Handles SELinux labels, vermagic check, dependency preloads, optional signing.

set -Eeuo pipefail

KVER="$(uname -r)"
WORK="$(mktemp -d -t wl-akmods-XXXXXX)"
CACHE_DIR="/var/cache/akmods/wl"
ROOT="/var/lib/wl-kmods/${KVER}"
MODDIR="${ROOT}/lib/modules/${KVER}/extra/wl"
MODPATH="${MODDIR}/wl.ko"

log()  { echo "[wl-akmods] $*"; }
fail() { echo "[wl-akmods] ERROR: $*" >&2; exit 1; }
cleanup(){ rm -rf "${WORK}"; }
trap cleanup EXIT

need_tools=(rpm2cpio cpio xz modprobe depmod modinfo)
for bin in "${need_tools[@]}"; do command -v "$bin" >/dev/null 2>&1 || fail "Missing tool: $bin"; done

# ----- FAST PATH: use existing staged module if valid -----------------------
if [[ -f "${MODPATH}" ]]; then
  VMOD="$(/usr/sbin/modinfo -F vermagic "${MODPATH}" | awk '{print $1}')"
  if [[ "${VMOD}" == "${KVER}" ]]; then
    log "Fast path: staged wl.ko matches ${KVER}, skipping akmods."
    # Ensure SELinux label is correct so kmod can read it
    if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
      if command -v semanage >/dev/null 2>&1; then
        semanage fcontext -a -t modules_object_t '/var/lib/wl-kmods(/.*)?' 2>/dev/null || true
        restorecon -RF "${ROOT}" || true
      else
        chcon -R -t modules_object_t "${ROOT}" || true
      fi
    fi
    # Preload deps, then load
    DEPS="$({ /usr/sbin/modinfo -F depends "${MODPATH}" || true; } | tr ',' ' ' | xargs -r echo || true)"
    for d in ${DEPS:-}; do /usr/sbin/modprobe "${d}" 2>/dev/null || true; done
    /usr/sbin/modprobe cfg80211 2>/dev/null || true
    depmod -b "${ROOT}" "${KVER}"
    if /usr/sbin/insmod "${MODPATH}" 2>/dev/null || /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" wl; then
      lsmod | grep -q '^wl\s' && { log "Loaded wl (fast path)."; exit 0; }
    fi
    log "Fast path load failed; falling back to build."
  fi
fi

# ----- SLOW PATH: build for this kernel via akmods --------------------------
# Only now do we require headers/akmods
rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1 || \
  fail "Missing kernel-devel for ${KVER} (dnf -y install kernel-devel-${KVER})"
command -v akmods >/dev/null 2>&1 || fail "Missing tool: akmods"

log "Building akmod 'wl' for ${KVER} (first boot after kernel update)..."
if ! /usr/sbin/akmods --kernels "${KVER}" --akmod wl; then
  log "WARNING: akmods install step failed (immutable base). Will use cached RPM if produced."
fi

RPM="$(ls -1t \
  "${CACHE_DIR}"/*-for-"${KVER}".rpm \
  "${CACHE_DIR}"/kmod-wl-*.rpm \
  2>/dev/null | head -n1 || true)"
[[ -n "${RPM}" && -f "${RPM}" ]] || {
  log "Build logs (if any):"; ls -1 "${CACHE_DIR}"/*-for-"${KVER}".{log,failed.log} 2>/dev/null || true
  fail "No kmod-wl RPM produced for ${KVER}."
}
log "Using RPM: ${RPM}"

pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM}"
FOUND="$(find "${WORK}" -type f \( -name 'wl.ko' -o -name 'wl.ko.xz' \) -print -quit || true)"
popd >/dev/null
[[ -n "${FOUND}" ]] || fail "wl.ko(.xz) not found in ${RPM}"
[[ "${FOUND}" == *.xz ]] && xz -df "${FOUND}" && FOUND="${FOUND%.xz}"

install -d -m 0755 "${MODDIR}"
install -m 0644 "${FOUND}" "${MODPATH}"
log "Staged module at ${MODPATH}"

# SELinux label so kmod can read it
if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
  if command -v semanage >/dev/null 2>&1; then
    semanage fcontext -a -t modules_object_t '/var/lib/wl-kmods(/.*)?' 2>/dev/null || true
    restorecon -RF "${ROOT}" || true
  else
    chcon -R -t modules_object_t "${ROOT}" || true
  fi
  log "SELinux labels applied (modules_object_t) under ${ROOT}"
fi

# Optional signing (secure boot)
PRIV="/etc/pki/akmods/private/private_key.priv"
PUB="/etc/pki/akmods/certs/public_key.der"
if [[ -f "${PRIV}" && -f "${PUB}" && -x "$(command -v kmodsign || true)" ]]; then
  log "Signing wl.ko with akmods key..."
  kmodsign sha512 "${PRIV}" "${PUB}" "${MODPATH}" || fail "kmodsign failed"
fi

# Verify vermagic; preload deps; load
VMOD="$(/usr/sbin/modinfo -F vermagic "${MODPATH}" | awk '{print $1}')"
[[ "${VMOD}" == "${KVER}" ]] || fail "vermagic mismatch: wl.ko built for ${VMOD}, running ${KVER}"

DEPS="$({ /usr/sbin/modinfo -F depends "${MODPATH}" || true; } | tr ',' ' ' | xargs -r echo || true)"
for d in ${DEPS:-}; do /usr/sbin/modprobe "${d}" 2>/dev/null || true; done
/usr/sbin/modprobe cfg80211 2>/dev/null || true

depmod -b "${ROOT}" "${KVER}"
/usr/sbin/insmod "${MODPATH}" 2>/dev/null || /usr/sbin/modprobe -S "${KVER}" -d "${ROOT}" wl || {
  dmesg | tail -n 120 || true
  fail "Failed to load wl."
}

lsmod | grep -q '^wl\s' && log "Loaded wl (build path)."
exit 0

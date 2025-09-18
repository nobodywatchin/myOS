#!/usr/bin/env bash

set -Eeuo pipefail

KVER="$(uname -r)"
WORK="$(mktemp -d -t wl-akmods-XXXXXX)"
CACHE_DIR="/var/cache/akmods/wl"
ROOT="/var/lib/wl-kmods/${KVER}"
MODDIR="${ROOT}/lib/modules/${KVER}/extra/wl"
MODPATH="${MODDIR}/wl.ko"

log() { echo "[wl-akmods] $*"; }
fail() { echo "[wl-akmods] ERROR: $*" >&2; exit 1; }
cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

# --- Preconditions ---------------------------------------------------------
for bin in akmods rpm2cpio cpio xz modprobe depmod; do
  command -v "$bin" >/dev/null 2>&1 || fail "Required tool '$bin' not found."
done

if ! rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1; then
  fail "Missing kernel-devel for ${KVER}. Install: dnf -y install kernel-devel-${KVER}"
fi

# --- Build via akmods (install step will fail on immutable /usr; that's fine) ----
log "Building akmod 'wl' for ${KVER}..."
if ! /usr/sbin/akmods --kernels "${KVER}" --akmod wl; then
  log "WARNING: akmods install step failed (immutable base). Continuing with cached RPM..."
fi

# --- Locate resulting kmod RPM ---------------------------------------------
RPM="$(ls -1t \
  "${CACHE_DIR}"/*-for-"${KVER}".rpm \
  "${CACHE_DIR}"/kmod-wl-*.rpm \
  2>/dev/null | head -n1 || true)"
[[ -n "${RPM}" && -f "${RPM}" ]] || {
  log "Build logs (if any):"
  ls -1 "${CACHE_DIR}"/*-for-"${KVER}".log        2>/dev/null || true
  ls -1 "${CACHE_DIR}"/*-for-"${KVER}".failed.log 2>/dev/null || true
  fail "No kmod-wl RPM produced for ${KVER} in ${CACHE_DIR}."
}
log "Using RPM: ${RPM}"

# --- Extract wl.ko ---------------------------------------------------------
pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM}"
FOUND="$(find "${WORK}" -type f \( -name 'wl.ko' -o -name 'wl.ko.xz' \) -print -quit || true)"
popd >/dev/null
[[ -n "${FOUND}" ]] || fail "wl.ko(.xz) not found inside ${RPM}"
[[ "${FOUND}" == *.xz ]] && xz -df "${FOUND}" && FOUND="${FOUND%.xz}"

# --- Stage into private module root ----------------------------------------
install -d -m 0755 "${MODDIR}"
install -m 0644 "${FOUND}" "${MODPATH}"
log "Staged module at ${MODPATH}"

# --- SELinux: ensure correct label so modprobe can read it ------------------
if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
  if command -v semanage >/dev/null 2>&1; then
    # Persist label across reboots for everything under /var/lib/wl-kmods
    semanage fcontext -a -t modules_object_t '/var/lib/wl-kmods(/.*)?' 2>/dev/null || true
    restorecon -RF "${ROOT}" || true
  else
    # Non-persistent fallback if semanage isn't installed
    chcon -R -t modules_object_t "${ROOT}" || true
  fi
  log "SELinux labels applied (modules_object_t) under ${ROOT}"
fi

# --- Optional: sign with akmods keypair (for Secure Boot) ------------------
PRIV="/etc/pki/akmods/private/private_key.priv"
PUB="/etc/pki/akmods/certs/public_key.der"
if [[ -f "${PRIV}" && -f "${PUB}" ]]; then
  if command -v kmodsign >/dev/null 2>&1; then
    log "Signing wl.ko with akmods key..."
    kmodsign sha512 "${PRIV}" "${PUB}" "${MODPATH}" || fail "kmodsign failed"
  else
    log "WARNING: kmodsign not found; skipping signing step."
  fi
fi

# --- Generate deps & load from private root --------------------------------
depmod -b "${ROOT}" "${KVER}"

if ! modprobe -S "${KVER}" -d "${ROOT}" wl; then
  log "modprobe failed; trying insmod fallback..."
  insmod "${MODPATH}" || fail "Failed to load wl (check dmesg/SELinux)."
fi

# --- Verify ----------------------------------------------------------------
if lsmod | grep -q '^wl\s'; then
  log "SUCCESS: wl module loaded."
else
  log "wl not listed by lsmod; recent dmesg:"
  dmesg | tail -n 50 || true
  fail "wl appears not to be active."
fi

exit 0

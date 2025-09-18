#!/usr/bin/env bash
# Build + load Broadcom wl module on rpm-ostree/BootC systems.
# - Makes akmods install failure non-fatal (immutable /usr).
# - Finds cached kmod RPM robustly, extracts wl.ko(.xz).
# - Optionally signs module if akmods keypair exists.
# - Loads using a private root so we don't touch /usr/lib/modules.

set -Eeuo pipefail

KVER="$(uname -r)"
WORK="$(mktemp -d -t wl-akmods-XXXXXX)"
CACHE_DIR="/var/cache/akmods/wl"
# Private, writable module tree used only for loading
ROOT="/var/lib/wl-kmods/${KVER}"
MODDIR="${ROOT}/lib/modules/${KVER}/extra"
MODPATH="${MODDIR}/wl.ko"

log() { echo "[wl-akmods] $*"; }
fail() { echo "[wl-akmods] ERROR: $*" >&2; exit 1; }

cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

# --- Preconditions ---------------------------------------------------------
# Tools needed to extract and (optionally) sign
for bin in akmods rpm2cpio cpio xz modprobe depmod; do
  command -v "$bin" >/dev/null 2>&1 || fail "Required tool '$bin' not found."
done

# Kernel headers must match running kernel
if ! rpm -q "kernel-devel-${KVER}" >/dev/null 2>&1; then
  fail "Missing kernel-devel for ${KVER}. Install: dnf -y install kernel-devel-${KVER}"
fi

# --- Build via akmods (install step will fail on ostree; that's OK) --------
log "Building akmod 'wl' for ${KVER}..."
if ! /usr/sbin/akmods --kernels "${KVER}" --akmod wl; then
  log "WARNING: akmods install step failed (expected on immutable /usr). Continuing with cached RPM..."
fi

# --- Locate resulting kmod RPM ---------------------------------------------
RPM="$(ls -1t \
  "${CACHE_DIR}"/*-for-"${KVER}".rpm \
  "${CACHE_DIR}"/kmod-wl-*.rpm \
  2>/dev/null | head -n1 || true)"

if [[ -z "${RPM}" || ! -f "${RPM}" ]]; then
  # Point to logs so diagnosis is easy
  log "Build logs:"
  ls -1 "${CACHE_DIR}"/*-for-"${KVER}".log 2>/dev/null || true
  ls -1 "${CACHE_DIR}"/*-for-"${KVER}".failed.log 2>/dev/null || true
  fail "No kmod-wl RPM produced for ${KVER} in ${CACHE_DIR}."
fi
log "Using RPM: ${RPM}"

# --- Extract wl.ko ---------------------------------------------------------
pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv >/dev/null 2>&1 || fail "Failed to extract ${RPM}"
FOUND="$(find "${WORK}" -type f \( -name 'wl.ko' -o -name 'wl.ko.xz' \) -print -quit || true)"
popd >/dev/null

[[ -n "${FOUND}" ]] || fail "wl.ko(.xz) not found inside ${RPM}"

# Decompress if required
if [[ "${FOUND}" == *.xz ]]; then
  xz -df "${FOUND}" || fail "Failed to decompress ${FOUND}"
  FOUND="${FOUND%.xz}"
fi

# --- Stage into private module root ----------------------------------------
install -d -m 0755 "${MODDIR}"
install -m 0644 "${FOUND}" "${MODPATH}"
log "Staged module at ${MODPATH}"

# --- Optional: Sign module if akmods keypair exists ------------------------
# If you've run kmodgenca -a and enrolled /etc/pki/akmods/certs/public_key.der via MOK,
# we sign the module so it will load on Secure Boot systems.
PRIV="/etc/pki/akmods/private/private_key.priv"
PUB="/etc/pki/akmods/certs/public_key.der"
if [[ -f "${PRIV}" && -f "${PUB}" ]]; then
  if command -v kmodsign >/dev/null 2>&1; then
    log "Signing wl.ko with akmods key..."
    kmodsign sha512 "${PRIV}" "${PUB}" "${MODPATH}" || fail "kmodsign failed"
  else
    log "WARNING: kmodsign not found; skipping signing step."
  fi
else
  log "No akmods keypair detected; skipping signing. (If Secure Boot is enabled, ensure MOK enrollment.)"
fi

# --- Generate module deps in the private root ------------------------------
depmod -b "${ROOT}" "${KVER}"

# --- Load module without touching /usr -------------------------------------
# modprobe -d uses our private root to resolve the module path.
if ! modprobe -S "${KVER}" -d "${ROOT}" wl; then
  # Fallback to insmod if alias resolution fails
  log "modprobe failed; trying insmod fallback..."
  insmod "${MODPATH}" || fail "Failed to load wl module (check Secure Boot and dmesg)."
fi

# --- Verify ----------------------------------------------------------------
if lsmod | grep -q '^wl\s'; then
  log "SUCCESS: wl module loaded."
else
  log "Module not listed by lsmod yet; checking dmesg for errors..."
  dmesg | tail -n 50
  fail "wl appears not to be active."
fi

# Optionally, persist autoload:
#   echo wl > /etc/modules-load.d/wl.conf
# But on immutable hosts, prefer a systemd service to invoke this script at boot.

exit 0

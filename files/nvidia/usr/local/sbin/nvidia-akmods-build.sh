#!/usr/bin/env bash
set -euo pipefail

kmod="nvidia"
kver="${1:-$(uname -r)}"

# akmods expects log dir
install -d -m0755 /var/log/akmods
install -d -m0755 "/var/cache/akmods/${kmod}/${kver}" || true

# If you ever turn SB on, make sure a key exists (no-op if SB off)
 /usr/local/sbin/akmods-key-ensure.sh || true

# Build with akmods; ignore non-zero if it only failed at the 'install' step
if ! /usr/sbin/akmods --force --kernels "$kver" --kmod "$kmod"; then
  echo "akmods returned non-zero; continuing if artifacts exist…" >&2
fi

# Locate built .ko tree; if not present, extract from the built kmod RPM(s)
find_src() {
  for p in \
    "/var/cache/akmods/${kmod}/${kver}/usr/lib/modules/${kver}/extra" \
    "/var/cache/akmods/${kmod}/${kver}/root/usr/lib/modules/${kver}/extra" \
    "/var/cache/akmods/${kmod}/${kver}/result/usr/lib/modules/${kver}/extra" \
    "/var/cache/akmods/${kmod}/${kver}/lib/modules/${kver}/extra"
  do
    if [ -d "$p" ] && ls "$p"/*.ko* >/dev/null 2>&1; then
      echo "$p"; return 0
    fi
  done
  # Fallback: extract from RPMs
  tmp="/var/cache/akmods/${kmod}/${kver}/_extract"
  rm -rf "$tmp"; mkdir -p "$tmp"
  shopt -s nullglob
  rpms=(/var/cache/akmods/${kmod}/${kver}/*.rpm /var/cache/akmods/${kmod}/${kver}/results/*.rpm)
  shopt -u nullglob
  if (( ${#rpms[@]} )); then
    for rpm in "${rpms[@]}"; do
      if command -v rpm2cpio >/dev/null 2>&1; then
        (cd "$tmp" && rpm2cpio "$rpm" | cpio -idmv >/dev/null 2>&1)
      elif command -v bsdtar >/dev/null 2>&1; then
        (cd "$tmp" && bsdtar -xf "$rpm")
      else
        echo "Need rpm2cpio or bsdtar to extract $rpm" >&2
        return 1
      fi
    done
    for p in "$tmp/usr/lib/modules/${kver}/extra" "$tmp/lib/modules/${kver}/extra"; do
      if [ -d "$p" ] && ls "$p"/*.ko* >/dev/null 2>&1; then
        echo "$p"; return 0
      fi
    done
  fi
  return 1
}

src="$(find_src)" || { echo "No akmods artifacts found for ${kmod}/${kver}" >&2; exit 1; }

# Stage into updates/ and bind-mount (ostree-safe)
dst="/var/lib/akmods/${kver}/updates"
mkdir -p "$dst"
rsync -a --delete "$src/"/ "$dst/"/
mkdir -p "/usr/lib/modules/${kver}/updates"
mountpoint -q "/usr/lib/modules/${kver}/updates" || mount --bind "$dst" "/usr/lib/modules/${kver}/updates"
depmod -a "$kver"

# Prefer NVIDIA over nouveau if nouveau happens to be loaded
modprobe -r nouveau 2>/dev/null || true

# Load the modules
modprobe nvidia || true
modprobe nvidia_modeset || true
modprobe nvidia_uvm || true
modprobe nvidia_drm || true

echo "nvidia modules staged and (attempted) loaded for $kver"

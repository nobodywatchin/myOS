#!/usr/bin/env bash
set -euo pipefail
kmod="${1:?kmod name required}"
kver="${2:-$(uname -r)}"

# Try common akmods cache layouts and locate built .ko files
src=""
for p in \
  "/var/cache/akmods/${kmod}/${kver}/usr/lib/modules/${kver}/extra" \
  "/var/cache/akmods/${kmod}/${kver}/root/usr/lib/modules/${kver}/extra" \
  "/var/cache/akmods/${kmod}/${kver}/result/usr/lib/modules/${kver}/extra"
do
  if [ -d "$p" ] && ls "$p"/*.ko* >/dev/null 2>&1; then src="$p"; break; fi
done

if [ -z "$src" ]; then
  echo "ERROR: Could not locate built ${kmod} modules under /var/cache/akmods/${kmod}/${kver}" >&2
  exit 1
fi

dst="/var/lib/akmods/${kver}/updates"
mkdir -p "$dst"
rsync -a --delete "$src/"/ "$dst/"/

# Bind-mount updates into the read-only /usr/lib/modules/<kver>/updates
mkdir -p "/usr/lib/modules/${kver}/updates"
if ! mountpoint -q "/usr/lib/modules/${kver}/updates"; then
  mount --bind "$dst" "/usr/lib/modules/${kver}/updates"
fi

depmod -a "$kver"

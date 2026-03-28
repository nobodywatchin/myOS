#!/bin/bash
# Exit 0 if this machine likely needs the proprietary wl driver, else 1.
# Uses sysfs only (works early, no lspci required).
set -euo pipefail

# Known wl-only device IDs you want to support (lowercase, 0x prefix optional):
NEED_IDS=("14e4:43a0" "14e4:43b1" "14e4:4331" "14e4:4359" "14e4:432b" "14e4:432a" "14e4:4338" "14e4:43aa")

any_brcm=1
for dev in /sys/bus/pci/devices/*; do
  [[ -e "$dev/vendor" ]] || continue
  ven=$(<"$dev/vendor")
  cls=$(<"$dev/class")
  [[ "${ven,,}" == "0x14e4" ]] || continue             # Broadcom
  any_brcm=0
  # Prefer wl only for Network Controller (0x0280xx) class
  [[ "${cls,,}" == 0x0280* ]] || continue

  # If device matches a known wl-only PCI ID, green-light
  if [[ -e "$dev/device" ]]; then
    dev_id=$(<"$dev/device")
    dev_id="${ven,,}:${dev_id,,}"       # 0x14e4:0x43a0
    dev_id="${dev_id/0x/}"              # 14e4:0x43a0
    dev_id="${dev_id/0x/}"              # 14e4:43a0
    for want in "${NEED_IDS[@]}"; do
      if [[ "${dev_id,,}" == "${want,,}" ]]; then
        exit 0
      fi
    done
  fi
done

# Fallback: if *any* Broadcom NIC exists but no in-kernel brcm modules are loaded, allow wl
if [[ $any_brcm -eq 0 ]]; then
  if ! grep -Eq '(^| )brcmfmac|(^| )b43|(^| )brcmsmac' /proc/modules; then
    exit 0
  fi
fi

exit 1

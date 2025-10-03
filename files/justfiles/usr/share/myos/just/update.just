# Update System Flatpaks and OS Image
update-system:
  sudo flatpak update --system -y
  sudo bootc upgrade
  @echo "Reboot to apply system updates"

# Update User Flatpaks and Distrobox Containers
update-user:
  flatpak update --user -y
  distrobox-upgrade --all

# Update Podman Containers
update-podman:
  podman image prune -f
  podman auto-update --authfile ~/.config/containers/auth.json

# Update Firmware
update-firmware:
  sudo fwupdmgr refresh --force
  sudo fwupdmgr get-updates
  sudo fwupdmgr update

# Update Everything
update-all:
  just update-system
  just update-user
  just update-podman
  just update-firmware

# Update Chooser
update:
    #!/usr/bin/env bash
    set -euo pipefail
    sel="$(fzf --prompt='Update: ' --height=15 --border --exit-0 \
          --with-nth=2.. \
          <<< $'update-system    Update System Flatpaks and OS Image\nupdate-user      Update User Flatpaks and Distrobox Containers\nupdate-podman    Update Podman Containers\nupdate-firmware  Update Firmware\nupdate-all       Update Everything\n')"
    [[ -n "$sel" ]] || { echo "No selection."; exit 0; }
    target="${sel%% *}"
    echo "→ Running: just ${target}"
    exec just "${target}"
